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
    error_notify "Usage: bastille destroy [option(s)] JAIL"
    error_notify "                                    RELEASE"
    cat << EOF

    Options:

    -a | --auto         Auto mode. Start/stop jail(s) if required.
    -c | --no-cache     Do not destroy cache when destroying a release (legacy releases).
    -f | --force        Force unmount any mounted datasets when destroying a jail or release (ZFS only).
    -y | --yes          Do not prompt. Assume always yes.
    -x | --debug        Enable debug mode.

EOF
    exit 1
}

destroy_jail() {

    local jail="${1}"
    local OPTIONS=""

    bastille_jail_base="${bastille_jailsdir}/${jail}"
    bastille_jail_log="${bastille_logsdir}/${jail}_console.log"

    # Validate jail state before continuing
    check_target_is_stopped "${jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${jail}"
    else
        info 1 "\n[${jail}]:"
        error_notify "Jail is running."
        error_continue "Use [-a|--auto] to auto-stop the jail."
    fi

    info 1 "\n[${jail}]:"

    # Ask if user is sure they want to destroy the jail
    # but only if AUTO_YES=0
    if [ "${AUTO_YES}" -ne 1 ]; then
        warn "\nAttempting to destroy jail: ${jail}\n"
        # shellcheck disable=SC3045
        read -p "Are you sure you want to continue? [y|n]:" answer
        case "${answer}" in
            [Yy]|[Yy][Ee][Ss])
                ;;
            [Nn]|[Nn][Oo])
                error_exit "[ERROR]: Cancelled by user."
                ;;
            *)
                error_exit "[ERROR]: Invalid input. Please answer 'y' or 'n'."
                ;;
        esac
    fi

    if [ -d "${bastille_jail_base}" ]; then

        # Make sure no filesystem is currently mounted
        mount_points="$(mount | cut -d ' ' -f 3 | grep ${bastille_jail_base}/root/)"

        if [ -n "${mount_points}" ]; then
            error_notify "[ERROR]: Failed to destroy jail: ${jail}"
            error_continue "Jail has mounted filesystems:\n$mount_points"
        fi

        info 2 "Destroying jail..."

        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ -n "${jail}" ]; then
                    OPTIONS="-r"
                    if [ "${FORCE}" = "1" ]; then
                        OPTIONS="-rf"
                    fi
                    # Remove jail zfs dataset recursively, or abort if error thus precerving jail content.
                    # This will deal with the common "cannot unmount 'XYZ': pool or dataset is busy"
                    # unless the force option is defined by the user, otherwise will have a partially deleted jail.
                    if ! zfs destroy "${OPTIONS}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${jail}"; then
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
            info 2 "Note: jail console logs archived."
            info 2 "${bastille_jail_log}-$(date +%F)"
        fi

        # Clear any active rdr rules
        if [ ! -z "$(pfctl -a "rdr/${jail}" -Psn 2>/dev/null)" ]; then
            info 2 "Clearing RDR rules..."
            pfctl -a "rdr/${jail}" -Fn
        fi
    fi
}

destroy_release() {

    local OPTIONS

    ## check release name match before destroy
    if [ -n "${NAME_VERIFY}" ]; then
        TARGET="${NAME_VERIFY}"
    else
        usage
    fi

    bastille_rel_base="${bastille_releasesdir}/${TARGET}"  ## dir

    info 1 "\nAttempting to destroy release: ${TARGET}"

    ## check if this release have containers child
    BASE_HASCHILD="0"
    if [ -d "${bastille_jailsdir}" ]; then

        JAIL_LIST=$(ls -v --color=never "${bastille_jailsdir}" | sed "s/\n//g")

        for jail in ${JAIL_LIST}; do

            if grep -qwo "${TARGET}" "${bastille_jailsdir}/${jail}/fstab" 2>/dev/null; then
                error_notify "[ERROR]: (${jail}) depends on ${TARGET} base."
                BASE_HASCHILD="1"
            elif checkyesno bastille_zfs_enable; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    ## check if this release have child clones
                    if zfs list -H -t snapshot -r "${bastille_rel_base}" > /dev/null 2>&1; then
                        SNAP_CLONE=$(zfs list -H -t snapshot -r "${bastille_rel_base}" 2> /dev/null | awk '{print $1}')
                        for snap_clone in ${SNAP_CLONE}; do
                            if zfs list -H -o clones "${snap_clone}" > /dev/null 2>&1; then
                                CLONE_JAIL=$(zfs list -H -o clones "${snap_clone}" | tr ',' '\n')
                                CLONE_CHECK="${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${jail}/root"
                                if echo "${CLONE_JAIL}" | grep -qw "${CLONE_CHECK}"; then
                                    error_notify "[ERROR]: (${jail}) depends on ${TARGET} base."
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
        error_exit "[ERROR]: Release base not found."
    else
        if [ "${BASE_HASCHILD}" -eq "0" ]; then
            info 2 "Deleting release base..."
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
            error_notify "[ERROR]: Cannot destroy base with child containers."
        fi
    fi
}

# Handle options.
AUTO=0
AUTO_YES=0
FORCE=0
NO_CACHE=0
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
        -y|--yes)
            AUTO_YES=1
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    a) AUTO=1 ;;
                    c) NO_CACHE=1 ;;
                    f) FORCE=1 ;;
                    y) AUTO_YES=1 ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\"" ;;
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
        destroy_release
        ;;
    *-RELEASE|*-RELEASE-I386|*-RELEASE-i386|*-release|*-RC[1-9]|*-rc[1-9]|*-BETA[1-9])
        ## check for FreeBSD releases name
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([0-9]{1,2})\.[0-9](-RELEASE|-RELEASE-i386|-RC[1-9]|-BETA[1-9])$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
        destroy_release
        ;;
    *-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
        ## check for HardenedBSD releases name
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})(-stable-last)$' | sed 's/STABLE/stable/g;s/last/LAST/g')
        destroy_release
        ;;
    *-stable-build-[0-9]*|*-STABLE-BUILD-[0-9]*)
        ## check for HardenedBSD(specific stable build releases)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '([0-9]{1,2})(-stable-build)-([0-9]{1,3})$' | sed 's/BUILD/build/g;s/STABLE/stable/g')
        destroy_release
        ;;
    *-stable-build-latest|*-stable-BUILD-LATEST|*-STABLE-BUILD-LATEST)
        ## check for HardenedBSD(latest stable build release)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '([0-9]{1,2})(-stable-build-latest)$' | sed 's/STABLE/stable/;s/build/BUILD/g;s/latest/LATEST/g')
        destroy_release
        ;;
    current-build-[0-9]*|CURRENT-BUILD-[0-9]*)
        ## check for HardenedBSD(specific current build releases)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(current-build)-([0-9]{1,3})' | sed 's/BUILD/build/g;s/CURRENT/current/g')
        destroy_release
        ;;
    current-build-latest|current-BUILD-LATEST|CURRENT-BUILD-LATEST)
        ## check for HardenedBSD(latest current build release)
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(current-build-latest)$' | sed 's/CURRENT/current/;s/build/BUILD/g;s/latest/LATEST/g')
        destroy_release
        ;;
    Ubuntu_1804|Ubuntu_2004|Ubuntu_2204|UBUNTU_1804|UBUNTU_2004|UBUNTU_2204)
        ## check for Linux releases
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(Ubuntu_1804)$|(Ubuntu_2004)$|(Ubuntu_2204)$' | sed 's/UBUNTU/Ubuntu/g;s/ubuntu/Ubuntu/g')
        destroy_release
        ;;
    Debian10|Debian11|Debian12|DEBIAN10|DEBIAN11|DEBIAN12)
        ## check for Linux releases
        NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(Debian10)$|(Debian11)$|(Debian12)$' | sed 's/DEBIAN/Debian/g')
        destroy_release
        ;;
    *)
        if [ -d "${bastille_releasesdir}/${TARGET}" ]; then
            NAME_VERIFY="${TARGET}"
            destroy_release
        else
            # Destroy targeted jail(s)
            set_target "${TARGET}" "reverse"
            for jail in ${JAILS}; do
                destroy_jail "${jail}"
            done
        fi
        ;;
esac
