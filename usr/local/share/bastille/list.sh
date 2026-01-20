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
    error_notify "Usage: bastille list [option(s)] [all|backup|export|import|ip|jail|limit]"
    error_notify "                                 [log|path|port|priority|release|snapshot|state|template|type]"
    cat << EOF
    Options:

    -d | --down       List stopped jails only.
    -j | --json       List jails or sub-arg(s) in json format.
    -p | --pretty     Print JSON in columns.
    -u | --up         List running jails only.
    -x | --debug      Enable debug mode.

EOF
    exit 1
}

print_info() {

    # Print jails in given order
    for file in $(echo ${tmp_list} | sort); do
        cat ${file}
        rm -f ${file}
    done
}

pretty_json() {
  sed -e 's/^  {/  {\n    /g' \
      -e 's/,"/,\n    "/g' \
      -e 's/}$/\n  }/g' \
      -e 's/},/\n  },/g' \
      -e 's/^\[\(.*\)\]$/[\n\1\n]/'
}

get_jail_list() {

    # Check if we want only a single jail, or all jails
    if [ -n "${TARGET}" ]; then
        JAIL_LIST="${TARGET}"
    else
        JAIL_LIST="$(ls -v --color=never "${bastille_jailsdir}" | sed "s/\n//g")"
    fi
}

get_max_lengths() {

    if [ -d "${bastille_jailsdir}" ]; then

        # Set default values
        DEFAULT_VALUE="-"
        SPACER=2

        # Set max length for jail name
        MAX_LENGTH_JAIL_NAME=$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h -m 1 -e "^.* {$" | awk '{ print length($1) }' | sort -nr | head -n 1)
        MAX_LENGTH_JAIL_NAME=${MAX_LENGTH_JAIL_NAME:-10}
        if [ "${MAX_LENGTH_JAIL_NAME}" -lt 3 ]; then MAX_LENGTH_JAIL_NAME=3; fi

        # Set max length for jail type
        MAX_LENGTH_JAIL_TYPE=${MAX_LENGTH_JAIL_TYPE:-5}

        # Set max length for JID
        MAX_LENGTH_JID=${MAX_LENGTH_JID:-3}

        # Set max length for jail IPs
        MAX_LENGTH_JAIL_IP=$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 sed -n "s/^[ ].*ip[4,6].addr[ ].*=[ ]\(.*\);$/\1/p" | sed -e 's/\// /g' -e 's/.*|//g' | awk '{ print length($1) }' | sort -nr | head -n 1)
        MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_IP:-10}

        # Set max length for VNET jail IPs
        # shellcheck disable=SC2046
        MAX_LENGTH_JAIL_VNET_IP6="$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -l "vnet;" | grep -h "ifconfig_vnet.*=.*inet6" $(sed -n "s/\(.*\)jail.conf$/\1root\/etc\/rc.conf/p") | grep -Eho "(::)?[0-9a-fA-F]{1,4}(::?[0-9a-fA-F]{1,4}){1,7}(::)?" | sed "s/\// /g" | awk '{print length}' | sort -nr | head -n 1)"
        MAX_LENGTH_JAIL_VNET_IP6=${MAX_LENGTH_JAIL_VNET_IP6:-10}
        # shellcheck disable=SC2046
        MAX_LENGTH_JAIL_VNET_IP="$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -l "vnet;" | grep -h "ifconfig_vnet.*=.*inet " $(sed -n "s/\(.*\)jail.conf$/\1root\/etc\/rc.conf/p") | grep -o "inet .*" | sed -e 's/"//' -e 's#/.*##g' | awk '{print length($2)}' | sort -nr | head -n 1)"
        MAX_LENGTH_JAIL_VNET_IP=${MAX_LENGTH_JAIL_VNET_IP:-10}
        # shellcheck disable=SC2046
        MAX_LENGTH_JAIL_VNET_IP_DHCP="$(find ${bastille_jailsdir}/*/root/etc/rc.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 grep -lE "ifconfig_vnet.*DHCP.*" | sed -E 's|.*/([^/]+)/root/etc/rc.conf|\1|' | xargs -r -P0 -I{} jexec -l {} ifconfig -an 2>&1 | grep "^[[:space:]]*inet " | grep -v "127.0.0.1" | awk '{print $2}' | sed "s/\// /g" | awk '{print length}' | sort -nr | head -n 1)"
        MAX_LENGTH_JAIL_VNET_IP_DHCP=${MAX_LENGTH_JAIL_VNET_IP_DHCP:-10}
        if [ "${MAX_LENGTH_JAIL_VNET_IP_DHCP}" -gt "${MAX_LENGTH_JAIL_IP}" ] && [ "${MAX_LENGTH_JAIL_VNET_IP_DHCP}" -gt "${MAX_LENGTH_JAIL_VNET_IP}" ] && [ "${MAX_LENGTH_JAIL_VNET_IP_DHCP}" -gt "${MAX_LENGTH_JAIL_VNET_IP6}" ]; then MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_VNET_IP_DHCP}
        elif [ "${MAX_LENGTH_JAIL_VNET_IP}" -gt "${MAX_LENGTH_JAIL_IP}" ] && [ "${MAX_LENGTH_JAIL_VNET_IP}" -gt "${MAX_LENGTH_JAIL_VNET_IP_DHCP}" ] && [ "${MAX_LENGTH_JAIL_VNET_IP}" -gt "${MAX_LENGTH_JAIL_VNET_IP6}" ]; then MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_VNET_IP}
        elif [ "${MAX_LENGTH_JAIL_VNET_IP6}" -gt "${MAX_LENGTH_JAIL_IP}" ] && [ "${MAX_LENGTH_JAIL_VNET_IP6}" -gt "${MAX_LENGTH_JAIL_VNET_IP}" ] && [ "${MAX_LENGTH_JAIL_VNET_IP6}" -gt "${MAX_LENGTH_JAIL_VNET_IP_DHCP}" ]; then MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_VNET_IP6}; fi
        if [ "${MAX_LENGTH_JAIL_IP}" -lt 10 ]; then MAX_LENGTH_JAIL_IP=10; fi

        # Set max length for jail hostname
        MAX_LENGTH_JAIL_HOSTNAME=$(find ${bastille_jailsdir}/*/jail.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h -m 1 -e "^[ ]*host.hostname[ ]*=[ ]*\(.*\);" | awk '{ print length(substr($3, 1, length($3)-1)) }' | sort -nr | head -n 1)
        MAX_LENGTH_JAIL_HOSTNAME=${MAX_LENGTH_JAIL_HOSTNAME:-8}
        if [ "${MAX_LENGTH_JAIL_HOSTNAME}" -lt 8 ]; then MAX_LENGTH_JAIL_HOSTNAME=8; fi

        # Set max length for jail ports (active)
        MAX_LENGTH_JAIL_PORTS=$(find ${bastille_jailsdir}/*/rdr.conf -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 -n1 awk '{ lines++; chars += length($0)} END { chars += lines - 1; print chars }' | sort -nr | head -n 1)
        MAX_LENGTH_JAIL_PORTS=${MAX_LENGTH_JAIL_PORTS:-15}
        if [ "${MAX_LENGTH_JAIL_PORTS}" -lt 15 ]; then MAX_LENGTH_JAIL_PORTS=15; fi
        if [ "${MAX_LENGTH_JAIL_PORTS}" -gt 30 ]; then MAX_LENGTH_JAIL_PORTS=30; fi

        # Set max length for freebsd jail release
        # shellcheck disable=SC2046
        MAX_LENGTH_JAIL_RELEASE="$(find ${bastille_jailsdir}/*/fstab -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -hs "/releases/.*/root/.bastille.*nullfs" | grep -hEs "^USERLAND_VERSION=" $(sed -n "s/^\(.*\) \/.*$/\1\/bin\/freebsd-version/p" | awk '!_[$0]++') | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p" | awk '{ print length($0) }' | sort -nr | head -n 1)"
        MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_JAIL_RELEASE:-7}
        MAX_LENGTH_THICK_JAIL_RELEASE=$(find ${bastille_jailsdir}/*/root/bin/freebsd-version -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -hEs "^USERLAND_VERSION=" | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p" | awk '{ print length($0) }' | sort -nr | head -n 1)
        MAX_LENGTH_THICK_JAIL_RELEASE=${MAX_LENGTH_THICK_JAIL_RELEASE:-7}

        # Set max length for linux jail release
        # shellcheck disable=SC2046
        MAX_LENGTH_LINUX_JAIL_RELEASE="$(find ${bastille_jailsdir}/*/fstab -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 grep -h "/jails/.*/root/proc.*linprocfs" | grep -hE "^NAME=|^VERSION_ID=|^VERSION_CODENAME=" $(sed -n "s/^linprocfs *\(.*\)\/.*$/\1\/etc\/os-release/p") 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | sed "N;N;s/\n/;/g" | sed -n "s/^NAME=\(.*\);VERSION_ID=\(.*\);VERSION_CODENAME=\(.*\)$/\1 \2 (\3)/p" | awk '{ print length($0) }' | sort -nr | head -n 1)"
        MAX_LENGTH_LINUX_JAIL_RELEASE=${MAX_LENGTH_LINUX_JAIL_RELEASE:-7}
        if [ "${MAX_LENGTH_THICK_JAIL_RELEASE}" -gt "${MAX_LENGTH_JAIL_RELEASE}" ]; then MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_THICK_JAIL_RELEASE}; fi
        if [ "${MAX_LENGTH_LINUX_JAIL_RELEASE}" -gt "${MAX_LENGTH_JAIL_RELEASE}" ]; then MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_LINUX_JAIL_RELEASE}; fi
        if [ "${MAX_LENGTH_JAIL_RELEASE}" -lt 7 ]; then MAX_LENGTH_JAIL_RELEASE=7; fi

        # Set max length for tags
        # Don't need these now as they are the last thing printed
        #MAX_LENGTH_JAIL_TAGS=$(find ${bastille_jailsdir}/*/tags -maxdepth 1 -type f -print0 2> /dev/null | xargs -r0 -P0 -n1 sh -c 'grep -h . "$1" | paste -sd "," -' sh | awk '{print length}' | sort -nr | head -n 1)
        #MAX_LENGTH_JAIL_TAGS=${MAX_LENGTH_JAIL_TAG:-10}

    else
        error_exit "[ERROR]: No jails found."
    fi
}

get_jail_info() {

    JAIL_NAME="${1}"

    # Get jail name
    JAIL_NAME=$(grep -h -m 1 -e "^.* {$" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | awk '{ print $1 }')

    # Get JID value
    JID="$(jls -j ${JAIL_NAME} jid 2>/dev/null)"

    # Get jail tags
    JAIL_TAGS=""
    if [ -f "${bastille_jailsdir}/${JAIL_NAME}/tags" ]; then
        JAIL_TAGS="$(paste -sd, ${bastille_jailsdir}/${JAIL_NAME}/tags)"
    fi

    # Get boot and priority value using 'bastille config'
    BOOT="$(sysrc -f ${bastille_jailsdir}/${JAIL_NAME}/settings.conf -n boot)"
    PRIORITY="$(sysrc -f ${bastille_jailsdir}/${JAIL_NAME}/settings.conf -n priority)"

    # Check if jail is FreeBSD or Linux
    IS_FREEBSD_JAIL=0
    if [ -f "${bastille_jailsdir}/${JAIL_NAME}/root/bin/freebsd-version" ] || [ -f "${bastille_jailsdir}/${JAIL_NAME}/root/.bastille/bin/freebsd-version" ] || [ "$(grep -c "/releases/.*/root/.bastille.*nullfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null)" -gt 0 ]; then IS_FREEBSD_JAIL=1; fi
    IS_FREEBSD_JAIL=${IS_FREEBSD_JAIL:-0}
    IS_LINUX_JAIL=0
    if [ "$(grep -c "^linprocfs.*${bastille_jailsdir}/${JAIL_NAME}/proc.*linprocfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null)" -gt 0 ]; then IS_LINUX_JAIL=1; fi
    IS_LINUX_JAIL=${IS_LINUX_JAIL:-0}

    # Get jail type
    if grep -qw "${bastille_jailsdir}/${JAIL_NAME}/root/.bastille" "${bastille_jailsdir}/${JAIL_NAME}/fstab"; then
        JAIL_TYPE="thin"
    elif [ "${IS_LINUX_JAIL}" -eq 1 ] && [ "${IS_FREEBSD_JAIL}" -eq 0 ]; then
        JAIL_TYPE="linux"
    elif checkyesno bastille_zfs_enable; then
        if [ "$(zfs get -H -o value origin ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${JAIL_NAME}/root)" != "-" ]; then
            JAIL_TYPE="clone"
        else
            JAIL_TYPE="thick"
        fi
    else
        JAIL_TYPE="thick"
    fi

    # Gather variable that depend on jail being UP or DOWN
    if [ "$(/usr/sbin/jls name | awk "/^${JAIL_NAME}$/")" ]; then

        JAIL_STATE="Up"

        # Get info if jail is UP
        if [ "$(awk '$1 == "vnet;" { print $1 }' "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)" ]; then
            # Get IP for VNET jails
            JAIL_IP4="$(jexec -l ${JAIL_NAME} ifconfig -an | grep "^[[:space:]]*inet " | grep -v "127.0.0.1" | awk '{print $2}')"
            JAIL_IP6="$(jexec -l ${JAIL_NAME} ifconfig -an | grep "^[[:space:]]*inet6" | grep -Ev 'lo[0-9]+| ::1 | fe80::' | awk '{print $2}' | sed 's/%.*//g')"
        else
            # Get IP for standard jails
            JAIL_IP4=$(jls -j ${JAIL_NAME} ip4.addr | sed 's/,/\n/g')
            JAIL_IP6=$(jls -j ${JAIL_NAME} ip6.addr | sed 's/,/\n/g')
        fi
        JAIL_IP="$(printf '%s\n%s' "${JAIL_IP4}" "${JAIL_IP6}" | sed -e '/^-$/d' -e '/^$/d')"

        # Print IPs with commans when JSON is selected
        JAIL_IP_FULL="$(echo ${JAIL_IP} | sed 's/ /,/g')"
        if [ "${OPT_JSON}" -eq 1 ]; then JAIL_IP="${JAIL_IP_FULL}"; fi

        # Get jail path
        JAIL_PATH=$(/usr/sbin/jls -j ${JAIL_NAME} path 2> /dev/null)

        # Get jail hostname
        JAIL_HOSTNAME=$(/usr/sbin/jls -j ${JAIL_NAME} host.hostname 2> /dev/null)

        # Get jail ports (active)
        JAIL_PORTS=$(pfctl -a "rdr/${JAIL_NAME}" -Psn 2> /dev/null | awk '{ printf "%s/%s:%s"",",$7,$14,$18 }' | sed "s/,$//")

        # Get release (FreeBSD or Linux)
        if [ "${IS_FREEBSD_JAIL}" -eq 1 ]; then
            JAIL_RELEASE=$(jexec -l ${JAIL_NAME} freebsd-version -u 2> /dev/null)
        elif [ "${IS_LINUX_JAIL}" -eq 1 ]; then
            JAIL_RELEASE=$(grep -hE "^NAME=.*$|^VERSION_ID=.*$|^VERSION_CODENAME=.*$" "${JAIL_PATH}/etc/os-release" 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | awk -F'=' '{ a[$1] = $2; o++ } o%3 == 0 { print a["VERSION_CODENAME"] " (" a["NAME"] " " a["VERSION_ID"] ")" }')
        fi

    else

        # Set state to Down or n/a
        JAIL_STATE=$(if [ "$(sed -n "/^${JAIL_NAME} {$/,/^}$/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | awk '$0 ~ /^'"${JAIL_NAME}"' \{$/ || $0 ~ /^\}$/ { printf "%s", $0 }')" = "${JAIL_NAME} {}" ]; then echo "Down"; else echo "n/a"; fi)

        # Get info if jail is DOWN
        if [ "$(awk '$1 == "vnet;" { print $1 }' "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)" ]; then
            JAIL_IP4=$(grep -E "^ifconfig_vnet.*inet .*" "${bastille_jailsdir}/${JAIL_NAME}/root/etc/rc.conf" 2> /dev/null | grep -o "inet .*" | awk '{print $2}' | sed -E 's#/[0-9]+.*##g' | sed 's/"//g')
            JAIL_IP6=$(grep -E "^ifconfig_vnet.*inet6.*" "${bastille_jailsdir}/${JAIL_NAME}/root/etc/rc.conf" 2> /dev/null | grep -Eow "(::)?[0-9a-fA-F]{1,4}(::?[0-9a-fA-F]{1,4}){1,7}(::)?" | sed -E 's#/[0-9]+.*##g' | sed 's/"//g')
        else
            JAIL_IP4=$(sed -n "s/^[ ].*ip4.addr[ ].*=[ ]\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | sed -e 's#/.*##g' -e 's#.*|##g')
            JAIL_IP6=$(sed -n "s/^[ ].*ip6.addr[ ].*=[ ]\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null | sed -e 's#/.*##g' -e 's#.*|##g')
        fi
        JAIL_IP="$(printf '%s\n%s' "${JAIL_IP4}" "${JAIL_IP6}" | sed -e '/^-$/d' -e '/^$/d')"

        JAIL_IP_FULL="$(echo ${JAIL_IP} | sed 's/ /,/g')"
        if [ "${OPT_JSON}" -eq 1 ]; then JAIL_IP="${JAIL_IP_FULL}"; fi

        # Set jail path
        JAIL_PATH=$(sed -n "s/^[ ]*path[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)

        # Get jail hostname
        JAIL_HOSTNAME=$(sed -n "s/^[ ]*host.hostname[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${JAIL_NAME}/jail.conf" 2> /dev/null)

        # Get jail ports (inactive)
        if [ -f "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf" ]; then JAIL_PORTS=$(awk '$1 ~ /^[tcp|udp]/ { printf "%s/%s:%s,",$1,$2,$3 }' "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf" 2> /dev/null | sed "s/,$//"); else JAIL_PORTS=""; fi

        # Get jail release (FreeBSD or Linux)
        if [ -n "${JAIL_PATH}" ]; then
            if [ "${IS_FREEBSD_JAIL}" -eq 1 ]; then
                if [ -f "${JAIL_PATH}/bin/freebsd-version" ]; then
                    JAIL_RELEASE=$(grep -Ehs "^USERLAND_VERSION=" "${JAIL_PATH}/bin/freebsd-version" 2> /dev/null | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p")
                else
                    JAIL_RELEASE=$(grep -hs "/releases/.*/root/.bastille.*nullfs" "${bastille_jailsdir}/${JAIL_NAME}/fstab" 2> /dev/null | grep -Ehs "^USERLAND_VERSION=" "$(sed -n "s/^\(.*\) \/.*$/\1\/bin\/freebsd-version/p" | awk '!_[$0]++')" | sed "s/[\"\'\^]//g;s/ .*$//g" | sed -n "s/^USERLAND_VERSION=\(.*\)$/\1/p")
                fi
            fi
            if [ "${IS_LINUX_JAIL}" -eq 1 ]; then
                JAIL_RELEASE=$(grep -hE "^NAME=.*$|^VERSION_ID=.*$|^VERSION_CODENAME=.*$" "${JAIL_PATH}/etc/os-release" 2> /dev/null | sed "s/\"//g" | sed "s/ GNU\/Linux//g" | awk -F'=' '{ a[$1] = $2; o++ } o%3 == 0 { print a["VERSION_CODENAME"] " (" a["NAME"] " " a["VERSION_ID"] ")" }')
            fi
        else
            JAIL_RELEASE=""
        fi
    fi

    # Continue if STATE doesnt match chosen options
    if [ "${OPT_STATE}" != "all" ] && [ "${JAIL_STATE}" != "${OPT_STATE}" ]; then
        # shellcheck disable=SC2104
        continue
    fi

    # Add ... if JAIL_PORTS is too long
    JAIL_PORTS_FULL="${JAIL_PORTS}"
    if [ "${#JAIL_PORTS}" -gt "${MAX_LENGTH_JAIL_PORTS}" ]; then JAIL_PORTS="$(echo ${JAIL_PORTS} | cut -c-$((${MAX_LENGTH_JAIL_PORTS} - 3)))..."; fi

    # Set default value (-) if empty
    BOOT=${BOOT:-${DEFAULT_VALUE}}
    JAIL_HOSTNAME=${JAIL_HOSTNAME:-${DEFAULT_VALUE}}
    JAIL_IP=${JAIL_IP:-${DEFAULT_VALUE}}
    JAIL_NAME=${JAIL_NAME:-${DEFAULT_VALUE}}
    JAIL_PATH=${JAIL_PATH:-${DEFAULT_VALUE}}
    JAIL_PORTS=${JAIL_PORTS:-${DEFAULT_VALUE}}
    JAIL_PORTS_FULL=${JAIL_PORTS_FULL:-${DEFAULT_VALUE}}
    JAIL_RELEASE=${JAIL_RELEASE:-${DEFAULT_VALUE}}
    JAIL_STATE=${JAIL_STATE:-${DEFAULT_VALUE}}
    JAIL_TAGS=${JAIL_TAGS:-${DEFAULT_VALUE}}
    JAIL_TYPE=${JAIL_TYPE:-${DEFAULT_VALUE}}
    JID=${JID:-${DEFAULT_VALUE}}
    PRIORITY=${PRIORITY:-${DEFAULT_VALUE}}
}

list_bastille(){

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sName%*sBoot%*sPrio%*sState%*sType%*sIP Address%*sPublished Ports%*sRelease%*sTags\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" "" "$((${SPACER}))" "" "$((${SPACER}))" "" "$((${SPACER}))" "" "$((${MAX_LENGTH_JAIL_TYPE} + ${SPACER} - 4))" "" "$((${MAX_LENGTH_JAIL_IP} + ${SPACER} - 10))" "" "$((${MAX_LENGTH_JAIL_PORTS} + ${SPACER} - 15))" "" "$((${MAX_LENGTH_JAIL_RELEASE} + ${SPACER} - 7))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        # Get JAIL_IP count
        JAIL_IP_COUNT=$(echo "${JAIL_IP}" | wc -l)

        # Print JAIL_IP in columns if -gt 1
        if [ ${JAIL_IP_COUNT} -gt 1 ]; then
            # vnet0 has more than one IPs assigned.
            # Put each IP in its own line below the jails first address. For instance:
            #  JID     State  IP Address       Published Ports  Hostname  Release          Path
            #  foo     Up     10.10.10.10      -                foo       14.0-RELEASE-p5  /usr/local/bastille/jails/foo/root
            #                 10.10.10.11
            #                 10.10.10.12
            FIRST_IP="$(echo "${JAIL_IP}" | head -n 1)"
            printf " ${JID}%*s${JAIL_NAME}%*s${BOOT}%*s${PRIORITY}%*s${JAIL_STATE}%*s${JAIL_TYPE}%*s${FIRST_IP}%*s${JAIL_PORTS}%*s${JAIL_RELEASE}%*s${JAIL_TAGS}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" "" "$((4 - ${#BOOT} + ${SPACER}))" "" "$((4 - ${#PRIORITY} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_TYPE} - ${#JAIL_TYPE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#FIRST_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
            for IP in $(echo "${JAIL_IP}" | tail -n +2); do
                printf "%*s%*s%*s%*s%*s%*s ${IP}\n" "$((${MAX_LENGTH_JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER}))" "" "$((4 + ${SPACER}))" "" "$((4 + ${SPACER}))" "" "$((5 + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_TYPE} + ${SPACER}))" ""
            done
        else
            printf " ${JID}%*s${JAIL_NAME}%*s${BOOT}%*s${PRIORITY}%*s${JAIL_STATE}%*s${JAIL_TYPE}%*s${JAIL_IP}%*s${JAIL_PORTS}%*s${JAIL_RELEASE}%*s${JAIL_TAGS}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" "" "$((4 - ${#BOOT} + ${SPACER}))" "" "$((4 - ${#PRIORITY} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_TYPE} - ${#JAIL_TYPE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#JAIL_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
        fi

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

list_all(){

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sBoot%*sPrio%*sState%*sIP Address%*sPublished Ports%*sHostname%*sRelease%*sPath\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${SPACER}))" "" "$((${SPACER}))" "" "$((${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} + ${SPACER} - 10))" "" "$((${MAX_LENGTH_JAIL_PORTS} + ${SPACER} - 15))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} + ${SPACER} - 8))" "" "$((${MAX_LENGTH_JAIL_RELEASE} + ${SPACER} - 7))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        # Get jail IP count
        JAIL_IP_COUNT=$(echo "${JAIL_IP}" | wc -l)

        if [ ${JAIL_IP_COUNT} -gt 1 ]; then
            # vnet0 has more than one IPs assigned.
            # Put each IP in its own line below the jails first address. For instance:
            #  JID     State  IP Address       Published Ports  Hostname  Release          Path
            #  foo     Up     10.10.10.10      -                foo       14.0-RELEASE-p5  /usr/local/bastille/jails/foo/root
            #                 10.10.10.11
            #                 10.10.10.12
            FIRST_IP="$(echo "${JAIL_IP}" | head -n 1)"
            printf " ${JID}%*s${BOOT}%*s${PRIORITY}%*s${JAIL_STATE}%*s${FIRST_IP}%*s${JAIL_PORTS}%*s${JAIL_HOSTNAME}%*s${JAIL_RELEASE}%*s${JAIL_PATH}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((4 - ${#BOOT} + ${SPACER}))" "" "$((4 - ${#PRIORITY} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#FIRST_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} - ${#JAIL_HOSTNAME} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
            for IP in $(echo "${JAIL_IP}" | tail -n +2); do
                printf "%*s%*s%*s%*s ${IP}\n" "$((${MAX_LENGTH_JID} + ${SPACER}))" "" "$((4 + ${SPACER}))" "" "$((4 + ${SPACER}))" "" "$((5 + ${SPACER}))" ""
            done
        else
            if echo "${JAIL_IP}" | grep -q "|"; then JAIL_IP="$(echo ${JAIL_IP} | awk -F"|" '{print $2}' | sed 's#/.*##g')"; fi
            printf " ${JID}%*s${BOOT}%*s${PRIORITY}%*s${JAIL_STATE}%*s${JAIL_IP}%*s${JAIL_PORTS}%*s${JAIL_HOSTNAME}%*s${JAIL_RELEASE}%*s${JAIL_PATH}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((4 - ${#BOOT} + ${SPACER}))" "" "$((4 - ${#PRIORITY} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#JAIL_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} - ${#JAIL_HOSTNAME} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
        fi

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

list_ips() {

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sName%*sIP Address\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        printf " ${JID}%*s${JAIL_NAME}%*s${JAIL_IP_FULL}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" ""

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

list_paths() {

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sName%*sPath\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        printf " ${JID}%*s${JAIL_NAME}%*s${JAIL_PATH}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" ""

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

list_ports() {

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sName%*sPublished Ports\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        printf " ${JID}%*s${JAIL_NAME}%*s${JAIL_PORTS_FULL}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" ""

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

list_state() {

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sName%*sState\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        printf " ${JID}%*s${JAIL_NAME}%*s${JAIL_STATE}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" ""

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

list_type() {

    tmp_list=

    get_max_lengths
    get_jail_list

    # Print header
    printf " JID%*sName%*sType\n" "$((${MAX_LENGTH_JID} + ${SPACER} - 3))" "" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 4))" ""

    for jail in ${JAIL_LIST}; do

        # Validate jail.conf existence
        if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
            tmp_jail=$(mktemp /tmp/bastille-list-${jail})
        else
            continue
        fi

        (

        get_jailinfo 1 "${jail}"

        printf " ${JID}%*s${JAIL_NAME}%*s${JAIL_TYPE}\n" "$((${MAX_LENGTH_JID} - ${#JID} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_NAME} - ${#JAIL_NAME} + ${SPACER}))" ""

        ) > "${tmp_jail}" &

        tmp_list="$(printf "%s\n%s" "${tmp_list}" "${tmp_jail}")"

    done
    wait

    print_info
}

# TODO: Check the correct usage or arguments here. See SC2120.
# shellcheck disable=SC2120
list_release() {

    if [ -d "${bastille_releasesdir}" ]; then
        # TODO: Check if this can be changed to `find` as SC2012 suggests.
        # shellcheck disable=SC2012
        release_list="$(ls -v --color=never "${bastille_releasesdir}" | sed "s/\n//g")"
        for release in ${release_list}; do
            if [ -f "${bastille_releasesdir}/${release}/COPYRIGHT" ] || [ -d "${bastille_releasesdir}/${release}/debootstrap" ]; then
                if [ "${1}" = "-p" ] && [ -f "${bastille_releasesdir}/${release}/bin/freebsd-version" ]; then
                    release_patch=$(sed -n "s/^USERLAND_VERSION=\"\(.*\)\"$/\1/p" "${bastille_releasesdir}/${release}/bin/freebsd-version" 2> /dev/null)
                    release_patch=${release_patch:-${release}}
                    info 3 "${release_patch}"
                else
                    info 3 "${release}"
                fi
            fi
        done
    fi
}

list_snapshot(){
    # TODO: Ability to list snapshot data for a single target.
    # List snapshots with its usage data for valid bastille jails only.
    if [ -d "${bastille_jailsdir}" ]; then
        jail_list=$(ls -v --color=never "${bastille_jailsdir}" | sed "s/\n//g")
        for jail in ${jail_list}; do
            if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
                info 1 "\n[${jail}]:"
                zfs list -r -t snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${jail}"
            fi
        done
    fi
}

list_template(){
    find "${bastille_templatesdir}" -type d -maxdepth 2 | sed "s#${bastille_templatesdir}/##g"
}

list_jail(){
    if [ -d "${bastille_jailsdir}" ]; then
        jail_list=$(ls -v --color=never "${bastille_jailsdir}" | sed "s/\n//g")
        for jail in ${jail_list}; do
            if [ -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
                info 3 "${jail}"
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
    ls -v "${bastille_backupsdir}" | grep -v ".sha256$"
}

bastille_root_check

TARGET=""

# Handle options.
OPT_JSON=0
OPT_PRETTY=0
OPT_STATE="all"
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -d|--down)
            OPT_STATE="Down"
            shift
            ;;
        -j|--json)
            OPT_JSON=1
            shift
            ;;
        -p|--pretty)
            OPT_PRETTY=1
            OPT_JSON=1
            shift
            ;;
        -u|--up)
            OPT_STATE="Up"
            shift
            ;;
        -x|--debug)
            enable_debug
	    shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    a) error_exit "[ERROR]: \"-a\" is deprecated. Use \"all\" instead." ;;
                    d) OPT_STATE="Down" ;;
                    j) OPT_JSON=1 ;;
                    p) OPT_PRETTY=1 ;;
                    u) OPT_STATE="Up" ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\""
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Clear tmp directory
rm -rf /tmp/bastille-list-*

# Perform basic list if no args
if [ "$#" -eq 0 ]; then
    # List json format, otherwise list all jails
    if [ "${OPT_JSON}" -eq 1 ]; then
        if [ "${OPT_PRETTY}" -eq 1 ]; then
            list_bastille | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Boot\":\"%s\",\"Prio\":\"%s\",\"State\":\"%s\",\"Type\":\"%s\",\"IP Address\":\"%s\",\"Published Ports\":\"%s\",\"Release\":\"%s\",\"Tags\":\"%s\"}",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10} END{print "\n]"}' | pretty_json
        else
            list_bastille | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Boot\":\"%s\",\"Prio\":\"%s\",\"State\":\"%s\",\"Type\":\"%s\",\"IP Address\":\"%s\",\"Published Ports\":\"%s\",\"Release\":\"%s\",\"Tags\":\"%s\"}",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10} END{print "\n]"}'
        fi
    else
        list_bastille
    fi
elif [ "$#" -eq 2 ]; then
    set_target "${1}" || exit 1
    shift 1
fi

if [ "$#" -eq 1 ]; then
    case "${1}" in
        -a|--all|all)
            if [ "${OPT_JSON}" -eq 1 ]; then
                if [ "${OPT_PRETTY}" -eq 1 ]; then
                    list_all | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Boot\":\"%s\",\"Prio\":\"%s\",\"State\":\"%s\",\"IP Address\":\"%s\",\"Published Ports\":\"%s\",\"Hostname\":\"%s\",\"Release\":\"%s\",\"Path\":\"%s\"}",$1,$2,$3,$4,$5,$6,$7,$8,$9} END{print "\n]"}' | pretty_json
                else
                    list_all | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Boot\":\"%s\",\"Prio\":\"%s\",\"State\":\"%s\",\"IP Address\":\"%s\",\"Published Ports\":\"%s\",\"Hostname\":\"%s\",\"Release\":\"%s\",\"Path\":\"%s\"}",$1,$2,$3,$4,$5,$6,$7,$8,$9} END{print "\n]"}'
                fi
            else
                list_all
            fi
            ;;
        ip|ips)
            if [ "${OPT_JSON}" -eq 1 ]; then
                if [ "${OPT_PRETTY}" -eq 1 ]; then
                    list_ips | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"IP Address\":\"%s\"}",$1,$2,$3} END{print "\n]"}' | pretty_json
                else
                    list_ips | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"IP Address\":\"%s\"}",$1,$2,$3} END{print "\n]"}'
                fi
            else
                list_ips
            fi
            ;;
        path|paths)
            if [ "${OPT_JSON}" -eq 1 ]; then
                if [ "${OPT_PRETTY}" -eq 1 ]; then
                    list_paths | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Path\":\"%s\"}",$1,$2,$3} END{print "\n]"}' | pretty_json
                else
                    list_paths | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Path\":\"%s\"}",$1,$2,$3} END{print "\n]"}'
                fi
            else
                list_paths
            fi
            ;;
        rdr|port|ports)
            if [ "${OPT_JSON}" -eq 1 ]; then
                if [ "${OPT_PRETTY}" -eq 1 ]; then
                    list_ports | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Published Ports\":\"%s\"}",$1,$2,$3} END{print "\n]"}' | pretty_json
                else
                    list_ports | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Published Ports\":\"%s\"}",$1,$2,$3} END{print "\n]"}'
                fi
            else
                list_ports
            fi
            ;;
        state|status)
            if [ "${OPT_JSON}" -eq 1 ]; then
                if [ "${OPT_PRETTY}" -eq 1 ]; then
                    list_state | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"State\":\"%s\"}",$1,$2,$3} END{print "\n]"}' | pretty_json
                else
                    list_state | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"State\":\"%s\"}",$1,$2,$3} END{print "\n]"}'
                fi
            else
                list_state
            fi
            ;;
        type|jailtype)
            if [ "${OPT_JSON}" -eq 1 ]; then
                if [ "${OPT_PRETTY}" -eq 1 ]; then
                    list_type | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Type\":\"%s\"}",$1,$2,$3} END{print "\n]"}' | pretty_json
                else
                    list_type | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Type\":\"%s\"}",$1,$2,$3} END{print "\n]"}'
                fi
            else
                list_type
            fi
            ;;
        release|releases)
            list_release "-p"
            ;;
        snap|snapshot|snapshots)
            list_snapshot
            exit 0
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
                    list_bastille | awk 'BEGIN{print "["} NR>1{if(NR>2)print ","; printf "  {\"JID\":\"%s\",\"Name\":\"%s\",\"Boot\":\"%s\",\"Prio\":\"%s\",\"State\":\"%s\",\"Type\":\"%s\",\"IP Address\":\"%s\",\"Published Ports\":\"%s\",\"Release\":\"%s\",\"Tags\":\"%s\"}",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10} END{print "\n]"}'
                else
                    list_bastille
                fi
            else
                usage
            fi
            ;;
    esac
fi
