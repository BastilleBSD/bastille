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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille destroy [option] | [container|release]${COLOR_RESET}"
    exit 1
}

destroy_jail() {
    bastille_jail_base="${bastille_jailsdir}/${TARGET}"            ## dir
    bastille_jail_log="${bastille_logsdir}/${TARGET}_console.log"  ## file

    if [ "$(jls name | awk "/^${TARGET}$/")" ]; then
        if [ "${FORCE}" = "1" ]; then
            bastille stop "${TARGET}"
        else
            echo -e "${COLOR_RED}Jail running.${COLOR_RESET}"
            echo -e "${COLOR_RED}See 'bastille stop ${TARGET}'.${COLOR_RESET}"
            exit 1
        fi
    fi

    if [ ! -d "${bastille_jail_base}" ]; then
        echo -e "${COLOR_RED}Jail not found.${COLOR_RESET}"
        exit 1
    fi

    if [ -d "${bastille_jail_base}" ]; then
        echo -e "${COLOR_GREEN}Deleting Jail: ${TARGET}.${COLOR_RESET}"
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ -n "${TARGET}" ]; then
                    ## remove jail zfs dataset recursively
                    zfs destroy -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}"
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
            echo -e "${COLOR_GREEN}Note: jail console logs archived.${COLOR_RESET}"
            echo -e "${COLOR_GREEN}${bastille_jail_log}-$(date +%F)${COLOR_RESET}"
        fi

        ## clear any active rdr rules
        if [ ! -z "$(pfctl -a "rdr/${TARGET}" -Psn 2>/dev/null)" ]; then
            echo -e "${COLOR_GREEN}Clearing RDR rules:${COLOR_RESET}"
            pfctl -a "rdr/${TARGET}" -Fn
        fi
        echo
    fi
}

destroy_rel() {
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
                echo -e "${COLOR_RED}Notice: (${_jail}) depends on ${TARGET} base.${COLOR_RESET}"
                BASE_HASCHILD="1"
            fi
        done
    fi

    if [ ! -d "${bastille_rel_base}" ]; then
        echo -e "${COLOR_RED}Release base not found.${COLOR_RESET}"
        exit 1
    else
        if [ "${BASE_HASCHILD}" -eq "0" ]; then
            echo -e "${COLOR_GREEN}Deleting base: ${TARGET}.${COLOR_RESET}"
            if [ "${bastille_zfs_enable}" = "YES" ]; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${TARGET}"
                    if [ "${FORCE}" = "1" ]; then
                        if [ -d "${bastille_cachedir}/${TARGET}" ]; then
                            zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${TARGET}"
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
            echo -e "${COLOR_RED}Cannot destroy base with containers child.${COLOR_RESET}"
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
        echo -e "${COLOR_RED}Unknown Option.${COLOR_RESET}"
        usage
        ;;
esac

TARGET="${1}"

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

## check what should we clean
case "${TARGET}" in
*-RELEASE|*-release|*-RC1|*-rc1|*-RC2|*-rc2)
    ## check for FreeBSD releases name
    NAME_VERIFY=$(echo "${TARGET}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-2])$' | tr '[:lower:]' '[:upper:]')
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
