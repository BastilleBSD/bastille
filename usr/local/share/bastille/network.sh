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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_notify "Usage: bastille network [option(s)] TARGET remove|add INTERFACE [IP]"
    cat << EOF

    Options:

    -a | --auto            Start/stop jail(s) if required.
    -B | --bridge          Add a bridge VNET interface.
    -M | --static-mac      Generate a static MAC address for the interface (VNET only).
    -n | --no-ip           Create interface without an IP (VNET only).
    -P | --passthrough     Add a raw interface.
    -V | --vnet            Add a VNET interface.
    -v | --vlan VLANID     Assign VLAN ID to interface (VNET only).
    -x | --debug           Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
BRIDGE=0
STATIC_MAC=0
STANDARD=0
PASSTHROUGH=0
VNET=0
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
            BRIDGE=1
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
        -P|--passthrough)
            PASSTHROUGH=1
            shift
            ;;
        -V|--vnet)
            VNET=1
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
                    B) BRIDGE=1 ;;
                    M) STATIC_MAC=1 ;;
                    n) NO_IP=1 ;;
                    P) PASSTHROUGH=1 ;;
                    V) VNET=1 ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\"" ;;
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

# Validate options
if [ "${ACTION}" = "add" ] && [ "${NO_IP}" -eq 0 ] && [ -n "${4}" ]; then
    IP="${4}"
elif [ "${NO_IP}" -eq 1 ] && [ -n "${4}" ]; then
    error_exit "[ERROR]: IP should not be present when using -n|--no-ip."
else
    IP=""
fi

# Default is standard interface
if [ "${VNET}" -eq 0 ] && [ "${BRIDGE}" -eq 0 ] && [ "${PASSTHROUGH}" -eq 0 ]; then
    STANDARD=1
fi

if [ "${ACTION}" = "add" ]; then
    if { [ "${VNET}" -eq 1 ] && [ "${BRIDGE}" -eq 1 ]; } || \
       { [ "${VNET}" -eq 1 ] && [ "${STANDARD}" -eq 1 ]; } || \
       { [ "${VNET}" -eq 1 ] && [ "${PASSTHROUGH}" -eq 1 ]; } || \
       { [ "${BRIDGE}" -eq 1 ] && [ "${STANDARD}" -eq 1 ]; } || \
       { [ "${BRIDGE}" -eq 1 ] && [ "${PASSTHROUGH}" -eq 1 ]; } || \
       { [ "${STANDARD}" -eq 1 ] && [ "${PASSTHROUGH}" -eq 1 ]; } then
        error_exit "[ERROR]: Only one of [-B|--bridge], [-P|--passthrough] or [-V|--vnet] should be set."
    elif [ "${VNET}" -eq 0 ] && [ "${BRIDGE}" -eq 0 ] && [ "${PASSTHROUGH}" -eq 0 ] && [ -n "${VLAN_ID}" ]; then
        error_exit "[ERROR]: VLANs can only be used with VNET interfaces."
    elif [ "${VNET}" -eq 0 ] && [ "${BRIDGE}" -eq 0 ] && [ "${NO_IP}" -eq 1 ]; then
        error_exit "[ERROR]: [-n|--no-ip] can only be used with VNET jails."
    elif [ "${bastille_network_vnet_type}" = "netgraph" ] && [ "${BRIDGE}" -eq 1 ]; then
        error_exit "[ERROR]: [-B|--bridge] cannot be used with Netgraph."
    fi
fi

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    usage
fi

bastille_root_check
set_target_single "${TARGET}"

# Validate jail state
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else
    info "\n[${TARGET}]:"
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

validate_ip() {

    local ip="${1}"
    local ip6="$( echo "${ip}" 2>/dev/null | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)' )"

    if [ -n "${ip6}" ]; then
        info "\nValid: (${ip6})."
        IP6_ADDR="${ip6}"
    elif [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ] || [ "${ip}" = "SYNCDHCP" ]; then
        info "\nValid: (${ip})."
        IP4_ADDR="${ip}"
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
            info "\nValid: (${ip})."
            IP4_ADDR="${ip}"
        else
            error_exit "Invalid: (${ip})."
        fi
    fi
}

validate_netif() {

    local interface="${1}"

    if ifconfig -l | grep -qwo ${interface}; then
        info "\nValid: (${interface})."
    else
        error_exit "Invalid: (${interface})."
    fi

    # Don't allow dots in INTERFACE if -V
    if [ "${VNET}" -eq 1 ] && [ "${BRIDGE}" -eq 0 ]; then
        if echo "${INTERFACE}" | grep -q "\."; then
            error_exit "[ERROR]: [-V|--vnet] does not support dots (.) in interface names."
        fi
    fi
}

check_interface_added() {

    local jailname="${1}"
    local if="${2}"
    local jail_config="${bastille_jailsdir}/${jailname}/jail.conf"

    if grep -qo "${if}" "${jail_config}"; then
        return 0
    else
        return 1
    fi
}

add_interface() {

    local jailname="${1}"
    local if="${2}"
    local ip="${3}"
    local jail_config="${bastille_jailsdir}/${jailname}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jailname}/root/etc/rc.conf"
    local jail_vnet_list="$(grep -Eo 'vnet[0-9]+' ${jail_rc_config} | sort -u | wc -l)"
    # Set vnetX number
    local jail_vnet_num="0"
    while echo "${jail_vnet_list}" | grep -Eosq "vnet${jail_vnet_num}"; do
        jail_vnet_num=$((jail_vnet_num + 1))
    done
    local jail_vnet="vnet${jail_vnet_num}"

    # Determine number of interfaces
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        local epair_list="$(grep -Eo 'e[0-9]+a_[^;" ]+' ${jail_config} | sort -u)"
        local epair_suffix="$(grep -m 1 -Eo 'e[0-9]+a_[^;" ]+' ${jail_config} | awk -F"_" '{print $2}')"
        local epair_num="0"
        while echo "${epair_list}" | grep -Eosq "e${epair_num}a_"; do
            epair_num=$((epair_num + 1))
        done
        if [ "${jail_vnet_num}" -ne "${epair_num}" ]; then
            error_exit "[ERROR]: Jail vnet+epair interface numbers do not match."
        fi
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local ng_list="$(grep -Eo 'ng[0-9]+_[^;" ]+' ${jail_config} | sort -u)"
        local ng_suffix="$(grep -m 1 -Eo 'ng[0-9]+_[^;" ]+' ${jail_config} | awk -F"_" '{print $2}')"
        local ng_num="0"
        while echo "${ng_list}" | grep -Eosq "ng${ng_num}_"; do
            ng_num=$((ng_num + 1))
        done
        if [ "${jail_vnet_num}" -ne "${ng_num}" ]; then
            error_exit "[ERROR]: Jail vnet+netgraph interface numbers do not match."
        fi
    fi

    # BRIDGE interface
    if [ "${BRIDGE}" -eq 1 ]; then

        local host_epair=e${epair_num}a_${epair_suffix}
        local jail_epair=e${epair_num}b_${epair_suffix}

        # Remove ending brace (it is added again with the netblock)
        sed -i '' '/^}$/d' "${jail_config}"
 
         # Generate NETBLOCK with static MAC
        if [ "${STATIC_MAC}" -eq 1 ]; then
            generate_static_mac "${jailname}" "${if}"
            cat << EOF >> "${jail_config}"
  ## ${host_epair} interface
  vnet.interface += ${jail_epair};
  exec.prestart += "epair${epair_num}=\\\$(ifconfig epair create) && ifconfig \\\${epair${epair_num}} up name ${host_epair} && ifconfig \\\${epair${epair_num}%a}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${if} addm ${host_epair}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"${jail_vnet} host interface for Bastille jail ${jailname}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
}
EOF
        else
            # Generate NETBLOCK without static MAC
            cat << EOF >> "${jail_config}"
  ## ${host_epair} interface
  vnet.interface += ${jail_epair};
  exec.prestart += "epair${epair_num}=\\\$(ifconfig epair create) && ifconfig \\\${epair${epair_num}} up name ${host_epair} && ifconfig \\\${epair${epair_num}%a}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${if} addm ${host_epair}";
  exec.prestart += "ifconfig ${host_epair} description \"${jail_vnet} host interface for Bastille jail ${jailname}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
}
EOF
        fi

        # Add config to /etc/rc.conf
        sysrc -f "${jail_rc_config}" ifconfig_${jail_epair}_name="${jail_vnet}"
        sysrc -f "${jail_rc_config}" ifconfig_${jail_epair}_descr="jail interface for ${if}"

        if [ -n "${IP6_ADDR}" ]; then
            if [ "${IP6_ADDR}" = "SLAAC" ]; then
                sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_ipv6="inet6 -ifdisabled accept_rtadv"
            else
                sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_ipv6="inet6 -ifdisabled ${IP6_ADDR}"
            fi
        elif [ -n "${IP4_ADDR}" ]; then
            # If 0.0.0.0 set DHCP, else set static IP address
            if [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ] || [ "${ip}" = "SYNCDHCP" ]; then
                sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="SYNCDHCP"
            else
                sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="inet ${IP4_ADDR}"
            fi
        fi
        echo "Added bridge interface: \"${if}\""

    # VNET interface
    elif [ "${VNET}" -eq 1 ]; then

        # if_bridge
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then

            local host_epair=e${epair_num}a_${epair_suffix}
            local jail_epair=e${epair_num}b_${epair_suffix}
            local jib_epair=${epair_suffix}

            # Remove ending brace (it is added again with the netblock)
            sed -i '' '/^}$/d' "${jail_config}"

            if [ "${STATIC_MAC}" -eq 1 ]; then
                # Generate NETBLOCK with static MAC
                generate_static_mac "${jailname}" "${if}"
                cat << EOF >> "${jail_config}"
  ## ${host_epair} interface
  vnet.interface += ${jail_epair};
  exec.prestart += "jib addm ${jib_epair} ${if}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"${jail_vnet} host interface for Bastille jail ${jailname}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
}
EOF
            else
                # Generate NETBLOCK without static MAC
                cat << EOF >> "${jail_config}"
  ## ${host_epair} interface
  vnet.interface += ${jail_epair};
  exec.prestart += "jib addm ${jib_epair} ${if}";
  exec.prestart += "ifconfig ${host_epair} description \"${jail_vnet} host interface for Bastille jail ${jailname}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
}
EOF
            fi

            # Add config to /etc/rc.conf
            sysrc -f "${jail_rc_config}" ifconfig_${jail_epair}_name="${jail_vnet}"
            sysrc -f "${jail_rc_config}" ifconfig_${jail_epair}_descr="jail interface for ${if}"

            if [ -n "${IP6_ADDR}" ]; then
                if [ "${IP6_ADDR}" = "SLAAC" ]; then
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_ipv6="inet6 -ifdisabled accept_rtadv"
                else
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_ipv6="inet6 -ifdisabled ${IP6_ADDR}"
                fi
            elif [ -n "${IP4_ADDR}" ]; then
                # If 0.0.0.0 set DHCP, else set static IP address
                if [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ] || [ "${ip}" = "SYNCDHCP" ]; then
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="SYNCDHCP"
                else
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="inet ${IP4_ADDR}"
                fi
            fi
            echo "Added VNET interface: \"${if}\""

        # netgraph
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then

            local ng_if=ng${ng_num}_${ng_suffix}
            local jng_if=${ng_suffix}

            # Remove ending brace (it is added again with the netblock)
            sed -i '' '/^}$/d' "${jail_config}"

            if [ "${STATIC_MAC}" -eq 1 ]; then
                # Generate NETBLOCK with static MAC
                generate_static_mac "${jailname}" "${if}"
                cat << EOF >> "${jail_config}"
  ## ${ng_if} interface
  vnet.interface += ${ng_if};
  exec.prestart += "jng bridge ${jng_if} ${if}";
  exec.prestart += "ifconfig ${ng_if} ether ${macaddr}b";
  exec.poststop += "jng shutdown ${jng_if}";
}
EOF
            else
                # Generate NETBLOCK without static MAC
                cat << EOF >> "${jail_config}"
  ## ${ng_if} interface
  vnet.interface += ${ng_if};
  exec.prestart += "jng bridge ${jng_if} ${if}";
  exec.poststop += "jng shutdown ${jng_if}";
}
EOF
            fi

            # Add config to /etc/rc.conf
            sysrc -f "${jail_rc_config}" ifconfig_${ng_if}_name="${jail_vnet}"

            if [ -n "${ip}" ]; then
                # If 0.0.0.0 set DHCP, else set static IP address
                if [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ]; then
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="SYNCDHCP"
                else
                    sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="inet ${ip}"
                fi
            fi
            echo "Added VNET interface: \"${if}\""

        fi

    # PASSTHROUGH
    elif [ "${PASSTHROUGH}" -eq 1 ]; then

        # Remove ending brace (it is added again with the netblock)
        sed -i '' '/^}$/d' "${jail_config}"

        # Generate NETBLOCK (static MAC not used on passthrough)
        cat << EOF >> "${jail_config}"
  ## ${if} interface
  vnet.interface += ${if};
  exec.prestop += "ifconfig ${if} -vnet ${jailname}";
}
EOF
        # Add config to /etc/rc.conf
	if [ -n "${IP6_ADDR}" ]; then
            if [ "${IP6_ADDR}" = "SLAAC" ]; then
                sysrc -f "${jail_rc_config}" ifconfig_${if}_ipv6="inet6 -ifdisabled accept_rtadv"
            else
                sysrc -f "${jail_rc_config}" ifconfig_${if}_ipv6="inet6 -ifdisabled ${IP6_ADDR}"
            fi
        elif [ -n "${IP4_ADDR}" ]; then
            # If 0.0.0.0 set DHCP, else set static IP address
            if [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ] || [ "${ip}" = "SYNCDHCP" ]; then
                sysrc -f "${jail_rc_config}" ifconfig_${if}="SYNCDHCP"
            else
                sysrc -f "${jail_rc_config}" ifconfig_${if}="inet ${IP4_ADDR}"
            fi
        fi
        echo "Added Passthrough interface: \"${if}\""

    elif [ "${STANDARD}" -eq 1 ]; then
        if [ -n "${IP6_ADDR}" ]; then
            sed -i '' "s/interface = .*/&\n  ip6.addr += ${if}|${ip};/" ${jail_config}
        else
            sed -i '' "s/interface = .*/&\n  ip4.addr += ${if}|${ip};/" ${jail_config}
        fi
    fi
}

remove_interface() {

    local jailname="${1}"
    local if="${2}"
    local jail_config="${bastille_jailsdir}/${jailname}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jailname}/root/etc/rc.conf"

    # Skip next block in case of standard jail
    if [ "$(bastille config ${TARGET} get vnet)" != "not set" ]; then

        if grep -q "vnet.interface.*${if};" ${jail_config}; then

            local if_jail="${if}"
            local if_type="passthrough"

        elif [ "${bastille_network_vnet_type}" = "if_bridge" ]; then

            local jib_epair="$(grep "jib addm.*${if}" ${jail_config} | awk '{print $3}')"
            local if_type="if_bridge"

            if [ -n "${jib_epair}" ]; then
                local epaira="$(grep -m 1 -A 1 "${if}" ${jail_config} | grep -Eo "e[0-9]+a_${jib_epair}")"
                local epairb="$(echo ${epaira} | sed 's/a_/b_/')"
                local if_jail="${epairb}"
            else
                local epaira="$(grep -m 1 "${if}" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
                local epairb="$(echo ${epaira} | sed 's/a_/b_/')"
                local if_jail="${epairb}"
            fi

        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then

            local jng_if="$(grep "jng bridge.*${if}" ${jail_config} | awk '{print $3}')"
            local if_jail="$(grep "ng[0-9]+_${jng_if}" ${jail_config})"
            local if_type="netgraph"

        else
            error_exit "[ERROR]: Could not find interface inside jail: \"${if_jail}\""
        fi

        # Get vnetX value from rc.conf
        if [ "${if_type}" = "if_bridge" ]; then
            if grep -oq "${if_jail}" ${jail_config}; then
                local if_vnet="$(grep "${if_jail}" ${jail_rc_config} | grep -Eo 'vnet[0-9]+')"
            else
                error_exit "[ERROR]: Interface not found: ${if_jail}"
            fi
        elif [ "${if_type}" = "netgraph" ]; then
            if grep -oq "${if_jail}" ${jail_config}; then
                local if_vnet="${if_jail}"
            else
                error_exit "[ERROR]: Interface not found: ${if_jail}"
            fi
        elif [ "${if_type}" = "passthrough" ]; then
            if grep -oq "${if_jail}" ${jail_config}; then
                local if_vnet="${if_jail}"
            else
                error_exit "[ERROR]: Interface not found: ${if_jail}"
            fi
        fi

        # Do not allow removing default vnet0 interface
        if [ "${if_vnet}" = "vnet0" ]; then
            error_exit "[ERROR]: Default interface cannot be removed."
        fi

        # Avoid removing entire file contents if variables aren't set for some reason
        if [ -z "${if_jail}" ]; then
            error_exit "[ERROR]: Could not find specifed interface."
        fi

        # Remove interface from /etc/rc.conf
        if [ "${if_type}" = "if_bridge" ]; then
            if [ -n "${if_vnet}" ] && echo ${if_vnet} | grep -Eoq 'vnet[0-9]+'; then
                sed -i '' "/.*${if_vnet}.*/d" "${jail_rc_config}"
            else
                error_exit "[ERROR]: Failed to remove interface from /etc/rc.conf"
            fi
        elif [ "${if_type}" = "netgraph" ]; then
            if [ -n "${if_vnet}" ] && echo ${if_vnet} | grep -Eoq 'vnet[0-9]+'; then
                sed -i '' "/.*${if_vnet}.*/d" "${jail_rc_config}"
            else
                error_exit "[ERROR]: Failed to remove interface from /etc/rc.conf"
            fi
        elif [ "${if_type}" = "passthrough" ]; then
            if [ -n "${if_vnet}" ]; then
                sed -i '' "/.*${if_vnet}.*/d" "${jail_rc_config}"
            else
                error_exit "[ERROR]: Failed to remove interface from /etc/rc.conf"
            fi
        fi

        # Remove VNET interface from jail.conf (VNET)
        if [ -n "${if_jail}" ]; then
            if [ "${if_type}" = "if_bridge" ]; then
                sed -i '' "/.*${epaira}.*/d" "${jail_config}"
                sed -i '' "/.*${epairb}.*/d" "${jail_config}"
                sed -i '' "/.*${if}.*/d" "${jail_config}"
            elif [ "${if_type}" = "netgraph" ]; then
                sed -i '' "/.*${if_jail}.*/d" "${jail_config}"
                sed -i '' "/.*${if}.*/d" "${jail_config}"
            elif [ "${if_type}" = "passthrough" ]; then
                sed -i '' "/.*${if_jail}.*/d" "${jail_config}"
            fi
        else
            error_exit "[ERROR]: Failed to remove interface from jail.conf"
        fi
    else
        # Remove interface from jail.conf (non-VNET)
        if [ -n "${if}" ]; then
            if grep ${if} ${jail_config} 2>/dev/null | grep -qo " = "; then
                error_exit "[ERROR]: Default interface cannot be removed."
            else
                sed -i '' "/.*${if}.*/d" "${jail_config}"
            fi
        else
            error_exit "[ERROR]: Failed to remove interface from jail.conf"
        fi
    fi
    echo "Removed interface: \"${if}\""
}

add_vlan() {

    local jailname="${1}"
    local interface="${2}"
    local ip="${3}"
    local vlan_id="${4}"
    local jail_config="${bastille_jailsdir}/${jailname}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jailname}/root/etc/rc.conf"

    if [ "${VNET}" -eq 1 ]; then
        local jib_epair="$(grep "jib addm.*${if}" ${jail_config} | awk '{print $3}')"
        local jail_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config})"
	local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
    elif [ "${BRIDGE}" -eq 1 ]; then
        local jail_epair="$(grep 'e[0-9]+b_[^;" ]+' ${jail_config})"
	local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
    elif [ "${PASSTHROUGH}" -eq 1 ]; then
        local _jail_vnet="${interface}"
    fi
    if grep -Eq "ifconfig_${jail_vnet}_${vlan_id}" "${bastille_jailsdir}/${jailname}/root/etc/rc.conf"; then
        error_exit "[ERROR]: VLAN has already been added: VLAN ${vlan_id}"
    else
        bastille start "${jailname}"
        bastille template "${jailname}" ${bastille_template_vlan} --arg VLANID="${vlan_id}" --arg IFCONFIG="inet ${ip}" --arg JAIL_VNET="${jail_vnet}"
        bastille restart "${jailname}"
    fi

    echo "Added VLAN ${vlan_id} to interface: \"${jail_vnet}\""
}

info "\n[${TARGET}]:"

case "${ACTION}" in

    add)

        validate_netconf
        validate_netif "${INTERFACE}"

        if check_interface_added "${TARGET}" "${INTERFACE}" && [ -z "${VLAN_ID}" ]; then
            error_exit "Interface is already added: \"${INTERFACE}\""
        elif { [ "${VNET}" -eq 1 ] || [ "${BRIDGE}" -eq 1 ] || [ "${PASSTHROUGH}" -eq 1 ]; } && [ -n "${VLAN_ID}" ]; then
            add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
            echo
            exit 0
        fi

        ## validate IP if not empty
        if [ -n "${IP}" ]; then
            validate_ip "${IP}"
        fi

        if [ "${VNET}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get vnet)" = "not set" ]; then
                error_exit "[ERROR]: ${TARGET} is not a VNET jail."
            elif ifconfig -g bridge | grep -owq "${INTERFACE}"; then
                error_exit "[ERROR]: '${INTERFACE}' is a bridge interface."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
                if [ -n "${VLAN_ID}" ]; then
                    add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
                fi
                if [ "${AUTO}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi

        elif [ "${BRIDGE}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get vnet)" = "not set" ]; then
                error_exit "[ERROR]: ${TARGET} is not a VNET jail."
            elif ! ifconfig -g bridge | grep -owq "${INTERFACE}"; then
                error_exit "[ERROR]: '${INTERFACE}' is not a bridge interface."
            else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
                if [ -n "${VLAN_ID}" ]; then
                    add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
                fi
                if [ "${AUTO}" -eq 1 ]; then
                    bastille start "${TARGET}"
                fi
            fi

        elif [ "${PASSTHROUGH}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get vnet)" = "not set" ]; then
                error_exit "[ERROR]: ${TARGET} is not a VNET jail."
	    else
                add_interface "${TARGET}" "${INTERFACE}" "${IP}"
            fi
            if [ -n "${VLAN_ID}" ]; then
                add_vlan "${TARGET}" "${INTERFACE}" "${IP}" "${VLAN_ID}"
            fi
            if [ "${AUTO}" -eq 1 ]; then
                bastille start "${TARGET}"
            fi

        elif [ "${STANDARD}" -eq 1 ]; then
            if [ "$(bastille config ${TARGET} get vnet)" != "not set" ]; then
                error_exit "[ERROR]: ${TARGET} is a VNET jail."
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
            error_exit "[ERROR]: Interface not found in jail.conf: \"${INTERFACE}\""
        else
            remove_interface "${TARGET}" "${INTERFACE}"
            if [ "${AUTO}" -eq 1 ]; then
                bastille start "${TARGET}"
            fi
        fi
        ;;
    *)
        error_exit "[ERROR]: Only [add|remove] are supported."
        ;;
esac
