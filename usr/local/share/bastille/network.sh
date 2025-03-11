#!/bin/sh
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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_notify "Usage: bastille network [option(s)] TARGET [remove|add] INTERFACE [IP_ADDRESS]"
    cat << EOF
    Options:

    -a | --auto                 Start/stop the jail(s) if required.
    -B | --bridge               Add a bridged VNET interface to an existing jail.
    -C | --classic              Add an interface to a classic (non-VNET) jail.
    -M | --static-mac           Generate a static MAC address for the interface.
    -n | --no-ip                Create interface without an IP (VNET only).
    -V | --vnet                 Add a VNET interface to an existing jail.
    -v | --vlan VLANID          Add interface with specified VLAN ID (VNET only).
    -x | --debug                Enable debug mode.
    
EOF
    exit 1
}

# Handle options.
AUTO=0
BRIDGE_VNET_JAIL=0
CLASSIC_JAIL=0
STATIC_MAC=0
VNET_JAIL=0
VLAN_ID=""
NO_IP=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -B|--bridge)
            BRIDGE_VNET_JAIL=1
            shift
            ;;
        -C|--classic)
            CLASSIC_JAIL=1
            shift
            ;; 
        -M|--static-mac)
            STATIC_MAC=1
            shift
            ;;
        -n|--no-ip)
            NO_IP=1
            shift
            ;;
        -V|--vnet)
            VNET_JAIL=1
            shift
            ;;
        -v|--vlan)
	    if echo "${2}" | grep -Eq '^[0-9]+$'; then
                VLAN_ID="${2}"
	    else
                error_exit "Not a valid VLAN ID: ${2}"
	    fi
            shift 2
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;        
        -*)
            for _o in $(echo ${1} 2>/dev/null | sed 's/-//g' | fold -w1); do
                case ${_o} in
                    a) AUTO=1 ;;
                    B) BRIDGE_VNET_JAIL=1 ;;
                    C) CLASSIC_JAIL=1 ;;
                    M) STATIC_MAC=1 ;;
                    n) NO_IP=1 ;;
                    V) VNET_JAIL=1 ;;
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

TARGET="${1}"
ACTION="${2}"
INTERFACE="${3}"
if [ "${NO_IP}" -eq 0 ]; then
    IP="${4}"
elif [ "${NO_IP}" -eq 1 ] && [ -z "${4}" ]; then
    IP=""
else
    usage
fi

if [ "${ACTION}" = "add" ]; then
    if { [ "${VNET_JAIL}" -eq 1 ] && [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; } || \
       { [ "${VNET_JAIL}" -eq 1 ] && [ "${CLASSIC_JAIL}" -eq 1 ]; } || \
       { [ "${CLASSIC_JAIL}" -eq 1 ] && [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; } then
        error_notify "Error: Only one of [-B|--bridge], [-C|--classic] or [-V|--vnet] should be set."
        usage
    elif [ "${VNET_JAIL}" -eq 0 ] && [ "${BRIDGE_VNET_JAIL}" -eq 0 ] && [ "${CLASSIC_JAIL}" -eq 0 ]; then 
        error_notify "Error: [-C|--classic], [-B|--bridge] or [-V|--vnet] must be set."
        usage
    elif [ "${VNET_JAIL}" -eq 0 ] && [ "${BRIDGE_VNET_JAIL}" -eq 0 ] && [ "${VLAN_ID}" -eq 1 ]; then
        error_notify "VLANs can only be used with VNET interfaces."
        usage
    elif [ "${VNET_JAIL}" -eq 0 ] && [ "${BRIDGE_VNET_JAIL}" -eq 0 ] && [ "${NO_IP}" -eq 1 ]; then
        error_notify "[-n|--no-ip] can only be used with VNET jails."
        usage
    fi
fi

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    usage
fi

bastille_root_check
set_target_single "${TARGET}"
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else   
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

validate_ip() {
    IP6_ENABLE=0
    local ip="${1}"
    local ip6="$( echo "${ip}" 2>/dev/null | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)' )"
    if [ -n "${ip6}" ]; then
        info "Valid: (${ip6})."
        IP6_ENABLE=1
    elif [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ]; then
        info "Valid: (${ip})."
    else
        local IFS
        if echo "${ip}" 2>/dev/null | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${ip}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "Invalid: (${TEST_IP})"
                fi
            done
            info "Valid: (${ip})."
        else
            error_exit "Invalid: (${ip})."
        fi
    fi
}

validate_netif() {
    local _interface="${1}"
    if ifconfig -l | grep -qwo ${_interface}; then
        info "Valid: (${_interface})."
    else
        error_exit "Invalid: (${_interface})."
    fi
}

validate_netconf() {
    if [ -n "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
        error_exit "Invalid network configuration."
    fi
}

check_interface_added() {
    local _jailname="${1}"
    local _if="${2}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf" 
    if grep -qo "${_if}" "${_jail_config}"; then
        return 0
    else 
        return 1
    fi
}

add_interface() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _epair_if_count="$( (grep -Eos 'epair[0-9]+' ${bastille_jailsdir}/*/jail.conf; ifconfig | grep -Eo '(e[0-9]+a|epair[0-9]+a)' ) | sort -u | wc -l | awk '{print $1}')"
    local _bastille_if_count="$(grep -Eos 'bastille[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _vnet_if_count="$(grep -Eo 'vnet[1-9]+' ${_jail_rc_config} | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet="vnet$((_vnet_if_count + 1))"
    local epair_num_range=$((_epair_if_count + 1))
    local bastille_num_range=$((_bastille_if_count + 1))
    if [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
       if [ "${_epair_if_count}" -gt 0 ]; then  
            for _num in $(seq 0 "${epair_num_range}"); do
                if ! grep -Eosq "epair${_num}" ${bastille_jailsdir}/*/jail.conf && ! ifconfig | grep -Eosq "(e${_num}a|epair${_num}a)"; then
                    if [ "$(echo -n "e${_num}a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                        local host_epair=e${_num}a_${_jailname}
                        local jail_epair=e${_num}b_${_jailname}
                    else
                        local host_epair=epair${_num}a
                        local jail_epair=epair${_num}b
                    fi
                    break
                fi
            done
        else
            if [ "$(echo -n "e0a_${_jailname}" | awk '{print length}')" -lt 16 ]; then
                local _num=0
                local host_epair=e${_num}a_${_jailname}
                local jail_epair=e${_num}b_${_jailname}
            else
                local _num=0
                local host_epair=epair${_num}a
                local jail_epair=epair${_num}b
            fi
        fi
        # Remove ending brace (it is added again with the netblock)
        sed -i '' '/}/d' "${_jail_config}"
        if [ "${STATIC_MAC}" -eq 1 ]; then
            # Generate NETBLOCK with static MAC
            generate_static_mac "${_jailname}" "${_if}"
            cat << EOF >> "${_jail_config}"
  ## ${host_epair} interface
  vnet.interface += ${jail_epair};
  exec.prestart += "ifconfig epair${_num} create";
  exec.prestart += "ifconfig ${_if} addm epair${_num}a";
  exec.prestart += "ifconfig epair${_num}a up name ${host_epair}";
  exec.prestart += "ifconfig epair${_num}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"${_if_vnet} host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "ifconfig ${_if} deletem ${host_epair}";
  exec.poststop += "ifconfig ${host_epair} destroy";
}
EOF
        else
            # Generate NETBLOCK without static MAC
            cat << EOF >> "${_jail_config}"
  ## ${host_epair} interface
  vnet.interface += ${jail_epair};
  exec.prestart += "ifconfig epair${_num} create";
  exec.prestart += "ifconfig ${_if} addm epair${_num}a";
  exec.prestart += "ifconfig epair${_num}a up name ${host_epair}";
  exec.prestart += "ifconfig epair${_num}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${host_epair} description \"${_if_vnet} host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "ifconfig ${_if} deletem ${host_epair}";
  exec.poststop += "ifconfig ${host_epair} destroy";
}
EOF
        fi
	
        # Add config to /etc/rc.conf
        sysrc -f "${_jail_rc_config}" ifconfig_${jail_epair}_name="${_if_vnet}"
	if [ -n "${_ip}" ]; then
            # If 0.0.0.0 set DHCP, else set static IP address
            if [ "${_ip}" = "0.0.0.0" ] || [ "${_ip}" = "DHCP" ]; then
                sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
            else
                sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="inet ${_ip}"
            fi
        fi

        info "[${_jailname}]:"
        echo "Added interface: \"${_if}\""

    elif [ "${VNET_JAIL}" -eq 1 ]; then
        for _num in $(seq 0 "${bastille_num_range}"); do
            if ! grep -Eq "bastille${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                    local bastille_epair="bastille${_num}"
                    break
            fi
        done
        # Remove ending brace (it is added again with the netblock)
        sed -i '' '/}/d' "${_jail_config}"
        if [ "${STATIC_MAC}" -eq 1 ]; then
            # Generate NETBLOCK with static MAC
            generate_static_mac "${_jailname}" "${_if}"
            cat << EOF >> "${_jail_config}"
  ## ${bastille_epair} interface
  vnet.interface += e0b_${bastille_epair};
  exec.prestart += "jib addm ${bastille_epair} ${_if}";
  exec.prestart += "ifconfig e0a_${bastille_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig e0b_${bastille_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig e0a_${bastille_epair} description \"${_if_vnet} host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "jib destroy ${bastille_epair}";
}
EOF
        else
            # Generate NETBLOCK without static MAC
            cat << EOF >> "${_jail_config}"
  ## ${bastille_epair} interface
  vnet.interface += e0b_${bastille_epair};
  exec.prestart += "jib addm ${bastille_epair} ${_if}";
  exec.prestart += "ifconfig e0a_${bastille_epair} description \"${_if_vnet} host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "jib destroy ${bastille_epair}";
}
EOF
        fi
        # Add config to /etc/rc.conf
        sysrc -f "${_jail_rc_config}" ifconfig_e0b_${bastille_epair}_name="${_if_vnet}"
	if [ -n "${_ip}" ]; then
            # If 0.0.0.0 set DHCP, else set static IP address
            if [ "${_ip}" = "0.0.0.0" ] || [ "${_ip}" = "DHCP" ]; then
                sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
            else
                sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="inet ${_ip}"
            fi
	fi

        info "[${_jailname}]:"
        echo "Added VNET interface: \"${_if}\""
        
    elif [ "${CLASSIC_JAIL}" -eq 1 ]; then
        if [ "${IP6_ENABLE}" -eq 1 ]; then
            sed -i '' "s/interface = .*/&\n  ip6.addr += ${_if}|${_ip};/" ${_jail_config}
        else
            sed -i '' "s/interface = .*/&\n  ip4.addr += ${_if}|${_ip};/" ${_jail_config}
        fi
    fi

    info "[${_jailname}]:"
    echo "Added interface: \"${_if}\""
}

remove_interface() {
    local _jailname="${1}"
    local _if="${2}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    # Skip next block in case of classic jail
    if [ "$(bastille config ${TARGET} get vnet)" != "not set" ]; then
        local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
        if grep ${_if} ${_jail_config} | grep -Eo -m 1 'bastille[0-9]+'; then
            local _if_bastille_num="$(grep ${_if} ${_jail_config} | grep -Eo -m 1 "bastille[0-9]+" | grep -Eo "[0-9]+")"
            local _if_jail="e0b_bastille${_if_bastille_num}"
            _if_type="bastille"
        elif grep ${_if} ${_jail_config} | grep -Eo -m 1 "epair[0-9]+"; then
            local _if_epair_num="$(grep ${_if} ${_jail_config} | grep -Eo -m 1 "epair[0-9]+" | grep -Eo "[0-9]+")"
            if grep epair${_if_epair_num}b ${_jail_config} | grep -Eo -m 1 "e${_if_epair_num}b_${_jailname}"; then
                local _if_jail="$(grep epair${_if_epair_num}b ${_jail_config} | grep -Eo -m 1 "e${_if_epair_num}b_${_jailname}")"
            else
                local _if_jail="epair${_if_epair_num}b"
            fi
            _if_type="epair"
        else
            error_exit "Could not find interface inside jail: \"${_if_jail}\""
        fi

        if grep -o "${_if_jail}" ${_jail_config}; then
            local _if_vnet="$(grep ${_if_jail} ${_jail_rc_config} | grep -Eo 'vnet[0-9]+')"
        else
            error_exit "Interface not found: ${_if_jail}"
        fi
    
        # Do not allow removing default vnet0 interface
        if [ "${_if_vnet}" = "vnet0" ]; then
            error_exit "Default interface cannot be removed."
        fi

        # Avoid removing entire file contents if variables aren't set for some reason
        if [ -z "${_if_jail}" ]; then
            error_exit "Error: Could not find specifed interface."
        fi
       
         # Remove interface from /etc/rc.conf
        if [ -n "${_if_vnet}" ] && echo ${_if_vnet} 2>/dev/null | grep -Eo 'vnet[0-9]+'; then
            sed -i '' "/.*${_if_vnet}.*/d" "${_jail_rc_config}"
        else
            error_continue "Failed to remove interface from /etc/rc.conf"
        fi
    
        # Remove VNET interface from jail.conf (VNET)
        if [ -n "${_if_jail}" ]; then
            if [ "${_if_type}" = "epair" ]; then
                sed -i '' "/.*epair${_if_epair_num}.*/d" "${_jail_config}" 
                sed -i '' "/.*e${_if_epair_num}a_${_jailname}.*/d" "${_jail_config}" 
                sed -i '' "/.*e${_if_epair_num}b_${_jailname}.*/d" "${_jail_config}" 
            elif [ "${_if_type}" = "bastille" ]; then
                sed -i '' "/.*${_if_jail}.*/d" "${_jail_config}"
                sed -i '' "/.*bastille${_if_bastille_num}.*/d" "${_jail_config}"
            fi
        else
            error_exit "Failed to remove interface from jail.conf"
        fi
    else
        # Remove interface from jail.conf (non-VNET)
        if [ -n "${_if}" ]; then
            if grep ${_if} ${_jail_config} 2>/dev/null | grep -qo " = "; then
                error_exit "Default interface cannot be removed."
            else
                sed -i '' "/.*${_if}.*/d" "${_jail_config}"
            fi
        else
            error_exit "Failed to remove interface from jail.conf"
        fi
    fi
   
    info "[${_jailname}]:"
    echo "Removed interface: \"${_if}\""
}

add_vlan() {
    local _jailname="${1}"
    local _interface="${2}"
    local _ip="${3}"
    local _vlan_id="${4}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    if [ "${VNET_JAIL}" -eq 1 ]; then
        local _jail_epair_num="$(grep ${_interface} ${_jail_config} | grep -Eo -m 1 "bastille[0-9]+" | grep -Eo "[0-9]+")"
	local _jail_vnet="$(grep "e0b_bastille${_jail_epair_num}_name" ${_jail_rc_config} | grep -Eo "vnet[0-9]+")"
    elif [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
        local _jail_epair_num="$(grep ${_interface} ${_jail_config} | grep -Eo -m 1 "epair[0-9]+" | grep -Eo "[0-9]+")"
	local _jail_vnet="$(grep "e.*${_jail_epair_num}b.*_name" ${_jail_rc_config} | grep -Eo "vnet[0-9]+")"
    fi
    if grep -Eq "ifconfig_${_jail_vnet}_${_vlan_id}" "${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"; then
        error_exit "VLAN has already been added: VLAN ${_vlan_id}"
    else
        bastille start "${_jailname}"
        bastille template "${_jailname}" ${bastille_template_vlan} --arg VLANID="${_vlan_id}" --arg IFCONFIG="inet ${_ip}" --arg JAIL_VNET="${_jail_vnet}"
        bastille restart "${_jailname}"
    fi

    info "[${_jailname}]:"
    info "Added VLAN ${_vlan_id} to interface: \"${_jail_vnet}\""
}

case "${ACTION}" in
    add)
        validate_netconf
        validate_netif "${INTERFACE}"
        if check_interface_added "${TARGET}" "${INTERFACE}" && [ -z "${VLAN_ID}" ]; then
            error_exit "Interface is already added: \"${INTERFACE}\""
        elif { [ "${VNET_JAIL}" -eq 1 ] || [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; } && [ -n "${VLAN_ID}" ]; then
	    add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
            exit 0
        fi
	## validate IP if not empty
        if [ -n "${IP}" ]; then
                validate_ip "${IP}"
        fi
        if [ "${VNET_JAIL}" -eq 1 ]; then
            if ifconfig -g bridge | grep -owq "${INTERFACE}"; then
                error_exit "\"${INTERFACE}\" is a bridge interface."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
		if [ -n "${VLAN_ID}" ]; then
		    add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
                fi
                if [ "${AUTO}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        elif [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
            if ! ifconfig -g bridge | grep -owq "${INTERFACE}"; then
                error_exit "\"${INTERFACE}\" is not a bridge interface."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
		if [ -n "${VLAN_ID}" ]; then
		    add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
                fi
                if [ "${AUTO}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        elif [ "${CLASSIC_JAIL}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get vnet)" != "not set" ]; then
                error_exit "Error: ${TARGET} is a VNET jail."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
                if [ "${AUTO}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        fi
        ;;
    remove|delete)
        check_interface_added "${TARGET}" "${INTERFACE}" || error_exit "Interface not found in jail.conf: \"${INTERFACE}\"" 
        validate_netif "${INTERFACE}"
        if ! grep -q "${INTERFACE}" ${bastille_jailsdir}/${TARGET}/jail.conf; then
            error_exit "Interface not found in jail.conf: \"${INTERFACE}\""
        else
            remove_interface "${TARGET}" "${INTERFACE}"
            if [ "${AUTO}" -eq 1 ]; then
                bastille start "${TARGET}"
            fi
        fi
        ;;
    *)
        error_exit "Only [add|remove] are supported."
        ;;
esac
