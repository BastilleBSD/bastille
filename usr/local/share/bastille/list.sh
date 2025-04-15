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
    error_notify "Usage: bastille list [option(s)] [RELEASE (-p)] [template] [JAIL|CONTAINER] [log] [limit] [import] [export] [backup] [priority]"
    cat << EOF
    Options:
    
    -j | --json           List jails in json format.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

list_all(){
        if [ -d "${bastille_jailsdir}" ]; then
            DEFAULT_VALUE="-"
            SPACER=2
            MAX_LENGTH_JAIL_NAME=$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h -m 1 -e "^.* {$" | awk '{ print length($1) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_NAME=${MAX_LENGTH_JAIL_NAME:-10}
            if [ "${MAX_LENGTH_JAIL_NAME}" -lt 3 ]; then MAX_LENGTH_JAIL_NAME=3; fi
            MAX_LENGTH_JID=${MAX_LENGTH_JID:-3}
            MAX_LENGTH_JAIL_IP=$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 sed -n "s/^[ ]*ip[4,6].addr[ ]*=[ ]*\(.*\);$/\1 /p" | sed 's/\// /g' | awk '{ print length($1) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_IP:-10}
            # shellcheck disable=SC2046
            MAX_LENGTH_JAIL_VNET_IP="$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -l "vnet;" | grep -h "ifconfig_vnet0=" $(sed -n "s/\(.*\)jail.conf$/\1root\/etc\/rc.conf/p") | sed -n "s/^ifconfig_vnet0=\"\(.*\)\"$/\1/p"| sed "s/\// /g" | awk '{ if ($1 ~ /^[inet|inet6]/) print length($2); else print 15 }' | sort -nr | head -n 1)"
            MAX_LENGTH_JAIL_VNET_IP=${MAX_LENGTH_JAIL_VNET_IP:-10}
            if [ "${MAX_LENGTH_JAIL_VNET_IP}" -gt "${MAX_LENGTH_JAIL_IP}" ]; then MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_VNET_IP}; fi
            if [ "${MAX_LENGTH_JAIL_IP}" -lt 10 ]; then MAX_LENGTH_JAIL_IP=10; fi
            MAX_LENGTH_JAIL_HOSTNAME=$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h -m 1 -e "^[ ]*host.hostname[ ]*=[ ]*\(.*\);" | awk '{ print length(substr($3, 1, length($3)-1)) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_HOSTNAME=${MAX_LENGTH_JAIL_HOSTNAME:-8}
            if [ "${MAX_LENGTH_JAIL_HOSTNAME}" -lt 8 ]; then MAX_LENGTH_JAIL_HOSTNAME=8; fi
            MAX_LENGTH_JAIL_PORTS=$(find ${bastille_jailsdir}/*/rdr.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 -n1 awk '{ lines++; chars += length($0)} END { chars += lines - 1; print chars }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_PORTS=${MAX_LENGTH_JAIL_PORTS:-15}
            if [ "${MAX_LENGTH_JAIL_PORTS}" -lt 15 ]; then MAX_LENGTH_JAIL_PORTS=15; fi
            if [ "${MAX_LENGTH_JAIL_PORTS}" -gt 30 ]; then MAX_LENGTH_JAIL_PORTS=30; fi
            # shellcheck disable=SC2046
            MAX_LENGTH_JAIL_RELEASE="$(find ${bastille_jailsdir}/*/fstab -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h "/releases/.*/root/.bastille.*nullfs" | grep -hE "^USERLAND_VERSION=" $(sed -n "s/^\(.*\) \/.*$/\1\/bin\/freebsd-version/p" | awk '!_[$0]++') | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p" | awk '{ print length($0) }' | sort -nr | head -n 1)"
            MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_JAIL_RELEASE:-7}
            MAX_LENGTH_THICK_JAIL_RELEASE=$(find ${bastille_jailsdir}/*/root/bin/freebsd-version -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -hE "^USERLAND_VERSION=" | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p" | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_THICK_JAIL_RELEASE=${MAX_LENGTH_THICK_JAIL_RELEASE:-7}
            # shellcheck disable=SC2046
            MAX_LENGTH_LINUX_JAIL_RELEASE="$(find ${bastille_jailsdir}/*/fstab -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h "/jails/.*/root/proc.*linprocfs" | grep -hE "^NAME=|^VERSION_ID=|^VERSION_CODENAME=" $(sed -n "s/^linprocfs *\(.*\)\/.*$/\1\/etc\/os-release/p") 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | sed "N;N;s/\n/;/g" | sed -n "s/^NAME=\(.*\);VERSION_ID=\(.*\);VERSION_CODENAME=\(.*\)$/\1 \2 (\3)/p" | awk '{ print length($0) }' | sort -nr | head -n 1)"
            MAX_LENGTH_LINUX_JAIL_RELEASE=${MAX_LENGTH_LINUX_JAIL_RELEASE:-7}
            if [ "${MAX_LENGTH_THICK_JAIL_RELEASE}" -gt "${MAX_LENGTH_JAIL_RELEASE}" ]; then MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_THICK_JAIL_RELEASE}; fi
            if [ "${MAX_LENGTH_LINUX_JAIL_RELEASE}" -gt "${MAX_LENGTH_JAIL_RELEASE}" ]; then MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_LINUX_JAIL_RELEASE}; fi
            if [ "${MAX_LENGTH_JAIL_RELEASE}" -lt 7 ]; then MAX_LENGTH_JAIL_RELEASE=7; fi
            printf " JID%*sName%*sBoot%*sPrio%*sState%*sIP Address%*sPublished Ports%*sRelease%*s\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" "" "$((${SPACER}))" "" "$((${SPACER}))" "" "$((${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} + ${SPACER} - 10))" "" "$((${MAX_LENGTH_JAIL_PORTS} + ${SPACER} - 15))" "" "$((${MAX_LENGTH_JAIL_RELEASE} + ${SPACER} - 7))" ""
            if [ -n "${TARGET}" ]; then
                # Query all info for a specific jail.
                JAIL_LIST="${TARGET}"
            else
                # Query all info for all jails(default).
                JAIL_LIST=$(ls --color=never "${bastille_jailsdir}" | sed "s/\n//g")
            fi

            for _JAIL in ${JAIL_LIST}; do
                if [ -f "${bastille_jailsdir}/${_JAIL}/jail.conf" ]; then
                    JAIL_NAME=$(grep -h -m 1 -e "^.* {$" "${bastille_jailsdir}/${_JAIL}/jail.conf" 2> /dev/null | awk '{ print $1 }')
                    JID="$(jls -j ${_JAIL} jid 2>/dev/null)"
                    BOOT="$(sysrc -f ${bastille_jailsdir}/${_JAIL}/boot.conf -n boot)"
                    PRIORITY="$(sysrc -f ${bastille_jailsdir}/${_JAIL}/boot.conf -n priority)"
                    IS_FREEBSD_JAIL=0
                    if [ -f "${bastille_jailsdir}/${JAIL_NAME}/root/bin/freebsd-version" ] || [ -f "${bastille_jailsdir}/${JAIL_NAME}/root/.bastille/bin/freebsd-version" ] || [ "$(grep -c "/releases/.*/root/.bastille.*nullfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null)" -gt 0 ]; then IS_FREEBSD_JAIL=1; fi
                    IS_FREEBSD_JAIL=${IS_FREEBSD_JAIL:-0}
                    IS_LINUX_JAIL=0
                    if [ "$(grep -c "^linprocfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null)" -gt 0 ]; then IS_LINUX_JAIL=1; fi
                    IS_LINUX_JAIL=${IS_LINUX_JAIL:-0}
                    if [ "$(/usr/sbin/jls name | awk "/^${JAIL_NAME}$/")" ]; then
                        JAIL_STATE="Up"
                        if [ "$(awk '$1 == "vnet;" { print $1 }' "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)" ]; then
                            JAIL_IP=$(jexec -l ${JAIL_NAME} ifconfig -an | grep -v "127.0.0.1" | grep "inet " | awk '{print $2}')
                            if [ ! "${JAIL_IP}" ]; then JAIL_IP=$(jexec -l ${JAIL_NAME} ifconfig -an | grep -v "lo0" | awk '{print $2}'); fi
                        else
                            JAIL_IP=$(bastille config ${JAIL_NAME} get ip4.addr | sed 's/,/\n/g')
                            if [ "${JAIL_IP}" = "not set" ]; then JAIL_IP=$(bastille config ${JAIL_NAME} get ip6.addr | sed 's/,/\n/g'); fi
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
                        JAIL_STATE=$(if [ "$(sed -n "/^${JAIL_NAME} {$/,/^}$/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | awk '$0 ~ /^'${JAIL_NAME}' \{|\}/ { printf "%s",$0 }')" = "${JAIL_NAME} {}" ]; then echo "Down"; else echo "n/a"; fi)
                        if [ "$(awk '$1 == "vnet;" { print $1 }' "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)" ]; then
                            JAIL_IP=$(grep -E "^ifconfig_vnet.*inet.*" "${bastille_jailsdir}/${JAIL_NAME}/root/etc/rc.conf" 2> /dev/null | grep -o "inet.*" | awk '{print $2}' | sed -E 's#/[0-9]+.*##g')
                        else
                            JAIL_IP=$(bastille config ${JAIL_NAME} get ip4.addr | sed 's/,/\n/g')
                            if [ "${JAIL_IP}" = "not set" ]; then JAIL_IP=$(bastille config ${JAIL_NAME} get ip6.addr | sed 's/,/\n/g'); fi
			fi
                        JAIL_HOSTNAME=$(sed -n "s/^[ ]*host.hostname[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)
                        if [ -f "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf" ]; then JAIL_PORTS=$(awk '$1 ~ /^[tcp|udp]/ { printf "%s/%s:%s,",$1,$2,$3 }' "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf" 2> /dev/null | sed "s/,$//"); else JAIL_PORTS=""; fi
                            JAIL_PATH=$(sed -n "s/^[ ]*path[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)
                            if [ "${JAIL_PATH}" ]; then
                                if [ "${IS_FREEBSD_JAIL}" -eq 1 ]; then
                                    if [ -f "${JAIL_PATH}/bin/freebsd-version" ]; then
                                        JAIL_RELEASE=$(grep -hE "^USERLAND_VERSION=" "${JAIL_PATH}/bin/freebsd-version" 2> /dev/null | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p")
                                    else
                                        JAIL_RELEASE=$(grep -h "/releases/.*/root/.bastille.*nullfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null | grep -hE "^USERLAND_VERSION=" "$(sed -n "s/^\(.*\) \/.*$/\1\/bin\/freebsd-version/p" | awk '!_[$0]++')" | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p")
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
                        JID=${JID:-${DEFAULT_VALUE}}
                        BOOT=${BOOT:-${DEFAULT_VALUE}}
                        PRIORITY=${PRIORITY:-${DEFAULT_VALUE}}
                        JAIL_STATE=${JAIL_STATE:-${DEFAULT_VALUE}}
                        JAIL_IP=${JAIL_IP:-${DEFAULT_VALUE}}
                        JAIL_PORTS=${JAIL_PORTS:-${DEFAULT_VALUE}}
                        JAIL_HOSTNAME=${JAIL_HOSTNAME:-${DEFAULT_VALUE}}
                        JAIL_RELEASE=${JAIL_RELEASE:-${DEFAULT_VALUE}}
                        JAIL_PATH=${JAIL_PATH:-${DEFAULT_VALUE}}
                        # Print IPs with commans when JSON is selected
                        if [ "${OPT_JSON}" -eq 1 ]; then JAIL_IP="$(echo ${JAIL_IP} | sed 's/ .*|/,/g')"; fi
                        JAIL_IP_COUNT=$(echo "${JAIL_IP}" | wc -l)
                        if [ ${JAIL_IP_COUNT} -gt 1 ]; then
                            # vnet0 has more than one IPs assigned.
                            # Put each IP in its own line below the jails first address. For instance:
                            #  JID     State  IP Address       Published Ports  Hostname  Release          Path
                            #  foo     Up     10.10.10.10      -                foo       14.0-RELEASE-p5  /usr/local/bastille/jails/foo/root
                            #                 10.10.10.11
                            #                 10.10.10.12
                            FIRST_IP="$(echo "${JAIL_IP}" | head -n 1)"
			                      if echo "${FIRST_IP}" | grep -q "|"; then FIRST_IP=$(echo ${FIRST_IP} | awk -F"|" '{print $2}' | sed 's#/.*##g'); fi
                            printf " ${JID}%*s${JAIL_NAME}%*s${BOOT}%*s${PRIORITY}%*s${JAIL_STATE}%*s${FIRST_IP}%*s${JAIL_PORTS}%*s${JAIL_RELEASE}%*s\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" "" "$((4 - ${#BOOT} + ${SPACER}))" "" "$((4 - ${#PRIORITY} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#FIRST_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
                            for IP in $(echo "${JAIL_IP}" | tail -n +2); do
                                if echo "${IP}" | grep -q "|"; then IP=$(echo ${IP} | awk -F"|" '{print $2}'); fi
                                printf "%*s%*s%*s%*s%*s ${IP}\n" "$((${MAX_LENGTH_JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER}))" "" "$((4 + ${SPACER}))" "" "$((4 + ${SPACER}))" "" "$((5 + ${SPACER}))" ""
                            done
                        else
			                      if echo "${JAIL_IP}" | grep -q "|"; then JAIL_IP="$(echo ${JAIL_IP} | awk -F"|" '{print $2}' | sed 's#/.*##g')"; fi
                            printf " ${JID}%*s${JAIL_NAME}%*s${BOOT}%*s${PRIORITY}%*s${JAIL_STATE}%*s${JAIL_IP}%*s${JAIL_PORTS}%*s${JAIL_RELEASE}%*s\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" "" "$((4 - ${#BOOT} + ${SPACER}))" "" "$((4 - ${#PRIORITY} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#JAIL_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
                        fi
                fi
            done
        else
            error_exit "unfortunately there are no jails here (${bastille_jailsdir})"
        fi
}

# TODO: Check the correct usage or arguments here. See SC2120.
# shellcheck disable=SC2120
list_release(){
    if [ -d "${bastille_releasesdir}" ]; then
        # TODO: Check if this can be changed to `find` as SC2012 suggests.
        # shellcheck disable=SC2012
        REL_LIST="$(ls "${bastille_releasesdir}" | sed "s/\n//g")"
        for _REL in ${REL_LIST}; do
            if [ -f "${bastille_releasesdir}/${_REL}/root/.profile" ] || [ -d "${bastille_releasesdir}/${_REL}/debootstrap" ]; then
                if [ "${1}" = "-p" ] && [ -f "${bastille_releasesdir}/${_REL}/bin/freebsd-version" ]; then
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
        JAIL_LIST=$(ls --color=never "${bastille_jailsdir}" | sed "s/\n//g")
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
    # shellcheck disable=SC2010
    ls "${bastille_backupsdir}" | grep -v ".sha256$"
}

list_ports(){
    if [ -d "${bastille_jailsdir}" ]; then
        JAIL_LIST="$(bastille list jails)"
        for _jail in ${JAIL_LIST}; do
            if [ -f "${bastille_jailsdir}/${_jail}/rdr.conf" ]; then
                _PORTS="$(cat ${bastille_jailsdir}/${_jail}/rdr.conf)"
                info "[${_jail}]:"
		echo "${_PORTS}"
	    fi
        done
    fi
}

bastille_root_check

TARGET=""

# Handle options.
OPT_JSON=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
	-h|--help|help)
	    usage
	    ;;
	-j|--json)
            OPT_JSON=1
	    shift
            ;;
        -x|--debug)
            enable_debug
	    shift
            ;;
        -*)
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    j) OPT_JSON=1 ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\""
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

# List json format, otherwise list all jails
if [ "${OPT_JSON}" -eq 1 ] && [ "$#" -eq 0 ]; then
    list_all | awk 'BEGIN {print "["} NR > 1 {print "  {\"JID\": \"" $1 "\", \"Name\": \"" $2 "\", \"Boot\": \"" $3 "\", \"Prio\": \"" $4 "\", \"State\": \"" $5 "\", \"IP_Address\": \"" $6 "\", \"Published_Ports\": \"" $7 "\", \"Release\": \"" $8 "\","} END {print "]"}' | sed 's/,$//'
elif [ "${OPT_JSON}" -eq 0 ] && [ "$#" -eq 0 ]; then
    list_all
fi

if [ "$#" -gt 0 ]; then
    case "${1}" in
        port|ports)
            list_ports
            ;;
        release|releases)
            list_release "${2}"
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
            TARGET="${1}"
      	    set_target "${TARGET}"
            if [ -f "${bastille_jailsdir}/${TARGET}/jail.conf" ]; then
                if [ "${OPT_JSON}" -eq 1 ]; then
                    list_all | awk 'BEGIN {print "["} NR > 1 {print "  {\"JID\": \"" $1 "\", \"Name\": \"" $2 "\", \"Boot\": \"" $3 "\", \"Prio\": \"" $4 "\", \"State\": \"" $5 "\", \"IP_Address\": \"" $6 "\", \"Published_Ports\": \"" $7 "\", \"Release\": \"" $8 "\","} END {print "]"}' | sed 's/,$//'
                elif [ "${OPT_JSON}" -eq 0 ]; then
                    list_all
                fi
            else
                usage
            fi
            ;;
    esac
fi
