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
    error_notify "Usage: bastille clone [option(s)] TARGET NEWNAME IPADDRESS"
    cat << EOF
	
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required. Cannot be used with [-l|--live].
    -l | --live           Clone a running jail. ZFS only. Jail must be running. Cannot be used with [-a|--auto].
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

if [ "${AUTO}" -eq 1 ] && [ "${LIVE}" -eq 1 ]; then
    error_exit "[-a|--auto] cannot be used with [-l|--live]"
fi

if [ $# -ne 3 ]; then
    usage
fi

TARGET="${1}"
NEWNAME="${2}"
IP="${3}"

bastille_root_check
set_target_single "${TARGET}"

## don't allow for dots(.) in container names
if echo "${NEWNAME}" | grep -q "[.]"; then
    error_exit "Container names may not contain a dot(.)!"
fi

validate_ip() {

    local IP="${1}"
    IP6_MODE="disable"
    ip6=$(echo "${IP}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$))')

    if [ -n "${ip6}" ]; then
        info "Valid: (${ip6})."
        IP6_MODE="new"
    elif { [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; } && [ "$(bastille config ${TARGET} get vnet)" = "enabled" ];  then
        info "\nValid: (${IP})."
    else
        local IFS
        if echo "${IP}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${IP}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "Invalid: (${TEST_IP})"
                fi
            done
            if ifconfig | grep -qwF "${TEST_IP}"; then
                warn "Warning: IP address already in use (${TEST_IP})."
            else
                info "\nValid: (${IP})."
            fi
        else
            error_exit "Invalid: (${IP})."
        fi
    fi
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
            sed -i '' "s|${TARGET} {|${NEWNAME} {|" "${JAIL_CONFIG}"
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
                    sed -i '' "s/.*ip4.addr = .*/  ip4.addr = ${_interface}|${IP};/" "${JAIL_CONFIG}"
                else
                    sed -i '' "/ip4.addr = .*/ s/${_ip}/${IP}/" "${JAIL_CONFIG}"
                fi
                sed -i '' "/ip4.addr += .*/ s/${_ip}/127.0.0.1/" "${JAIL_CONFIG}"
            done
        fi

        # IP6
        if [ "${_ip6}" != "not set" ]; then
            for _ip in ${_ip6}; do
                if echo ${_ip} | grep -q "|"; then
                    _ip="$(echo ${_ip} | awk -F"|" '{print $2}')"
                fi
                if [ "${_interface}" != "not set" ]; then
                    sed -i '' "s/.*${_interface} = .*/  ip6.addr = ${_interface}|${IP};/" "${JAIL_CONFIG}"
                else
                    sed -i '' "/ip6.addr = .*/ s/${_ip}/${IP}/" "${JAIL_CONFIG}"
                fi
                sed -i '' "/ip6.addr += .*/ s/${_ip}/127.0.0.1/" "${JAIL_CONFIG}"
                sed -i '' "s/ip6 = .*/ip6 = ${IP6_MODE};/" "${JAIL_CONFIG}"
            done
        fi
    fi
}

update_jailconf_vnet() {

    local _jail_conf="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local _rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"

    # Determine number of interfaces
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        local _if_list="$(grep -Eo 'epair[0-9]+|e[0-9]+b_bastille[0-9]+' ${_jail_conf} | sort -u)"
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local _if_list="$(grep -Eo 'ng[0-9]+_bastille[0-9]+' ${_jail_conf} | sort -u)"
    fi

    for _if in ${_if_list}; do

        # Get number of interfaces manged by Bastille
        get_bastille_if_count

        local _bastille_if_num_range=$((_bastille_if_count + 1))

        # Update bridged VNET config
        if echo ${_if} | grep -Eoq 'epair[0-9]+'; then
            for _num in $(seq 0 "${_bastille_if_num_range}"); do
                if ! echo "${_bastille_if_list}" | grep -oqswx "${_num}"; then
                    # Generate new epair name
                    if [ "$(echo -n "e${_num}a_${NEWNAME}" | awk '{print length}')" -lt 16 ]; then
                        local _new_host_epair="e${_num}a_${NEWNAME}"
                        local _new_jail_epair="e${_num}b_${NEWNAME}"
                    else
                        local _new_host_epair="epair${_num}a"
                        local _new_jail_epair="epair${_num}b"
                    fi
                    # Get epair name from TARGET
                    if grep -Eoq "e[0-9]+a_${TARGET}" "${_jail_conf}"; then
                        _target_host_epair="$(grep -Eo -m 1 "e[0-9]+a_${TARGET}" "${_jail_conf}")"
                        _target_jail_epair="$(grep -Eo -m 1 "e[0-9]+b_${TARGET}" "${_jail_conf}")"
                    else
                        _target_host_epair="${_if}a"
                        _target_jail_epair="${_if}b"
                    fi
                    # Replace host epair name in jail.conf                  
                    sed -i '' "s|up name ${_target_host_epair}|up name ${_new_host_epair}|g" "${_jail_conf}"
                    sed -i '' "s|${_target_host_epair} ether|${_new_host_epair} ether|g" "${_jail_conf}"
                    sed -i '' "s|deletem ${_target_host_epair}|deletem ${_new_host_epair}|g" "${_jail_conf}"
                    sed -i '' "s|${_target_host_epair} destroy|${_new_host_epair} destroy|g" "${_jail_conf}"
                    sed -i '' "s|${_target_host_epair} description|${_new_host_epair} description|g" "${_jail_conf}"
                    # Replace jail epair name in jail.conf
                    sed -i '' "s|= ${_target_jail_epair};|= ${_new_jail_epair};|g" "${_jail_conf}"
                    sed -i '' "s|up name ${_target_jail_epair}|up name ${_new_jail_epair}|g" "${_jail_conf}"
                    sed -i '' "s|${_target_jail_epair} ether|${_new_jail_epair} ether|g" "${_jail_conf}"
                    # Replace epair name in jail.conf                  
                    sed -i '' "s|${_if}|epair${_num}|g" "${_jail_conf}"
                    # If jail had a static MAC, generate one for clone
                    if grep -q ether ${_jail_conf}; then
                        local external_interface="$(grep "epair${_num}a" ${_jail_conf} | grep -o '[^ ]* addm' | awk '{print $1}')"
                        generate_static_mac "${NEWNAME}" "${external_interface}"
                        sed -i '' "s|${_new_host_epair} ether.*:.*:.*:.*:.*:.*a\";|${_new_host_epair} ether ${macaddr}a\";|" "${_jail_conf}"
                        sed -i '' "s|${_new_jail_epair} ether.*:.*:.*:.*:.*:.*b\";|${_new_jail_epair} ether ${macaddr}b\";|" "${_jail_conf}"
                    fi
                    # Replace epair description
                    sed -i '' "/${_new_host_epair}/ s|vnet host interface for Bastille jail ${TARGET}|vnet host interface for Bastille jail ${NEWNAME}|g" "${_jail_conf}"
                    # Update /etc/rc.conf
                    local _jail_vnet="$(grep ${_target_jail_epair} "${_rc_conf}" | grep -Eo -m 1 "vnet[0-9]+")"
                    local _jail_vnet_vlan="$(grep "vlans_${_jail_vnet}" "${_rc_conf}" | sed 's/.*=//g')"
                    sed -i '' "s|${_target_jail_epair}_name|${_new_jail_epair}_name|" "${_rc_conf}"
                    if grep "vnet0" "${_rc_conf}" | grep -q "${_new_jail_epair}_name"; then
                        if [ -n "${_jail_vnet_vlan}" ]; then
                            if [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; then
                                sysrc -f "${_rc_conf}" ifconfig_vnet0_${_jail_vnet_vlan}="SYNCDHCP"
                            else
                                sysrc -f "${_rc_conf}" ifconfig_vnet0_${_jail_vnet_vlan}="inet ${IP}"
                            fi
                        else
                            if [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; then
                                sysrc -f "${_rc_conf}" ifconfig_vnet0="SYNCDHCP"
                            else
                                sysrc -f "${_rc_conf}" ifconfig_vnet0="inet ${IP}"
                            fi
                        fi
                    else
                        if [ -n "${_jail_vnet_vlan}" ]; then
                            sysrc -f "${_rc_conf}" ifconfig_${_jail_vnet}_${_jail_vnet_vlan}="SYNCDHCP"
                        else
                            sysrc -f "${_rc_conf}" ifconfig_${_jail_vnet}="SYNCDHCP"
                        fi
                    fi
                    break
                fi
            done
        # Update VNET (non-bridged) config
        elif echo ${_if} | grep -Eoq 'e[0-9]+b_bastille[0-9]+'; then
            # Update VNET config
            _if="$(echo ${_if} | grep -Eo 'bastille[0-9]+')"
            for _num in $(seq 0 "${_bastille_if_num_range}"); do
                if ! echo "${_bastille_if_list}" | grep -oqswx "${_num}"; then
                    # Update jail.conf epair name
                    local _jail_if="bastille${_num}"
                    local _jail_vnet="$(grep ${_if} "${_rc_conf}" | grep -Eo -m 1 "vnet[0-9]+")"
                    local _jail_vnet_vlan="$(grep "vlans_${_jail_vnet}" "${_rc_conf}" | sed 's/.*=//g')"
                    sed -i '' "s|${_if}|${_jail_if}|g" "${_jail_conf}"
                    # If jail had a static MAC, generate one for clone
                    if grep ether ${_jail_conf} | grep -qoc ${_jail_if}; then
                        local external_interface="$(grep ${_jail_if} ${_jail_conf} | grep -o 'addm.*' | awk '{print $3}' | sed 's/["|;]//g')"
                        generate_static_mac "${NEWNAME}" "${external_interface}"
                        sed -i '' "s|${_jail_if} ether.*:.*:.*:.*:.*:.*a\";|${_jail_if} ether ${macaddr}a\";|" "${_jail_conf}"
                        sed -i '' "s|${_jail_if} ether.*:.*:.*:.*:.*:.*b\";|${_jail_if} ether ${macaddr}b\";|" "${_jail_conf}"
                    fi
                    sed -i '' "/${_jail_if}/ s|vnet host interface for Bastille jail ${TARGET}|vnet host interface for Bastille jail ${NEWNAME}|g" "${_jail_conf}"
                    # Update /etc/rc.conf
                    sed -i '' "s|ifconfig_e0b_${_if}_name|ifconfig_e0b_${_jail_if}_name|" "${_rc_conf}"
                    if grep "vnet0" "${_rc_conf}" | grep -q ${_jail_if}; then
                        if [ -n "${_jail_vnet_vlan}" ]; then
                            if [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; then
                                sysrc -f "${_rc_conf}" ifconfig_vnet0_${_jail_vnet_vlan}="SYNCDHCP"
                            else
                                sysrc -f "${_rc_conf}" ifconfig_vnet0_${_jail_vnet_vlan}="inet ${IP}"
                            fi
                        else
                            if [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; then
                                sysrc -f "${_rc_conf}" ifconfig_vnet0="SYNCDHCP"
                            else
                                sysrc -f "${_rc_conf}" ifconfig_vnet0="inet ${IP}"
                            fi
                        fi
                    else
                        if [ -n "${_jail_vnet_vlan}" ]; then
                            sysrc -f "${_rc_conf}" ifconfig_${_jail_vnet}_${_jail_vnet_vlan}="SYNCDHCP"
                        else
                            sysrc -f "${_rc_conf}" ifconfig_${_jail_vnet}="SYNCDHCP"
                        fi
                    fi
                    break
                fi
            done       
       # Update netgraph VNET (non-bridged) config
       elif echo ${_if} | grep -Eoq 'ng[0-9]+_bastille[0-9]+'; then
            _if="$(echo ${_if} | grep -Eo 'bastille[0-9]+')"
            for _num in $(seq 0 "${_bastille_if_num_range}"); do
                if ! echo "${_bastille_if_list}" | grep -oqswx "${_num}"; then
                    # Update jail.conf epair name
                    local _jail_if="bastille${_num}"
                    local _jail_vnet="$(grep ${_if} "${_rc_conf}" | grep -Eo -m 1 "vnet[0-9]+")"
                    local _jail_vnet_vlan="$(grep "vlans_${_jail_vnet}" "${_rc_conf}" | sed 's/.*=//g')"
                    sed -i '' "s|${_if}|${_jail_if}|g" "${_jail_conf}"
                    # If jail had a static MAC, generate one for clone
                    if grep ether ${_jail_conf} | grep -qoc ${_jail_if}; then
                        local external_interface="$(grep ${_jail_if} ${_jail_conf} | grep -o 'jng bridge.*' | awk '{print $4}' | sed 's/["|;]//g')"
                        generate_static_mac "${NEWNAME}" "${external_interface}"
                        sed -i '' "s|${_jail_if} ether.*:.*:.*:.*:.*:.*a\";|${_jail_if} ether ${macaddr}a\";|" "${_jail_conf}"
                    fi
                    # Update /etc/rc.conf
                    sed -i '' "s|ifconfig_ng0_${_if}_name|ifconfig_ng0_${_jail_if}_name|" "${_rc_conf}"
                    if grep "vnet0" "${_rc_conf}" | grep -q ${_jail_if}; then
                        if [ -n "${_jail_vnet_vlan}" ]; then
                            if [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; then
                                sysrc -f "${_rc_conf}" ifconfig_vnet0_${_jail_vnet_vlan}="SYNCDHCP"
                            else
                                sysrc -f "${_rc_conf}" ifconfig_vnet0_${_jail_vnet_vlan}="inet ${IP}"
                            fi
                        else
                            if [ "${IP}" = "0.0.0.0" ] || [ "${IP}" = "DHCP" ]; then
                                sysrc -f "${_rc_conf}" ifconfig_vnet0="SYNCDHCP"
                            else
                                sysrc -f "${_rc_conf}" ifconfig_vnet0="inet ${IP}"
                            fi
                        fi
                    else
                        if [ -n "${_jail_vnet_vlan}" ]; then
                            sysrc -f "${_rc_conf}" ifconfig_${_jail_vnet}_${_jail_vnet_vlan}="SYNCDHCP"
                        else
                            sysrc -f "${_rc_conf}" ifconfig_${_jail_vnet}="SYNCDHCP"
                        fi
                    fi
                    break
                fi
            done
        fi
    done
}

clone_jail() {

    if ! [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ "${LIVE}" -eq 1 ]; then
                if ! check_target_is_running "${TARGET}"; then
                    error_exit "[-l|--live] can only be used with a running jail."
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

            if [ -n "${IP}" ]; then
                validate_ip "${IP}"
            else
                usage
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
        error_exit "${NEWNAME} already exists."
    fi

    # Generate jail configuration files
    update_jailconf
    update_fstab "${TARGET}" "${NEWNAME}"

    # Display exit status
    if [ "$?" -ne 0 ]; then
        error_exit "An error has occurred while attempting to clone '${TARGET}'."
    else
        info "\nCloned '${TARGET}' to '${NEWNAME}' successfully."
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

clone_jail

echo