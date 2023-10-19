#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille list [-j|-a] [release [-p]|template|(jail|container)|log|limit|(import|export|backup)]"
}

if [ "${1}" = help -o "${1}" = "-h" -o "${1}" = "--help" ]; then
    usage
fi

bastille_root_check

if [ $# -eq 0 ]; then
   /usr/sbin/jls
fi

if [ "${1}" == "-j" ]; then
    /usr/sbin/jls -N --libxo json
    exit 0
fi

TARGET=

list_all(){
        if [ -d "${bastille_jailsdir}" ]; then
            DEFAULT_VALUE="-"
            SPACER=2
            MAX_LENGTH_JAIL_NAME=$(find ""${bastille_jailsdir}/*/jail.conf"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h -m 1 -e "^.* {$" | awk '{ print length($1) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_NAME=${MAX_LENGTH_JAIL_NAME:-3}
            if [ "${MAX_LENGTH_JAIL_NAME}" -lt 3 ]; then MAX_LENGTH_JAIL_NAME=3; fi
            MAX_LENGTH_JAIL_IP=$(find ""${bastille_jailsdir}/*/jail.conf"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 sed -n "s/^[ ]*ip[4,6].addr[ ]*=[ ]*\(.*\);$/\1 /p" | sed 's/\// /g' | awk '{ print length($1) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_IP:-10}
            MAX_LENGTH_JAIL_VNET_IP=$(find ""${bastille_jailsdir}/*/jail.conf"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -l "vnet;" | grep -h "ifconfig_vnet0=" $(sed -n "s/\(.*\)jail.conf$/\1root\/etc\/rc.conf/p") | sed -n "s/^ifconfig_vnet0=\"\(.*\)\"$/\1/p"| sed "s/\// /g" | awk '{ if ($1 ~ /^[inet|inet6]/) print length($2); else print 15 }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_VNET_IP=${MAX_LENGTH_JAIL_VNET_IP:-10}
            if [ "${MAX_LENGTH_JAIL_VNET_IP}" -gt "${MAX_LENGTH_JAIL_IP}" ]; then MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_VNET_IP}; fi
            if [ "${MAX_LENGTH_JAIL_IP}" -lt 10 ]; then MAX_LENGTH_JAIL_IP=10; fi
            MAX_LENGTH_JAIL_HOSTNAME=$(find ""${bastille_jailsdir}/*/jail.conf"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h -m 1 -e "^[ ]*host.hostname[ ]*=[ ]*\(.*\);" | awk '{ print length(substr($3, 1, length($3)-1)) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_HOSTNAME=${MAX_LENGTH_JAIL_HOSTNAME:-8}
            if [ "${MAX_LENGTH_JAIL_HOSTNAME}" -lt 8 ]; then MAX_LENGTH_JAIL_HOSTNAME=8; fi
            MAX_LENGTH_JAIL_PORTS=$(find ""${bastille_jailsdir}/*/rdr.conf"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 -n1 awk '{ lines++; chars += length($0)} END { chars += lines - 1; print chars }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_PORTS=${MAX_LENGTH_JAIL_PORTS:-15}
            if [ "${MAX_LENGTH_JAIL_PORTS}" -lt 15 ]; then MAX_LENGTH_JAIL_PORTS=15; fi
            if [ "${MAX_LENGTH_JAIL_PORTS}" -gt 30 ]; then MAX_LENGTH_JAIL_PORTS=30; fi
            MAX_LENGTH_JAIL_RELEASE=$(find ""${bastille_jailsdir}/*/fstab"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h "/releases/.*/root/.bastille.*nullfs" | grep -hE "^USERLAND_VERSION=" $(sed -n "s/^\(.*\) \/.*$/\1\/bin\/freebsd-version/p" | awk '!_[$0]++') | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p" | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_JAIL_RELEASE:-7}
            MAX_LENGTH_THICK_JAIL_RELEASE=$(find ""${bastille_jailsdir}/*/root/bin/freebsd-version"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -hE "^USERLAND_VERSION=" | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p" | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_THICK_JAIL_RELEASE=${MAX_LENGTH_THICK_JAIL_RELEASE:-7}
            MAX_LENGTH_LINUX_JAIL_RELEASE=$(find ""${bastille_jailsdir}/*/fstab"" -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h "/jails/.*/root/proc.*linprocfs" | grep -hE "^NAME=|^VERSION_ID=|^VERSION_CODENAME=" $(sed -n "s/^linprocfs *\(.*\)\/.*$/\1\/etc\/os-release/p") 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | sed "N;N;s/\n/;/g" | sed -n "s/^NAME=\(.*\);VERSION_ID=\(.*\);VERSION_CODENAME=\(.*\)$/\1 \2 (\3)/p" | awk '{ print length($0) }' | sort -nr | head -n 1) 
            MAX_LENGTH_LINUX_JAIL_RELEASE=${MAX_LENGTH_LINUX_JAIL_RELEASE:-7}
            if [ "${MAX_LENGTH_THICK_JAIL_RELEASE}" -gt "${MAX_LENGTH_JAIL_RELEASE}" ]; then MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_THICK_JAIL_RELEASE}; fi
            if [ "${MAX_LENGTH_LINUX_JAIL_RELEASE}" -gt "${MAX_LENGTH_JAIL_RELEASE}" ]; then MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_LINUX_JAIL_RELEASE}; fi
            if [ "${MAX_LENGTH_JAIL_RELEASE}" -lt 7 ]; then MAX_LENGTH_JAIL_RELEASE=7; fi
            printf " JID%*sState%*sIP Address%*sPublished Ports%*sHostname%*sRelease%*sPath\n" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 3))" "" "$((${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} + ${SPACER} - 10))" "" "$((${MAX_LENGTH_JAIL_PORTS} + ${SPACER} - 15))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} + ${SPACER} - 8))" "" "$((${MAX_LENGTH_JAIL_RELEASE} + ${SPACER} - 7))" ""
            if [ -n "${TARGET}" ]; then
                # Query all info for a specific jail.
                JAIL_LIST="${TARGET}"
            else
                # Query all info for all jails(default).
                JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
            fi
            for _JAIL in ${JAIL_LIST}; do
                if [ -f "${bastille_jailsdir}/${_JAIL}/jail.conf" ]; then
                    JAIL_NAME=$(grep -h -m 1 -e "^.* {$" "${bastille_jailsdir}/${_JAIL}/jail.conf" 2> /dev/null | awk '{ print $1 }')
                    IS_FREEBSD_JAIL=0
                    if [ -f "${bastille_jailsdir}/${JAIL_NAME}/root/bin/freebsd-version" -o -f "${bastille_jailsdir}/${JAIL_NAME}/root/.bastille/bin/freebsd-version" -o "$(grep -c "/releases/.*/root/.bastille.*nullfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null)" -gt 0 ]; then IS_FREEBSD_JAIL=1; fi
                    IS_FREEBSD_JAIL=${IS_FREEBSD_JAIL:-0}
                    IS_LINUX_JAIL=0
                    if [ "$(grep -c "^linprocfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null)" -gt 0 ]; then IS_LINUX_JAIL=1; fi
                    IS_LINUX_JAIL=${IS_LINUX_JAIL:-0}
                    if [ "$(/usr/sbin/jls name | awk "/^${JAIL_NAME}$/")" ]; then
                        JAIL_STATE="Up"
                        if [ "$(awk '$1 == "vnet;" { print $1 }' "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)" ]; then
                            JAIL_IP=$(jexec -l ${JAIL_NAME} ifconfig -n vnet0 inet 2> /dev/null | sed -n "/.inet /{s///;s/ .*//;p;}")
                            if [ ! "${JAIL_IP}" ]; then JAIL_IP=$(jexec -l ${JAIL_NAME} ifconfig -n vnet0 inet6 2> /dev/null | awk '/inet6 / && (!/fe80::/ || !/%vnet0/)' | sed -n "/.inet6 /{s///;s/ .*//;p;}"); fi
                        else
                            JAIL_IP=$(/usr/sbin/jls -j ${JAIL_NAME} ip4.addr 2> /dev/null)
                            if [ "${JAIL_IP}" = "-" ]; then JAIL_IP=$(/usr/sbin/jls -j ${JAIL_NAME} ip6.addr 2> /dev/null); fi
                        fi
                        JAIL_HOSTNAME=$(/usr/sbin/jls -j ${JAIL_NAME} host.hostname 2> /dev/null)
                        JAIL_PORTS=$(pfctl -a "rdr/${JAIL_NAME}" -Psn 2> /dev/null | awk '{ printf "%s/%s:%s"",",$7,$14,$18 }' | sed "s/,$//")
                        JAIL_PATH=$(/usr/sbin/jls -j ${JAIL_NAME} path 2> /dev/null)
                        if [ "${IS_FREEBSD_JAIL}" -eq 1 ]; then
                            JAIL_RELEASE=$(jexec -l ${JAIL_NAME} freebsd-version -u 2> /dev/null)
                        fi
                        if [ "${IS_LINUX_JAIL}" -eq 1 ]; then
                            JAIL_RELEASE=$(grep -hE "^NAME=.*$|^VERSION_ID=.*$|^VERSION_CODENAME=.*$" "${JAIL_PATH}/etc/os-release" 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | awk -F'=' '{ a[$1] = $2; o++ } o%3 == 0 { print a["VERSION_CODENAME"] " (" a["NAME"] " " a["VERSION_ID"] ")" }')
                        fi
                    else
                        JAIL_STATE=$(if [ "$(sed -n "/^${JAIL_NAME} {$/,/^}$/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | awk '$0 ~ /^'${JAIL_NAME}' \{|\}/ { printf "%s",$0 }')" == "${JAIL_NAME} {}" ]; then echo "Down"; else echo "n/a"; fi)
                        if [ "$(awk '$1 == "vnet;" { print $1 }' "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)" ]; then
                            JAIL_IP=$(sed -n 's/^ifconfig_vnet0="\(.*\)"$/\1/p' "${bastille_jailsdir}/${JAIL_NAME}/root/etc/rc.conf" 2> /dev/null | sed "s/\// /g" | awk '{ if ($1 ~ /^[inet|inet6]/) print $2; else print $1 }')
                        else
                            JAIL_IP=$(sed -n "s/^[ ]*ip[4,6].addr[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | sed "s/\// /g" | awk '{ print $1 }')
                        fi
                        JAIL_HOSTNAME=$(sed -n "s/^[ ]*host.hostname[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)
                        if [ -f "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf" ]; then JAIL_PORTS=$(awk '$1 ~ /^[tcp|udp]/ { printf "%s/%s:%s,",$1,$2,$3 }' "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf" 2> /dev/null | sed "s/,$//"); else JAIL_PORTS=""; fi
                            JAIL_PATH=$(sed -n "s/^[ ]*path[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)
                            if [ "${JAIL_PATH}" ]; then
                                if [ "${IS_FREEBSD_JAIL}" -eq 1 ]; then
                                    if [ -f "${JAIL_PATH}/bin/freebsd-version" ]; then
                                        JAIL_RELEASE=$(grep -hE "^USERLAND_VERSION=" "${JAIL_PATH}/bin/freebsd-version" 2> /dev/null | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p")
                                    else
                                        JAIL_RELEASE=$(grep -h "/releases/.*/root/.bastille.*nullfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null | grep -hE "^USERLAND_VERSION=" $(sed -n "s/^\(.*\) \/.*$/\1\/bin\/freebsd-version/p" | awk '!_[$0]++') | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p")
                                    fi
                                fi
                                if [ "${IS_LINUX_JAIL}" -eq 1 ]; then
                                    JAIL_RELEASE=$(grep -hE "^NAME=.*$|^VERSION_ID=.*$|^VERSION_CODENAME=.*$" "${JAIL_PATH}/etc/os-release" 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | awk -F'=' '{ a[$1] = $2; o++ } o%3 == 0 { print a["VERSION_CODENAME"] " (" a["NAME"] " " a["VERSION_ID"] ")" }')
                                fi
                            else
                               JAIL_RELEASE=""
                            fi
                        fi

                        if [ "${#JAIL_PORTS}" -gt "${MAX_LENGTH_JAIL_PORTS}" ]; then JAIL_PORTS="$(echo ${JAIL_PORTS} | cut -c-$((${MAX_LENGTH_JAIL_PORTS} - 3)))..."; fi
                        JAIL_NAME=${JAIL_NAME:-${DEFAULT_VALUE}}
                        JAIL_STATE=${JAIL_STATE:-${DEFAULT_VALUE}}
                        JAIL_IP=${JAIL_IP:-${DEFAULT_VALUE}}
                        JAIL_PORTS=${JAIL_PORTS:-${DEFAULT_VALUE}}
                        JAIL_HOSTNAME=${JAIL_HOSTNAME:-${DEFAULT_VALUE}}
                        JAIL_RELEASE=${JAIL_RELEASE:-${DEFAULT_VALUE}}
                        JAIL_PATH=${JAIL_PATH:-${DEFAULT_VALUE}}
                        printf " ${JAIL_NAME}%*s${JAIL_STATE}%*s${JAIL_IP}%*s${JAIL_PORTS}%*s${JAIL_HOSTNAME}%*s${JAIL_RELEASE}%*s${JAIL_PATH}\n" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#JAIL_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} - ${#JAIL_HOSTNAME} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
                fi
            done
        else
            error_exit "unfortunately there are no jails here (${bastille_jailsdir})"
        fi
}

list_release(){
    if [ -d "${bastille_releasesdir}" ]; then
        REL_LIST=$(ls "${bastille_releasesdir}" | sed "s/\n//g")
        for _REL in ${REL_LIST}; do
            if [ -f "${bastille_releasesdir}/${_REL}/root/.profile" -o -d "${bastille_releasesdir}/${_REL}/debootstrap" ]; then
                if [ "${2}" == "-p" -a -f "${bastille_releasesdir}/${_REL}/bin/freebsd-version" ]; then
                    REL_PATCH_LEVEL=$(sed -n "s/^USERLAND_VERSION=\"\(.*\)\"$/\1/p" "${bastille_releasesdir}/${_REL}/bin/freebsd-version" 2> /dev/null)
                    REL_PATCH_LEVEL=${REL_PATCH_LEVEL:-${_REL}}
                    echo "${REL_PATCH_LEVEL}"
                else
                    echo "${_REL}"
                fi
            fi
        done
    fi
}

list_template(){
    find "${bastille_templatesdir}" -type d -maxdepth 2
}

list_jail(){
    if [ -d "${bastille_jailsdir}" ]; then
        JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
        for _JAIL in ${JAIL_LIST}; do
            if [ -f "${bastille_jailsdir}/${_JAIL}/jail.conf" ]; then
                echo "${_JAIL}"
            fi
        done
    fi
}

list_log(){
	find "${bastille_logsdir}" -type f -maxdepth 1
}

list_limit(){
    rctl -h jail:
}

list_import(){
    ls "${bastille_backupsdir}" | grep -v ".sha256$"
}

if [ $# -gt 0 ]; then
    # Handle special-case commands first.
    case "${1}" in
    all|-a|--all)
        list_all
        ;;
    release|releases)
        list_release
        ;;
    template|templates)
        list_template
        ;;
    jail|jails|container|containers)
        list_jail
        ;;
    log|logs)
        list_log
        ;;
    limit|limits)
        list_limit
        ;;
    import|imports|export|exports|backup|backups)
        list_import
    exit 0
    ;;
    *)
        # Check if we want to query all info for a specific jail instead.
        if [ -f "${bastille_jailsdir}/${1}/jail.conf" ]; then
            TARGET="${1}"
            list_all
        else
            usage
        fi
        ;;
    esac
fi
