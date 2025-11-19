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
    error_notify "Usage: bastille clone [option(s)] TARGET NEW_NAME IP"
    cat << EOF

    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required. Cannot be used with [-l|--live].
    -l | --live           Clone a running jail (ZFS only). Cannot be used with [-a|--auto].
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
LIVE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -l|--live)
            if ! checkyesno bastille_zfs_enable; then
                error_exit "[-l|--live] can only be used with ZFS."
            else
                LIVE=1
                shift
            fi
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    l) LIVE=1 ;;
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

if [ "${AUTO}" -eq 1 ] && [ "${LIVE}" -eq 1 ]; then
    error_exit "[-a|--auto] cannot be used with [-l|--live]"
fi

if [ $# -ne 3 ]; then
    usage
fi

TARGET="${1}"
NEWNAME="${2}"
IP="${3}"
CLONE_INTERFACE_COUNT=0

bastille_root_check
set_target_single "${TARGET}"

clone_validate_jail_name() {
    if echo "${NEWNAME}" | grep -q "[.]"; then
        error_exit "[ERROR]: Jail names may not contain a dot(.)!"
    fi
}

validate_ip() {

    local _ip="${1}"
    local _ip6="$(echo ${_ip} | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)')"

    if [ -n "${_ip6}" ]; then
    	if [ "${_ip6}" = "SLAAC" ] && [ "$(bastille config ${TARGET} get vnet)" != "enabled" ];  then
            error_exit "[ERROR]: Unsupported IP option for standard jail: (${_ip6})."
        fi
        info "\nValid: (${_ip6})."
        IP6_ADDR="${_ip6}"
    elif [ "${_ip}" = "inherit" ] || [ "${_ip}" = "ip_hostname" ]; then
	        if [ "$(bastille config ${TARGET} get vnet)" = "enabled" ];  then
                error_exit "[ERROR]: Unsupported IP option for VNET jail: (${_ip})."
	        else
                info "\nValid: (${_ip})."
                IP4_ADDR="${_ip}"
                IP6_ADDR="${_ip}"
	        fi
    elif [ "${_ip}" = "0.0.0.0" ] || [ "${_ip}" = "DHCP" ] || [ "${_ip}" = "SYNCDHCP" ]; then
        if [ "$(bastille config ${TARGET} get vnet)" = "enabled" ];  then
            info "\nValid: (${_ip})."
            IP4_ADDR="${_ip}"
        else
            error_exit "[ERROR]: Unsupported IP option for standard jail: (${_ip})."
        fi
    else
        local IFS
        if echo "${_ip}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${_ip}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_continue "Invalid: (${TEST_IP})"
                fi
            done

            if ifconfig | grep -qwF "${TEST_IP}"; then
                warn "\nWarning: IP address already in use (${TEST_IP})."
                IP4_ADDR="${_ip}"
            else
                info "\nValid: (${_ip})."
                IP4_ADDR="${_ip}"
            fi

        else
            error_continue "Invalid: (${_ip})."
        fi
    fi
}

validate_ips() {

    IP4_ADDR=""
    IP6_ADDR=""

    for ip in ${IP}; do
        validate_ip "${ip}"
    done
}

update_jailconf() {

    # Update jail.conf
    JAIL_CONFIG="${bastille_jailsdir}/${NEWNAME}/jail.conf"

    if [ -f "${JAIL_CONFIG}" ]; then
        if ! grep -qw "path = ${bastille_jailsdir}/${NEWNAME}/root;" "${JAIL_CONFIG}"; then
            sed -i '' "s|host.hostname = ${TARGET};|host.hostname = ${NEWNAME};|" "${JAIL_CONFIG}"
            sed -i '' "s|exec.consolelog = .*;|exec.consolelog = ${bastille_logsdir}/${NEWNAME}_console.log;|" "${JAIL_CONFIG}"
            sed -i '' "s|path = .*;|path = ${bastille_jailsdir}/${NEWNAME}/root;|" "${JAIL_CONFIG}"
            sed -i '' "s|mount.fstab = .*;|mount.fstab = ${bastille_jailsdir}/${NEWNAME}/fstab;|" "${JAIL_CONFIG}"
            sed -i '' "s|^${TARGET}.*{$|${NEWNAME} {|" "${JAIL_CONFIG}"
        fi
    fi

    if grep -qw "vnet;" "${JAIL_CONFIG}"; then
        validate_netconf
        update_jailconf_vnet
    else
        _ip4="$(bastille config ${TARGET} get ip4.addr | sed 's/,/ /g')"
        _ip6="$(bastille config ${TARGET} get ip6.addr | sed 's/,/ /g')"
        _interface="$(bastille config ${TARGET} get interface)"
        # Remove old style interface naming in place of new if|ip style
        if [ "${_interface}" != "not set" ]; then
            sed -i '' "/.*interface = .*/d" "${JAIL_CONFIG}"
        fi

        # IP4
        if [ "${_ip4}" != "not set" ]; then
            for _ip in ${_ip4}; do
                if echo ${_ip} | grep -q "|"; then
                    _ip="$(echo ${_ip} | awk -F"|" '{print $2}')"
                fi
                if [ "${_interface}" != "not set" ]; then
                    sed -i '' "s#.*ip4.addr = .*#  ip4.addr = ${_interface}|${IP4_ADDR};#" "${JAIL_CONFIG}"
                else
                    sed -i '' "\#ip4.addr = .*# s#${_ip}#${IP4_ADDR}#" "${JAIL_CONFIG}"
                fi
                sed -i '' "\#ip4.addr += .*# s#${_ip}#127.0.0.1#" "${JAIL_CONFIG}"
            done
        fi

        # IP6
        if [ "${_ip6}" != "not set" ]; then
            for _ip in ${_ip6}; do
                if echo ${_ip} | grep -q "|"; then
                    _ip="$(echo ${_ip} | awk -F"|" '{print $2}')"
                fi
                if [ "${_interface}" != "not set" ]; then
                    sed -i '' "s#.*${_interface} = .*#  ip6.addr = ${_interface}|${IP6_ADDR};/" "${JAIL_CONFIG}"
                else
                    sed -i '' "\#ip6.addr = .*# s#${_ip}#${IP6_ADDR}#" "${JAIL_CONFIG}"
                fi
                sed -i '' "\#ip6.addr += .*# s#${_ip}#::1#" "${JAIL_CONFIG}"
            done
        fi
    fi
}

update_jailconf_vnet() {

    local jail_config="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"

    # Determine number of interfaces
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        local if_list="$(grep -Eo 'e[0-9]+a_[^;" ]+' ${jail_config} | sort -u)"
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local if_list="$(grep -Eo 'ng[0-9]+_[^;" ]+' ${jail_config} | sort -u)"
    fi

    # We need to following to prevent incremental bastille1, bastille2 etc...
    local reuse_new_suffix=""

    for if in ${if_list}; do

        CLONE_INTERFACE_COUNT=$((CLONE_INTERFACE_COUNT + 1))
        local old_if_prefix="$(echo ${if} | awk -F'_' '{print $1}')"
        local old_if_suffix="$(echo ${if} | awk -F'_' '{print $2}')"

        # For if_bridge network type
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then

            local epair_num="$(echo "${old_if_prefix}" | grep -Eo "[0-9]+")"
            local old_host_epair="${if}"
            local old_jail_epair="${old_if_prefix%a}b_${old_if_suffix}"

            if [ "$(echo -n "e${epair_num}a_${NEWNAME}" | awk '{print length}')" -lt 16 ]; then
                # Generate new epair name
                local new_host_epair="e${epair_num}a_${NEWNAME}"
                local new_jail_epair="e${epair_num}b_${NEWNAME}"
            else
                if [ -z "${reuse_new_suffix}" ]; then
                    get_bastille_epair_count
                    local bastille_epair_num=1
                    while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${bastille_epair_num}"; do
                        bastille_epair_num=$((bastille_epair_num + 1))
                    done
                    local new_host_epair="e${epair_num}a_bastille${bastille_epair_num}"
                    local new_jail_epair="e${epair_num}b_bastille${bastille_epair_num}"
                    local reuse_new_suffix="bastille${bastille_epair_num}"
                else
                    local new_host_epair="e${epair_num}a_${reuse_new_suffix}"
                    local new_jail_epair="e${epair_num}b_${reuse_new_suffix}"
                fi
            fi

            local new_if_prefix="$(echo ${new_host_epair} | awk -F'_' '{print $1}')"
            local new_if_suffix="$(echo ${new_host_epair} | awk -F'_' '{print $2}')"

            if grep "${old_if_suffix}" "${jail_config}" | grep -oq "jib addm"; then
                # For -V jails
                # Replace host epair name in jail.conf
                sed -i '' "s|jib addm ${old_if_suffix}\>|jib addm ${new_if_suffix}|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} ether|${new_host_epair} ether|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} destroy|${new_host_epair} destroy|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} description|${new_host_epair} description|g" "${jail_config}"

                # Replace jail epair name in jail.conf
                sed -i '' "s|= ${old_jail_epair};|= ${new_jail_epair};|g" "${jail_config}"
                sed -i '' "s|\<${old_jail_epair} ether|${new_jail_epair} ether|g" "${jail_config}"

                # If jail had a static MAC, generate one for clone
                if grep ether ${jail_config} | grep -qoc ${new_jail_epair}; then
                    local external_interface="$(grep ${new_if_suffix} ${jail_config} | grep -o 'addm.*' | awk '{print $3}' | sed 's/["|;]//g')"
                    generate_static_mac "${NEWNAME}" "${external_interface}"
                    sed -i '' "s|\<${new_jail_epair} ether.*:.*:.*:.*:.*:.*a\";|${new_jail_epair} ether ${macaddr}a\";|" "${jail_config}"
                    sed -i '' "s|\<${new_jail_epair} ether.*:.*:.*:.*:.*:.*b\";|${new_jail_epair} ether ${macaddr}b\";|" "${jail_config}"
                fi

                # Replace epair description
                sed -i '' "s|host interface for Bastille jail ${TARGET}\>|host interface for Bastille jail ${NEWNAME}|g" "${jail_config}"

                # Replace epair name in /etc/rc.conf
                sed -i '' "/ifconfig/ s|\<${old_jail_epair}\>|${new_jail_epair}|g" "${jail_rc_config}"

            else

                # For -B jails
                # Replace host epair name in jail.conf
                sed -i '' "s|up name ${old_host_epair}\>|up name ${new_host_epair}|g" "${jail_config}"
                sed -i '' "s|addm ${old_host_epair}\>|addm ${new_host_epair}|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} ether|${new_host_epair} ether|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} destroy|${new_host_epair} destroy|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} description|${new_host_epair} description|g" "${jail_config}"

                # Replace jail epair name in jail.conf
                sed -i '' "s|= ${old_jail_epair};|= ${new_jail_epair};|g" "${jail_config}"
                sed -i '' "s|up name ${old_jail_epair}\>|up name ${new_jail_epair}|g" "${jail_config}"
                sed -i '' "s|\<${old_jail_epair} ether|${new_jail_epair} ether|g" "${jail_config}"

                # If jail had a static MAC, generate one for clone
                if grep -q ether ${jail_config}; then
                    local external_interface="$(grep "e${epair_num}a" ${jail_config} | grep -o '[^ ]* addm' | awk '{print $1}')"
                    generate_static_mac "${NEWNAME}" "${external_interface}"
                    sed -i '' "s|\<${new_host_epair} ether.*:.*:.*:.*:.*:.*a\";|${new_host_epair} ether ${macaddr}a\";|" "${jail_config}"
                    sed -i '' "s|\<${new_jail_epair} ether.*:.*:.*:.*:.*:.*b\";|${new_jail_epair} ether ${macaddr}b\";|" "${jail_config}"
                fi

                # Replace epair description
                sed -i '' "s|host interface for Bastille jail ${TARGET}\>|host interface for Bastille jail ${NEWNAME}|g" "${jail_config}"

                # Replace epair name in /etc/rc.conf
                sed -i '' "/ifconfig/ s|\<${old_jail_epair}\>|${new_jail_epair}|g" "${jail_rc_config}"

            fi

            # Update /etc/rc.conf
            local jail_vnet="$(grep ${old_jail_epair} "${jail_rc_config}" | grep -Eo -m 1 "vnet[0-9]+")"
            local jail_vnet_vlan="$(grep "vlans_${jail_vnet}" "${jail_rc_config}" | sed 's/.*=//g')"

            # Change epair name
            sed -i '' "s|ifconfig_${old_jail_epair}_name|ifconfig_${new_jail_epair}_name|" "${jail_rc_config}"

            # IP4
            if [ -n "${IP4_ADDR}" ]; then
                if grep "vnet0" "${jail_rc_config}" | grep -q "${new_jail_epair}_name"; then
                    if [ -n "${jail_vnet_vlan}" ]; then
                        if [ "${IP4_ADDR}" = "0.0.0.0" ] || [ "${IP4_ADDR}" = "DHCP" ] || [ "${IP4_ADDR}" = "SYNCDHCP" ]; then
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0_${jail_vnet_vlan}="SYNCDHCP"
                        else
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0_${jail_vnet_vlan}="inet ${IP4_ADDR}"
                        fi
                    else
                        if [ "${IP4_ADDR}" = "0.0.0.0" ] || [ "${IP4_ADDR}" = "DHCP" ] || [ "${IP4_ADDR}" = "SYNCDHCP" ]; then
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0="SYNCDHCP"
                        else
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0="inet ${IP4_ADDR}"
                        fi
                    fi
                else
                    if [ -n "${jail_vnet_vlan}" ]; then
                        sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_${jail_vnet_vlan}=""
                    else
                        sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}=""
                    fi
                fi
            fi

            # IP6
            if [ -n "${IP6_ADDR}" ]; then
                if grep "vnet0" "${jail_rc_config}" | grep -q "${new_jail_epair}_name"; then
                    if [ "${IP6_ADDR}" = "SLAAC" ]; then
                        sysrc -f "${jail_rc_config}" ifconfig_vnet0_ipv6="inet6 -ifdisabled accept_rtadv"
                    else
                        sysrc -f "${jail_rc_config}" ifconfig_vnet0_ipv6="inet6 -ifdisabled ${IP6_ADDR}"
                    fi
                else
                    if [ "${IP6_ADDR}" = "SLAAC" ]; then
                        sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_ipv6="inet6 -ifdisabled accept_rtadv"
                    fi
                fi
            fi

            # Replace epair description
            sed -i '' "/${new_host_epair}/ s|\<${jail_vnet} host interface for Bastille jail ${TARGET}\>|${jail_vnet} host interface for Bastille jail ${NEWNAME}|g" "${jail_config}"

        # Update netgraph VNET (non-bridged) config
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then

            local ngif_num="$(echo "${old_if_prefix}" | grep -Eo "[0-9]+")"
            local old_ngif="${if}"
            # Generate new netgraph interface name
            local new_ngif="ng${ngif_num}_${NEWNAME}"
            # shellcheck disable=SC2034
            local new_if_prefix="$(echo ${if} | awk -F'_' '{print $1}')"
            local new_if_suffix="$(echo ${if} | awk -F'_' '{print $2}')"

            # Replace netgraph interface name
            sed -i '' "s|jng bridge ${old_if_suffix}\>|jng bridge ${new_if_suffix}|g" "${jail_config}"
            sed -i '' "s|\<${old_ngif} ether|${new_ngif} ether|g" "${jail_config}"
            sed -i '' "s|jng shutdown ${old_if_suffix}\>|jng shutdown ${new_if_suffix}|g" "${jail_config}"

            # Replace jail epair name in jail.conf
            sed -i '' "s|= ${old_ngif};|= ${new_ngif};|g" "${jail_config}"

            # Replace epair name in /etc/rc.conf
            sed -i '' "/ifconfig/ s|\<${old_ngif}\>|${new_ngif}|g" "${jail_rc_config}"

            local jail_vnet="$(grep ${if} "${jail_rc_config}" | grep -Eo -m 1 "vnet[0-9]+")"
            local jail_vnet_vlan="$(grep "vlans_${jail_vnet}" "${jail_rc_config}" | sed 's/.*=//g')"

            # If jail had a static MAC, generate one for clone
            if grep ether ${jail_config} | grep -qoc ${new_ngif}; then
                local external_interface="$(grep ${new_if_suffix} ${jail_config} | grep -o 'jng bridge.*' | awk '{print $4}' | sed 's/["|;]//g')"
                generate_static_mac "${NEWNAME}" "${external_interface}"
                sed -i '' "s|\<${new_ngif} ether.*:.*:.*:.*:.*:.*a\";|${new_ngif} ether ${macaddr}a\";|" "${jail_config}"
            fi

            # Update /etc/rc.conf
            sed -i '' "s|ifconfig_${old_ngif}_name|ifconfig_${new_ngif}_name|" "${jail_rc_config}"

            # IP4
            if [ -n "${IP4_ADDR}" ]; then
                if grep "vnet0" "${jail_rc_config}" | grep -q "${new_ngif}_name"; then
                    if [ -n "${jail_vnet_vlan}" ]; then
                        if [ "${IP4_ADDR}" = "0.0.0.0" ] || [ "${IP4_ADDR}" = "DHCP" ] || [ "${IP4_ADDR}" = "SYNCDHCP" ]; then
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0_${jail_vnet_vlan}="SYNCDHCP"
                        else
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0_${jail_vnet_vlan}="inet ${IP4_ADDR}"
                        fi
                    else
                        if [ "${IP4_ADDR}" = "0.0.0.0" ] || [ "${IP4_ADDR}" = "DHCP" ] || [ "${IP4_ADDR}" = "SYNCDHCP" ]; then
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0="SYNCDHCP"
                        else
                            sysrc -f "${jail_rc_config}" ifconfig_vnet0="inet ${IP4_ADDR}"
                        fi
                    fi
                else
                    if [ -n "${jail_vnet_vlan}" ]; then
                        sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_${jail_vnet_vlan}="SYNCDHCP"
                    else
                        sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="SYNCDHCP"
                    fi
                fi
            fi
            # IP6
            if [ -n "${IP6_ADDR}" ]; then
                if grep "vnet0" "${jail_rc_config}" | grep -q "${new_ngif}_name"; then
                    if [ "${IP6_ADDR}" = "SLAAC" ]; then
                        sysrc -f "${jail_rc_config}" ifconfig_vnet0_ipv6="inet6 -ifdisabled accept_rtadv"
                    else
                        sysrc -f "${jail_rc_config}" ifconfig_vnet0_ipv6="inet6 -ifdisabled ${IP6_ADDR}"
                    fi
                else
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_ipv6="inet6 -ifdisabled accept_rtadv"
                fi
            fi
        fi
    done
}

clone_jail() {

    if ! [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then

        if [ -n "${IP}" ]; then
            validate_ips
        else
            usage
        fi

        # Validate proper IP settings
        if [ "$(bastille config ${TARGET} get vnet)" != "not set" ]; then
            # VNET
            if grep -Eoq "ifconfig_vnet0=" "${bastille_jailsdir}/${TARGET}/root/etc/rc.conf"; then
                if [ -z "${IP4_ADDR}" ]; then
                    error_exit "[ERROR]: IPv4 not set. Retry with a proper IPv4 address."
                fi
            fi
            if grep -Eoq "ifconfig_vnet0_ipv6=" "${bastille_jailsdir}/${TARGET}/root/etc/rc.conf"; then
                if [ -z "${IP6_ADDR}" ]; then
                    error_exit "[ERROR]: IPv6 not set. Retry with a proper IPv6 address."
                fi
            fi
        else
            if [ "$(bastille config ${TARGET} get ip4.addr)" != "not set" ]; then
                if [ -z "${IP4_ADDR}" ]; then
                    error_exit "[ERROR]: IPv4 not set. Retry with a proper IPv4 address."
                fi
            elif [ "$(bastille config ${TARGET} get ip6.addr)" != "not set" ]; then
                if [ -z "${IP6_ADDR}" ]; then
                    error_exit "[ERROR]: IPv6 not set. Retry with a proper IPv6 address."
                fi
            fi
        fi

        if checkyesno bastille_zfs_enable; then

            # Validate jail state
            if [ "${LIVE}" -eq 1 ]; then
                if ! check_target_is_running "${TARGET}"; then
                    error_exit "[ERROR]: [-l|--live] can only be used with a running jail."
                fi
            elif ! check_target_is_stopped "${TARGET}"; then
                if [ "${AUTO}" -eq 1 ]; then
                    bastille stop "${TARGET}"
                else
                    info "\n[${TARGET}]:"
                    error_notify "Jail is running."
                    error_exit "Use [-a|--auto] to force stop the jail, or [-l|--live] (ZFS only) to clone a running jail."
                fi
            fi

            if [ -n "${bastille_zfs_zpool}" ]; then
                # Replicate the existing container
                DATE=$(date +%F-%H%M%S)
                zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_clone_${DATE}"
                zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_clone_${DATE}" | zfs recv "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}"

                # Cleanup source temporary snapshots
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_clone_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_clone_${DATE}"

                # Cleanup target temporary snapshots
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}/root@bastille_clone_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}@bastille_clone_${DATE}"
            fi

        else

            check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
                bastille stop "${TARGET}"
            else
                info "\n[${TARGET}]:"
                error_notify "Jail is running."
                error_exit "Use [-a|--auto] to force stop the jail."
            fi

            # Perform container file copy (archive mode)
            cp -a "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"

        fi
    else
        error_exit "[ERROR]: ${NEWNAME} already exists."
    fi

    # Generate jail configuration files
    update_jailconf
    update_fstab "${TARGET}" "${NEWNAME}"

    # Display exit status
    if [ "$?" -ne 0 ]; then
        error_exit "[ERROR]: An error has occurred while attempting to clone '${TARGET}'."
    else
        info "\nCloned '${TARGET}' to '${NEWNAME}' successfully."
        if [ "${CLONE_INTERFACE_COUNT}" -gt 1 ]; then
            info "\nEdit 'rc.conf' to manually set network info for non-default interfaces."
        fi
    fi

    # Start jails if AUTO=1 or LIVE=1
    if [ "${AUTO}" -eq 1 ]; then
        bastille start "${TARGET}"
        bastille start "${NEWNAME}"
    elif [ "${LIVE}" -eq 1 ]; then
        bastille start "${NEWNAME}"
    fi
}

info "\nAttempting to clone '${TARGET}' to '${NEWNAME}'..."

clone_validate_jail_name

clone_jail
