#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

. /usr/local/share/bastille/common.sh

usage() {
    error_notify "Usage: bastille destroy [option(s)] [JAIL|RELEASE]"
    cat << EOF
	
    Options:

    -a | --auto              Auto mode. Start/stop jail(s) if required.
    -f | --force             Force unmount any mounted datasets when destroying a jail or release (ZFS only).
    -c | --no-cache          Do no destroy cache when destroying a release.
    -x | --debug             Enable debug mode.

EOF
    exit 1
}

destroy_jail() {

    local OPTIONS

    for _jail in ${JAILS}; do

        bastille_jail_base="${bastille_jailsdir}/${_jail}"
        bastille_jail_log="${bastille_logsdir}/${_jail}_console.log"

        # Validate jail state before continuing
        check_target_is_stopped "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
            bastille stop "${_jail}"
        else
            info "\n[${_jail}]:"
            error_notify "Jail is running."
            error_continue "Use [-a|--auto] to auto-stop the jail."
        fi

        info "\n[${_jail}]:"

        if [ -d "${bastille_jail_base}" ]; then

            # Make sure no filesystem is currently mounted
            mount_points="$(mount | cut -d ' ' -f 3 | grep ${bastille_jail_base}/root/)"

            if [ -n "${mount_points}" ]; then
                error_notify "Failed to destroy jail: ${_jail}"
                error_continue "Jail has mounted filesystems:\n$mount_points"
            fi

            echo "Destroying jail..."

            if checkyesno bastille_zfs_enable; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    if [ -n "${_jail}" ]; then
                        OPTIONS="-r"
                        if [ "${FORCE}" = "1" ]; then
                            OPTIONS="-rf"
                        fi
                        # Remove jail zfs dataset recursively, or abort if error thus precerving jail content.
                        # This will deal with the common "cannot unmount 'XYZ': pool or dataset is busy"
                        # unless the force option is defined by the user, otherwise will have a partially deleted jail.
                        if ! zfs destroy "${OPTIONS}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"; then
                            error_continue "[ERROR]: Jail dataset(s) appears to be busy, exiting."
                        fi
                    fi
                fi
            fi

            if [ -d "${bastille_jail_base}" ]; then
                # Remove flags
                chflags -R noschg "${bastille_jail_base}"

                # Remove jail base
                rm -rf "${bastille_jail_base}"
            fi

            # Archive jail log
            if [ -f "${bastille_jail_log}" ]; then
                mv "${bastille_jail_log}" "${bastille_jail_log}"-"$(date +%F)"
                echo "Note: jail console logs archived."
                echo "${bastille_jail_log}-$(date +%F)"
            fi

            # Clear any active rdr rules
            if [ ! -z "$(pfctl -a "rdr/${_jail}" -Psn 2>/dev/null)" ]; then
                echo "Clearing RDR rules..."
                pfctl -a "rdr/${_jail}" -Fn
            fi
        fi
	
    done
}

destroy_rel() {

    local OPTIONS

    ## check release name match before destroy
    if [ -n "${NAME_VERIFY}" ]; then
        TARGET="${NAME_VERIFY}"
    else
        usage
    fi

    bastille_rel_base="${bastille_releasesdir}/${TARGET}"  ## dir

    info "\nAttempting to destroy release: ${TARGET}"

    ## check if this release have containers child
    BASE_HASCHILD="0"
    if [ -d "${bastille_jailsdir}" ]; then
        JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
        for _jail in ${JAIL_LIST}; do
            if grep -qwo "${TARGET}" "${bastille_jailsdir}/${_jail}/fstab" 2>/dev/null; then
                error_notify "Notice: (${_jail}) depends on ${TARGET} base."
                BASE_HASCHILD="1"
            elif checkyesno bastille_zfs_enable; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    ## check if this release have child clones
                    if zfs list -H -t snapshot -r "${bastille_rel_base}" > /dev/null 2>&1; then
                        SNAP_CLONE=$(zfs list -H -t snapshot -r "${bastille_rel_base}" 2> /dev/null | awk '{print $1}')
                        for _snap_clone in ${SNAP_CLONE}; do
                            if zfs list -H -o clones "${_snap_clone}" > /dev/null 2>&1; then
                                CLONE_JAIL=$(zfs list -H -o clones "${_snap_clone}" | tr ',' '\n')
                                CLONE_CHECK="${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}/root"
                                if echo "${CLONE_JAIL}" | grep -qw "${CLONE_CHECK}"; then
                                    error_notify "Notice: (${_jail}) depends on ${TARGET} base."
                                    BASE_HASCHILD="1"
                                fi
                            fi
                        done
                    fi
                fi
            fi
        done
    fi

    if [ ! -d "${bastille_rel_base}" ]; then
        error_exit "Release base not found."
    else
        if [ "${BASE_HASCHILD}" -eq "0" ]; then
            echo "Deleting base..."
            if checkyesno bastille_zfs_enable; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    if [ -n "${TARGET}" ]; then
                        OPTIONS="-r"
                        if [ "${FORCE}" = "1" ]; then
                            OPTIONS="-rf"
                        fi
                        zfs destroy "${OPTIONS}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${TARGET}"
                        if [ "${NO_CACHE}" = "0" ]; then
                            if [ -d "${bastille_cachedir}/${TARGET}" ]; then
                                zfs destroy "${OPTIONS}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${TARGET}"
                            fi
                        fi
                    fi
                fi
            fi

            if [ -d "${bastille_rel_base}" ]; then
                ## removing all flags
                chflags -R noschg "${bastille_rel_base}"

                ## remove jail base
                rm -rf "${bastille_rel_base}"
            fi

            if [ "${NO_CACHE}" = "0" ]; then
                ## remove cache by default
                if [ -d "${bastille_cachedir}/${TARGET}" ]; then
                    rm -rf "${bastille_cachedir:?}/${TARGET:?}"
                fi
            fi
        else
            error_notify "Cannot destroy base with child containers."
        fi
    fi
}

# Handle options.
AUTO="0"
FORCE="0"
NO_CACHE="0"
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -c|--no-cache)
            NO_CACHE=1
            shift
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    c) NO_CACHE=1 ;;
                    f) FORCE=1 ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\"" ;;
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check

## check what should we clean
case "${TARGET}" in
    *-CURRENT|*-CURRENT-I386|*-CURRENT-i386|*-current)
        ## check for FreeBSD releases name
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})\.[0-9](-CURRENT|-CURRENT-i386)$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
        destroy_rel
        ;;
    *-RELEASE|*-RELEASE-I386|*-RELEASE-i386|*-release|*-RC[1-9]|*-rc[1-9]|*-BETA[1-9])
        ## check for FreeBSD releases name
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RELEASE-i386|-RC[1-9]|-BETA[1-9])$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
        destroy_rel
        ;;
    *-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
        ## check for HardenedBSD releases name
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})(-stable-last)$' | sed 's/STABLE/stable/g;s/last/LAST/g')
        destroy_rel
        ;;
    *-stable-build-[0-9]*|*-STABLE-BUILD-[0-9]*)
        ## check for HardenedBSD(specific stable build releases)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '([0-9]{1,2})(-stable-build)-([0-9]{1,3})$' | sed 's/BUILD/build/g;s/STABLE/stable/g')
        destroy_rel
        ;;
    *-stable-build-latest|*-stable-BUILD-LATEST|*-STABLE-BUILD-LATEST)
        ## check for HardenedBSD(latest stable build release)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '([0-9]{1,2})(-stable-build-latest)$' | sed 's/STABLE/stable/;s/build/BUILD/g;s/latest/LATEST/g')
        destroy_rel
        ;;
    current-build-[0-9]*|CURRENT-BUILD-[0-9]*)
        ## check for HardenedBSD(specific current build releases)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(current-build)-([0-9]{1,3})' | sed 's/BUILD/build/g;s/CURRENT/current/g')
        destroy_rel
        ;;
    current-build-latest|current-BUILD-LATEST|CURRENT-BUILD-LATEST)
        ## check for HardenedBSD(latest current build release)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(current-build-latest)$' | sed 's/CURRENT/current/;s/build/BUILD/g;s/latest/LATEST/g')
        destroy_rel
        ;;
    Ubuntu_1804|Ubuntu_2004|Ubuntu_2204|UBUNTU_1804|UBUNTU_2004|UBUNTU_2204)
        ## check for Linux releases
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(Ubuntu_1804)$|(Ubuntu_2004)$|(Ubuntu_2204)$' | sed 's/UBUNTU/Ubuntu/g;s/ubuntu/Ubuntu/g')
        destroy_rel
        ;;
    Debian10|Debian11|Debian12|DEBIAN10|DEBIAN11|DEBIAN12)
        ## check for Linux releases
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(Debian10)$|(Debian11)$|(Debian12)$' | sed 's/DEBIAN/Debian/g')
        destroy_rel
        ;;
    *)
        ## just destroy a jail
        set_target "${TARGET}" "reverse"
        destroy_jail "${JAILS}"
        ;;
esac
