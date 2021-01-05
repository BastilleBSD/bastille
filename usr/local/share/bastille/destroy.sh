#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_exit "Usage: bastille destroy [option] | [container|release]"
}

destroy_jail() {
    local OPTIONS
    bastille_jail_base="${bastille_jailsdir}/${TARGET}"            ## dir
    bastille_jail_log="${bastille_logsdir}/${TARGET}_console.log"  ## file

    if [ "$(jls name | awk "/^${TARGET}$/")" ]; then
        if [ "${FORCE}" = "1" ]; then
            bastille stop "${TARGET}"
        else
            error_notify "Jail running."
            error_exit "See 'bastille stop ${TARGET}'."
        fi
    fi

    if [ ! -d "${bastille_jail_base}" ]; then
        error_exit "Jail not found."
    fi

    if [ -d "${bastille_jail_base}" ]; then
        info "Deleting Jail: ${TARGET}."
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ -n "${TARGET}" ]; then
                    OPTIONS="-r"
                    if [ "${FORCE}" = "1" ]; then
                        OPTIONS="-rf"
                    fi
                    ## remove jail zfs dataset recursively
                    zfs destroy "${OPTIONS}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}"
                fi
            fi
        fi

        if [ -d "${bastille_jail_base}" ]; then
            ## removing all flags
            chflags -R noschg "${bastille_jail_base}"

            ## remove jail base
            rm -rf "${bastille_jail_base}"
        fi

        ## archive jail log
        if [ -f "${bastille_jail_log}" ]; then
            mv "${bastille_jail_log}" "${bastille_jail_log}"-"$(date +%F)"
            info "Note: jail console logs archived."
            info "${bastille_jail_log}-$(date +%F)"
        fi

        ## clear any active rdr rules
        if [ ! -z "$(pfctl -a "rdr/${TARGET}" -Psn 2>/dev/null)" ]; then
            info "Clearing RDR rules:"
            pfctl -a "rdr/${TARGET}" -Fn
        fi
        echo
    fi
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

    ## check if this release have containers child
    BASE_HASCHILD="0"
    if [ -d "${bastille_jailsdir}" ]; then
        JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
        for _jail in ${JAIL_LIST}; do
            if grep -qwo "${TARGET}" "${bastille_jailsdir}/${_jail}/fstab" 2>/dev/null; then
                error_notify "Notice: (${_jail}) depends on ${TARGET} base."
                BASE_HASCHILD="1"
            fi
        done
    fi

    if [ ! -d "${bastille_rel_base}" ]; then
        error_exit "Release base not found."
    else
        if [ "${BASE_HASCHILD}" -eq "0" ]; then
            info "Deleting base: ${TARGET}"
            if [ "${bastille_zfs_enable}" = "YES" ]; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    if [ -n "${TARGET}" ]; then
                        OPTIONS="-r"
                        if [ "${FORCE}" = "1" ]; then
                            OPTIONS="-rf"
                        fi
                        zfs destroy "${OPTIONS}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${TARGET}"
                        if [ "${FORCE}" = "1" ]; then
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

            if [ "${FORCE}" = "1" ]; then
                ## remove cache on force
                if [ -d "${bastille_cachedir}/${TARGET}" ]; then
                    rm -rf "${bastille_cachedir}/${TARGET}"
                fi
            fi
            echo
        else
            error_notify "Cannot destroy base with child containers."
        fi
    fi
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

## reset this options
FORCE=""

## handle additional options
case "${1}" in
    -f|--force|force)
        FORCE="1"
        shift
        ;;
    -*)
        error_notify "Unknown Option."
        usage
        ;;
esac

TARGET="${1}"

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

## check what should we clean
case "${TARGET}" in
*-CURRENT|*-CURRENT-I386|*-CURRENT-i386|*-current)
    ## check for FreeBSD releases name
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})\.[0-9](-CURRENT|-CURRENT-i386)$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
    destroy_rel
    ;;
*-RELEASE|*-RELEASE-I386|*-RELEASE-i386|*-release|*-RC1|*-rc1|*-RC2|*-rc2)
    ## check for FreeBSD releases name
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RELEASE-i386|-RC[1-2])$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
    destroy_rel
    ;;
*-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
    ## check for HardenedBSD releases name
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})(-stable-last)$' | sed 's/STABLE/stable/g' | sed 's/last/LAST/g')
    destroy_rel
    ;;
*-stable-build-[0-9]*|*-STABLE-BUILD-[0-9]*)
    ## check for HardenedBSD(specific stable build releases)
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '([0-9]{1,2})(-stable-build)-([0-9]{1,3})$' | sed 's/BUILD/build/g' | sed 's/STABLE/stable/g')
    destroy_rel
    ;;
*-stable-build-latest|*-stable-BUILD-LATEST|*-STABLE-BUILD-LATEST)
    ## check for HardenedBSD(latest stable build release)
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '([0-9]{1,2})(-stable-build-latest)$' | sed 's/STABLE/stable/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
    destroy_rel
    ;;
current-build-[0-9]*|CURRENT-BUILD-[0-9]*)
    ## check for HardenedBSD(specific current build releases)
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(current-build)-([0-9]{1,3})' | sed 's/BUILD/build/g' | sed 's/CURRENT/current/g')
    destroy_rel
    ;;
current-build-latest|current-BUILD-LATEST|CURRENT-BUILD-LATEST)
    ## check for HardenedBSD(latest current build release)
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '(current-build-latest)$' | sed 's/CURRENT/current/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
    destroy_rel
    ;;
*)
    ## just destroy a jail
    destroy_jail
    ;;
esac
