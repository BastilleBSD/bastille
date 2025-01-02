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
    error_notify "Usage: bastille network [option(s)] TARGET [remove|add] INTERFACE [IP_ADDRESS]"
    cat << EOF
    Options:

    -b | --bridge              Add a bridged VNET interface to an existing jail.
    -f | --force               Stop the jail if it is running.
    -m | --static-mac          Generate a static MAC address for the interface.
    -s | --start               Start jail on completion.
    -v | --vnet                Add a VNET interface to an existing jail.

EOF
    exit 1
}

# Handle options.
BRIDGE_VNET_JAIL=0
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
        -f|--force)
            FORCE=1
            shift
            ;;
        -m|--static-mac)
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
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    b|B) BRIDGE_VNET_JAIL=1 ;;
                    f) FORCE=1 ;;
                    m) STATIC_MAC=1 ;;
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

TARGET="${1}"
ACTION="${2}"
INTERFACE="${3}"
IP="${4}"

if [ "${ACTION}" = "add" ]; then
    if [ "${VNET_JAIL}" -eq 1 ] && [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
        error_notify "Error: [-v|-V|--vnet] and [-b|-B|--bridge] cannot both be set."
        usage
    elif [ "${VNET_JAIL}" -eq 0 ] && [ "${BRIDGE_VNET_JAIL}" -eq 0 ]; then 
        error_notify "Error: [-v|-V|--vnet] or [-b|-B|--bridge] must be set."
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
    local ip="${1}"
    local ip6="$( echo "${ip}" 2>/dev/null | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)' )"
    if [ -n "${ip6}" ]; then
        info "Valid: (${ip6})."
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
    if grep -o "${_if}" "${_jail_config}"; then
        return 0
    else 
        return 1
    fi
}

add_vnet_interface_block() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _if_count="$(grep -Eo 'bastille[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet_count="$(grep -Eo 'vnet[1-9]+' ${_jail_rc_config} | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet="vnet$((_if_vnet_count + 1))"
    local num_range=$((_if_count + 1))
        for _num in $(seq 0 "${num_range}"); do
            if ! grep -Eq "bastille${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                    local uniq_epair="bastille${_num}"
                    break
            fi
        done
    generate_static_mac "${_jailname}" "${_if}"
    sed -i '' "s|}||" "${_jail_config}"
    ## generate config
    cat << EOF >> "${_jail_config}"
  ## ${uniq_epair} interface
  vnet.interface += e0b_${uniq_epair};
  exec.prestart += "jib addm ${uniq_epair} ${_if}";
  exec.prestart += "ifconfig e0a_${uniq_epair} description \"vnet host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "jib destroy ${uniq_epair}";
}
EOF

    # add config to /etc/rc.conf
    sysrc -f "${_jail_rc_config}" ifconfig_e0b_${uniq_epair}_name="${_if_vnet}"
    # If 0.0.0.0 set DHCP, else set static IP address
    if [ "${_ip}" = "0.0.0.0" ]; then
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
    else
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}=" inet ${_ip} "
    fi

    info "[${_jailname}]:"
    echo "Added interface: \"${_if}\""
}

add_vnet_interface_block_static_mac() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _if_count="$(grep -Eo 'bastille[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet_count="$(grep -Eo 'vnet[1-9]+' ${_jail_rc_config} | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet="vnet$((_if_vnet_count + 1))"
    local num_range=$((_if_count + 1))
        for _num in $(seq 0 "${num_range}"); do
            if ! grep -Eq "bastille${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                    local uniq_epair="bastille${_num}"
                    break
            fi
        done
    generate_static_mac "${_jailname}" "${_if}"
    sed -i '' "s|}||" "${_jail_config}"
    ## generate config
    cat << EOF >> "${_jail_config}"
  ## ${uniq_epair} interface
  vnet.interface += e0b_${uniq_epair};
  exec.prestart += "jib addm ${uniq_epair} ${_if}";
  exec.prestart += "ifconfig e0a_${uniq_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig e0b_${uniq_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig e0a_${uniq_epair} description \"vnet host interface for Bastille jail ${_jailname}\"";
  exec.poststop += "jib destroy ${uniq_epair}";
}
EOF

    # add config to /etc/rc.conf
    sysrc -f "${_jail_rc_config}" ifconfig_e0b_${uniq_epair}_name="${_if_vnet}"
    # If 0.0.0.0 set DHCP, else set static IP address
    if [ "${_ip}" = "0.0.0.0" ]; then
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
    else
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}=" inet ${_ip} "
    fi

    info "[${_jailname}]:"
    echo "Added interface: \"${_if}\""
}

add_bridge_interface_block() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _if_count="$(grep -Eo 'epair[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet_count="$(grep -Eo 'vnet[1-9]+' ${_jail_rc_config} | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet=vnet$((_if_vnet_count + 1))
    local num_range=$((_if_count + 1))
        for _num in $(seq 0 "${num_range}"); do
            if ! grep -Eq "epair${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                    local uniq_epair="${_num}"
                    break
            fi
        done
    generate_static_mac "${_jailname}" "${_if}"
    sed -i '' "s|}||" "${_jail_config}"
    ## generate config
    cat << EOF >> "${_jail_config}"
  ## epair${uniq_epair} interface
  vnet.interface += e${uniq_epair}b_${_jailname};
  exec.prestart += "ifconfig epair${uniq_epair} create";
  exec.prestart += "ifconfig ${_if} addm epair${uniq_epair}a";
  exec.prestart += "ifconfig epair${uniq_epair}a up name e${uniq_epair}a_${_jailname}";
  exec.prestart += "ifconfig epair${uniq_epair}b up name e${uniq_epair}b_${_jailname}";
  exec.poststop += "ifconfig ${_if} deletem e${uniq_epair}a_${_jailname}";
  exec.poststop += "ifconfig e${uniq_epair}a_${_jailname} destroy";
}
EOF

    # Add config to /etc/rc.conf
    sysrc -f "${_jail_rc_config}" ifconfig_e${uniq_epair}b_${_jailname}_name="${_if_vnet}"
    # If 0.0.0.0 set DHCP, else set static IP address
    if [ "${_ip}" = "0.0.0.0" ]; then
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
    else
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}=" inet ${_ip} "
    fi

    info "[${_jailname}]:"
    echo "Added interface: \"${_if}\""
}

add_bridge_interface_block_static_mac() {
    local _jailname="${1}"
    local _if="${2}"
    local _ip="${3}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _if_count="$(grep -Eo 'epair[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet_count="$(grep -Eo 'vnet[1-9]+' ${_jail_rc_config} | sort -u | wc -l | awk '{print $1}')"
    local _if_vnet=vnet$((_if_vnet_count + 1))
    local num_range=$((_if_count + 1))
        for _num in $(seq 0 "${num_range}"); do
            if ! grep -Eq "epair${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                    local uniq_epair="${_num}"
                    break
            fi
        done
    generate_static_mac "${_jailname}" "${_if}"
    sed -i '' "s|}||" "${_jail_config}"
    ## generate config
    cat << EOF >> "${_jail_config}"
  ## epair${uniq_epair} interface
  vnet.interface += e${uniq_epair}b_${_jailname};
  exec.prestart += "ifconfig epair${uniq_epair} create";
  exec.prestart += "ifconfig ${_if} addm epair${uniq_epair}a";
  exec.prestart += "ifconfig epair${uniq_epair}a up name e${uniq_epair}a_${_jailname}";
  exec.prestart += "ifconfig epair${uniq_epair}b up name e${uniq_epair}b_${_jailname}";
  exec.prestart += "ifconfig e${uniq_epair}a_${_jailname} ether ${macaddr}a";
  exec.prestart += "ifconfig e${uniq_epair}b_${_jailname} ether ${macaddr}b";
  exec.poststop += "ifconfig ${_if} deletem e${uniq_epair}a_${_jailname}";
  exec.poststop += "ifconfig e${uniq_epair}a_${_jailname} destroy";
}
EOF

    # Add config to /etc/rc.conf
    sysrc -f "${_jail_rc_config}" ifconfig_e${uniq_epair}b_${_jailname}_name="${_if_vnet}"
    # If 0.0.0.0 set DHCP, else set static IP address
    if [ "${_ip}" = "0.0.0.0" ]; then
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}="SYNCDHCP"
    else
        sysrc -f "${_jail_rc_config}" ifconfig_${_if_vnet}=" inet ${_ip} "
    fi

    info "[${_jailname}]:"
    echo "Added interface: \"${_if}\""
}

remove_vnet_interface_block() {
    local _jailname="${1}"
    local _if="${2}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _if_jail="$(grep "${_if}" ${_jail_config} | grep -Eo 'bastille[0-9]+')"
    if grep -o "${_if_jail}" ${_jail_rc_config}; then
        local _if_vnet="$(grep "${_if_jail}" ${_jail_rc_config} | grep -Eo 'vnet[0-9]+')"
    else
        error_exit "Interface not found: ${_if_jail}"
    fi
    
    # Do not allow removing default vnet0 interface
    if [ "${_if_vnet}" = "vnet0" ]; then
        error_exit "Default interface cannot be removed."
    fi

    # Avoid removing entire file contents if variables aren't set for some reason
    if [ -z "${_if_jail}" ]; then
        error_exit "Error: Could not find specifed interfaces. Exiting..."
    fi

    # Remove interface from jail.conf
    if [ -n "${_if_jail}" ]; then
        sed -i '' "s|.*${_if_jail}.*||" "${_jail_config}"
        sed -i '' '/^$/d' "${_jail_config}"
    else
        error_exit "Failed to remove interface from jail.conf"
    fi
    
    # Remove interface from /etc/rc.conf
    if [ -n "${_if_vnet}" ] && echo ${_if_vnet} 2>/dev/null | grep -Eo 'vnet[0-9]+'; then
        sed -i '' "s|.*${_if_vnet}.*||" "${_jail_rc_config}"
        sed -i '' '/^$/d' "${_jail_rc_config}"
    else
        error_exit "Failed to remove interface from /etc/rc.conf"
    fi

    info "[${_jailname}]:"
    echo "Removed interface: \"${_if}\""
}

remove_bridge_interface_block() {
    local _jailname="${1}"
    local _if="${2}"
    local _jail_config="${bastille_jailsdir}/${_jailname}/jail.conf"
    local _jail_rc_config="${bastille_jailsdir}/${_jailname}/root/etc/rc.conf"
    local _if_epair="$(grep "${_if}" ${_jail_config} | grep -Eo 'epair[0-9]+')"
    local _if_epaira_name="$(grep "${_if_epair}" ${_jail_config} | grep -Eo "e[0-9]+a_${_jailname}")"
    local _if_epairb_name="$(grep "${_if_epair}" ${_jail_config} | grep -Eo "e[0-9]+b_${_jailname}")"
    if grep -o "${_if_epairb_name}" ${_jail_rc_config}; then
        local _if_vnet="$(grep "${_if_epairb_name}" ${_jail_rc_config} | grep -Eo 'vnet[0-9]+')"
    else
        error_exit "Interface not found: ${_if_epair_name}"
    fi
    
    # Do not allow removing default vnet0 interface
    if [ "${_if_vnet}" = "vnet0" ]; then
        error_exit "Default interface cannot be removed."
    fi

    # Avoid removing entire file contents if variables aren't set for some reason
    if [ -z "${_if_epair}" ] || [ -z "${_if_epaira_name}" ] || [ -z "${_if_epairb_name}" ] || [ -z "${_if_vnet}" ]; then
        error_exit "Error: Could not find specifed interfaces. Exiting..."
    fi

    # Remove interface from jail.conf
    if [ -n "${_if_epair}" ] && [ -n "${_if_epaira_name}" ] && [ -n "${_if_epairb_name}" ] && [ -n "${_if_vnet}" ]; then
        sed -i '' "s|.*${_if_epair}.*||" "${_jail_config}"
        sed -i '' "s|.*${_if_epaira_name}.*||" "${_jail_config}"
        sed -i '' "s|.*${_if_epairb_name}.*||" "${_jail_config}"
        sed -i '' '/^$/d' "${_jail_config}"
    else
        error_exit "Failed to remove interface from jail.conf"
    fi
    
    # Remove interface from /etc/rc.conf
    if [ -n "${_if_vnet}" ] && echo ${_if_vnet} 2>/dev/null | grep -Eo 'vnet[0-9]+'; then
        sed -i '' "s|ifconfig.*${_if_vnet}.*||" "${_jail_rc_config}"
        sed -i '' '/^$/d' "${_jail_rc_config}"
    else
        error_exit "Failed to remove interface from /etc/rc.conf"
    fi

    info "[${_jailname}]:"
    echo "Removed interface: \"${_if}\""
}

case "${ACTION}" in
    add)
        validate_netconf
        validate_netif "${INTERFACE}"
        if check_interface_added "${TARGET}" "${INTERFACE}"; then
            error_exit "Interface is already added: \"${INTERFACE}\""
        fi
        if [ -z "${IP}" ] || [ "${IP}" = "0.0.0.0" ]; then
            IP="SYNCDHCP"
        else
            validate_ip "${IP}"
        fi
        if [ "${VNET_JAIL}" -eq 1 ]; then
            if ifconfig | grep "${INTERFACE}" | grep -q bridge; then
                error_exit "\"${INTERFACE}\" is a bridge interface."
            else
                if [ "${STATIC_MAC}" -eq 1 ]; then
                    add_vnet_interface_block_static_mac "${TARGET}" "${INTERFACE}" "${IP}"
                else
                    add_vnet_interface_block "${TARGET}" "${INTERFACE}" "${IP}"
                fi
                if [ "${START}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        elif [ "${BRIDGE_VNET_JAIL}" -eq 1 ]; then
            if ! ifconfig | grep "${INTERFACE}" | grep -q bridge; then
                error_exit "\"${INTERFACE}\" is not a bridge interface."
            else
                if [ "${STATIC_MAC}" -eq 1 ]; then
                    add_bridge_interface_block_static_mac "${TARGET}" "${INTERFACE}" "${IP}"
                else
                    add_bridge_interface_block "${TARGET}" "${INTERFACE}" "${IP}"
                fi
                if [ "${START}" -eq 1 ]; then
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
            if grep "${INTERFACE}" ${bastille_jailsdir}/${TARGET}/jail.conf 2>/dev/null | grep -qE '[[:blank:]]bastille[0-9]+'; then
                remove_vnet_interface_block "${TARGET}" "${INTERFACE}"
                if [ "${START}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            elif grep "${INTERFACE}" ${bastille_jailsdir}/${TARGET}/jail.conf 2>/dev/null | grep -qE '[[:blank:]]epair[0-9]+'; then
                remove_bridge_interface_block "${TARGET}" "${INTERFACE}"
                if [ "${START}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi
        fi
        ;;
    *)
        error_exit "Only [add|remove] are supported."
        ;;
esac

