#!/bin/sh
#
# Copyright (c) 2018-2024, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille network [option(s)] TARGET [remove|add|change] INTERFACE [IP_ADDRESS]"
    cat << EOF
    Options:

    -b | --bridge              Add a bridged VNET interface to an existing VNET jail.
    -c | --classic             Add an interface to a classic (non-VNET) jail.
    -f | --force               Stop the jail if it is running.
    -m | --static-mac          Generate a static MAC address for the VNET interface.
    -s | --start               Start jail on completion.
    -v | --vnet                Add a VNET interface to an existing VNET jail.

EOF
    exit 1
}

# Handle options.
BRIDGE_VNET_JAIL=0
CLASSIC_JAIL=0
FORCE=0
STATIC_MAC=0
START=0
VNET_JAIL=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -b|-B|--bridge)
            BRIDGE_VNET_JAIL=1
            shift
            ;;
        -c|--classic)
            CLASSIC_JAIL=1
            shift
            ;; 
       -f|--force)
            FORCE=1
            shift
            ;;
        -m|-M|--static-mac)
            STATIC_MAC=1
            shift
            ;;
        -s|--start)
            START=1
            shift
            ;;
        -v|-V|--vnet)
            VNET_JAIL=1
            shift
            ;;
        -*)
            for _o in $(echo ${1} 2>/dev/null | sed 's/-//g' | fold -w1); do
                case ${_o} in
                    b|B) BRIDGE_VNET_JAIL=1 ;;
                    c) CLASSIC_JAIL=1 ;;
                    f) FORCE=1 ;;
                    m|M) STATIC_MAC=1 ;;
                    s) START=1 ;;
                    v|V) VNET_JAIL=1 ;;
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
set -x

TARGET="${1}"
ACTION="${2}"
INTERFACE="${3}"
IP="${4}"

if [ "${ACTION}" = "add" ]; then
    if { [ "${VNET_JAIL}" -eq 1 ] && [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; } || \
       { [ "${VNET_JAIL}" -eq 1 ] && [ "${CLASSIC_JAIL}" -eq 1 ]; } || \
       { [ "${CLASSIC_JAIL}" -eq 1 ] && [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; } then
        error_notify "Error: Only one of [-b|-B|--bridge], [-c|--classic] or [-v|-V|--vnet] should be set."
        usage
    elif [ "${VNET_JAIL}" -eq 0 ] && [ "${BRIDGE_VNET_JAIL}" -eq 0 ] && [ "${CLASSIC_JAIL}" -eq 0 ]; then 
        error_notify "Error: [-c|--classic], [-b|-B|--bridge] or [-v|-V|--vnet] must be set."
        usage
    fi
fi

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    usage
fi

bastille_root_check
set_target_single "${TARGET}"
check_target_is_stopped "${TARGET}" || if [ "${FORCE}" -eq 1 ]; then
    bastille stop "${TARGET}"
else   
    error_notify "Jail is running."
    error_exit "Use [-f|--force] to force stop the jail."
fi

validate_ip() {
    IP6_ENABLE=0
    local _ip="${1}"
    local _jail_config="${bastille_jailsdir}/${TARGET}/jail.conf"
    if grep -Eqo ${_ip} ${_jail_config}; then
        error_exit "Error: IP already present in jail.conf"
    fi
    local _ip6="$( echo "${_ip}" 2>/dev/null | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)' )"
    if [ -n "${_ip6}" ]; then
        info "Valid: (${_ip6})."
        IP6_ENABLE=1
    else
        local IFS
        if echo "${_ip}" 2>/dev/null | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${_ip}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "Invalid: (${TEST_IP})"
                fi
            done
            info "Valid: (${_ip})."
        else
            error_exit "Invalid: (${_ip})."
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

change_ip() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _type="${4}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf" 
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _epair="$(grep -E ${_if} ${_jail_config} | grep -Eo -m 1 'epair[0-9]+|bastille[0-9]+')"
    local _jail_vnet="$(grep -E ${_epair} ${_jail_rc_config} | grep -Eo -m 1 'vnet[0-9]+')"
    sysrc -f "${_jail_rc_config}" ifconfig_${_jail_vnet}=" inet ${IP} "        
}

test_change_ip() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _type="${4}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf" 
    if [ "${_type}" = "vnet" ]; then
        local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
        local _epair="$(grep -E ${_if} ${_jail_config} | grep -Eo -m 1 'epair[0-9]+|bastille[0-9]+')"
        local _jail_vnet="$(grep -E ${_epair} ${_jail_rc_config} | grep -Eo -m 1 'vnet[0-9]+')"
        sysrc -f "${_jail_rc_config}" ifconfig_${_jail_vnet}=" inet ${IP} "
    elif [ "${_type}" = "classic" ]; then
        if [ "${IP6_ENABLE}" -eq 1 ]; then
            local _ip6="$(bastille config ${_jailname} get ip6.addr | sed 's/,/ /g' | grep -F ${_if})"
            if [ "${_ip6}" != "not set" ]; then
                sed -i '' "s/${_if}|.*/${_if}|${_ip};/" "${_jail_config}"
            fi
        else
            local _ip4="$(bastille config ${_jailname} get ip4.addr | sed 's/,/ /g' | grep -F ${_if})"
            if [ "${_ip4}" != "not set" ]; then
                sed -i '' "s/${_if}|.*/${_if}|${_ip};/" "${_jail_config}"
            fi
        fi
    fi          
}

add_interface() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _epair_if_count="$(grep -Eo 'epair[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _bastille_if_count="$(grep -Eo 'bastille[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _vnet_if_count="$(grep -Eo 'vnet[1-9]+' ${_jail_rc_config} | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet="vnet$((_vnet_if_count + 1))"
    local epair_num_range=$((_epair_if_count + 1))
    local bastille_num_range=$((_bastille_if_count + 1))
    if [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
        for _num in $(seq 0 "${epair_num_range}"); do
            if ! grep -Eq "epair${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                    local bridge_epair="epair${_num}"
                    break
            fi
        done
        # Remove ending brace (it is added again with the netblock)
        sed -i '' '/}/d' "${_jail_config}"
        if [ "${STATIC_MAC}" -eq 1 ]; then
            # Generate NETBLOCK with static MAC
            generate_static_mac "${_jailname}" "${_if}"
            cat << EOF >> "${_jail_config}"
  ## ${bridge_epair} interface
  vnet.interface += ${bridge_epair}b;
  exec.prestart += "ifconfig ${bridge_epair} create";
  exec.prestart += "ifconfig ${_if} addm ${bridge_epair}a";
  exec.prestart += "ifconfig ${bridge_epair}a ether ${macaddr}a";
  exec.prestart += "ifconfig ${bridge_epair}b ether ${macaddr}b";
  exec.prestart += "ifconfig ${bridge_epair}a description \"vnet host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "ifconfig ${_if} deletem ${bridge_epair}a";
  exec.poststop += "ifconfig ${bridge_epair}a destroy";
}
EOF
        else
            # Generate NETBLOCK without static MAC
            cat << EOF >> "${_jail_config}"
  ## ${bridge_epair} interface
  vnet.interface += ${bridge_epair}b;
  exec.prestart += "ifconfig ${bridge_epair} create";
  exec.prestart += "ifconfig ${_if} addm ${bridge_epair}a";
  exec.prestart += "ifconfig ${bridge_epair}a description \"vnet host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "ifconfig ${_if} deletem ${bridge_epair}a";
  exec.poststop += "ifconfig ${bridge_epair}a destroy";
}
EOF
        fi
        # Add config to /etc/rc.conf
        sysrc -f "${_jail_rc_config}" ifconfig_${bridge_epair}b_name="${_if_vnet}"
        # If 0.0.0.0 set DHCP, else set static IP address
        if [ "${_ip}" = "0.0.0.0" ]; then
            sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
        else
            sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}=" inet ${_ip} "
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
  exec.prestart += "ifconfig e0a_${bastille_epair} description \"vnet host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "jib destroy ${bastille_epair}";
}
EOF
        else
            # Generate NETBLOCK without static MAC
            cat << EOF >> "${_jail_config}"
  ## ${bastille_epair} interface
  vnet.interface += e0b_${bastille_epair};
  exec.prestart += "jib addm ${bastille_epair} ${_if}";
  exec.prestart += "ifconfig e0a_${bastille_epair} description \"vnet host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "jib destroy ${bastille_epair}";
}
EOF
        fi
        # Add config to /etc/rc.conf
        sysrc -f "${_jail_rc_config}" ifconfig_e0b_${bastille_epair}_name="${_if_vnet}"
        # If 0.0.0.0 set DHCP, else set static IP address
        if [ "${_ip}" = "0.0.0.0" ]; then
            sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
        else
            sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}=" inet ${_ip} "
        fi

        info "[${_jailname}]:"
        echo "Added VNET interface: \"${_if}\""
        
    elif [ "${CLASSIC_JAIL}" -eq 1 ]; then
        if [ "${IP6_ENABLE}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get ip6)" = "disable" ]; then
                error_exit "Error: IPv6 is not enabled for this jail."
            else
                sed -i '' "s/ip6.addr = .*/&\n  ip6.addr += ${_if}|${_ip};/" ${_jail_config}
            fi
        else
            if [ "$(bastille config ${TARGET} get ip4)" = "disable" ]; then
                error_exit "Error: IPv4 is not enabled for this jail."
            else
                sed -i '' "s/ip4.addr = .*/&\n  ip4.addr += ${_if}|${_ip};/" ${_jail_config}
            fi
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
        local _if_jail="$(grep ${_if} ${_jail_config} | grep -Eo -m 1 'epair[0-9]+|bastille[0-9]+')"

        if grep -o "${_if_jail}" ${_jail_rc_config}; then
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
            error_exit "Failed to remove interface from /etc/rc.conf"
        fi
    
        # Remove VNET interface from jail.conf (VNET)
        if [ -n "${_if_jail}" ]; then
            sed -i '' "/.*${_if_jail}.*/d" "${_jail_config}"
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

case "${ACTION}" in
    add)
        validate_netif "${INTERFACE}"
        if [ -z "${IP}" ] || [ "${IP}" = "0.0.0.0" ]; then
            IP="SYNCDHCP"
            IP6_ENABLE=0
        else
            validate_ip "${IP}"
        fi
        if [ "${VNET_JAIL}" -eq 1 ]; then
        ! check_interface_added "${TARGET}" "${INTERFACE}" || error_exit "Interface is already added: \"${INTERFACE}\""
            if ifconfig | grep "${INTERFACE}" | grep -q bridge; then
                error_exit "\"${INTERFACE}\" is a bridge interface."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
                if [ "${START}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        elif [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
        ! check_interface_added "${TARGET}" "${INTERFACE}" || error_exit "Interface is already added: \"${INTERFACE}\""
            if ! ifconfig | grep "${INTERFACE}" | grep -q bridge; then
                error_exit "\"${INTERFACE}\" is not a bridge interface."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
                if [ "${START}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        elif [ "${CLASSIC_JAIL}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get vnet)" != "not set" ]; then
                error_exit "Error: ${TARGET} is a VNET jail."
            elif [ "$(bastille config ${TARGET} get ip4)" = "inherit" ] || [ "$(bastille config ${TARGET} get ip6)" = "inherit" ]; then
                error_exit "Error: Jail IP mode is set to inherit."
            elif [ "${IP}" = "SYNCDHCP" ]; then
                error_exit "Error: Valid IP is required for non-VNET jails."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
                if [ "${START}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        fi
        ;;
    remove|delete)
        check_interface_added "${TARGET}" "${INTERFACE}" || error_exit "Interface not found in jail.conf: \"${INTERFACE}\"" 
        validate_netif "${INTERFACE}"
        remove_interface "${TARGET}" "${INTERFACE}"
        if [ "${START}" -eq 1 ]; then
            bastille start "${TARGET}"
        fi
        ;;
    change)
        validate_netif "${INTERFACE}"
        check_interface_added "${TARGET}" "${INTERFACE}" || error_exit "Interface not found in jail.conf: \"${INTERFACE}\""
        if grep -qo "vnet;" "${bastille_jailsdir}/${TARGET}/jail.conf"; then
            if [ -z "${IP}" ] || [ "${IP}" = "0.0.0.0" ]; then
                IP="SYNCDHCP"
            fi
            validate_ip "${IP}"
            change_ip "${TARGET}" "${INTERFACE}" "${IP}"
            if [ "${START}" -eq 1 ]; then
                bastille start "${TARGET}"
            fi
        else
            error_notify "Error: Changing IP is not supported for non-VNET jails."
            error_exit "Please use [add] to add an additional IP to a classic, non-VNET jail."
        fi   
        ;;
    *)
        error_exit "Only [add|remove|change] are supported."
        ;;
esac