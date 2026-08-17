#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2026, Christer Edwards <christer.edwards@gmail.com>
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

# Networking, IP and VNET helpers.

get_bastille_epair_count() {
    for config in /usr/local/etc/bastille/*.conf; do
        local bastille_jailsdir="$(sysrc -f "${config}" -n bastille_jailsdir)"
        BASTILLE_EPAIR_LIST="$(printf '%s\n%s' "$( (grep -Ehos "bastille[0-9]+" ${bastille_jailsdir}/*/jail.conf; ifconfig -g epair | grep -Eos "e[0-9]+a_bastille[0-9]+$" | grep -Eos 'bastille[0-9]+') | sort -u)" "${BASTILLE_EPAIR_LIST}")"
    done
    BASTILLE_EPAIR_COUNT=$(printf '%s' "${BASTILLE_EPAIR_LIST}" | sort -u | wc -l | awk '{print $1}')
    export BASTILLE_EPAIR_LIST
    export BASTILLE_EPAIR_COUNT
}

generate_static_mac() {
    local jail_name="${1}"
    local external_interface="${2}"
    local external_interface_mac="$(ifconfig ${external_interface} | grep ether | awk '{print $2}')"
    # Use FreeBSD vendor MAC prefix (58:9c:fc) for jail MAC prefix
    local macaddr_prefix="58:9c:fc"
    # Use hash of interface+jailname for jail MAC suffix
    local macaddr_suffix="$(echo -n "${external_interface_mac}${external_interface}${jail_name}" | sed 's#:##g' | sha256 | cut -b -5 | sed 's/\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F]\)/\1:\2:\3/')"
    if [ -z "${macaddr_prefix}" ] || [ -z "${macaddr_suffix}" ]; then
        error_notify "Failed to generate MAC address."
    fi
    macaddr="${macaddr_prefix}:${macaddr_suffix}"
    export macaddr
}

generate_vnet_jail_netblock() {
    local jail_name="${1}"
    # interface_type can be "standard" "bridge" or "passthrough"
    local interface_type="${2}"
    local external_interface="${3}"
    local static_mac="${4}"
    # Set epair/interface values for host/jail
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        if [ "${interface_type}" = "bridge" ]; then
            if [ "$(echo -n "e0a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                local host_epair=e0a_${jail_name}
                local jail_epair=e0b_${jail_name}
            else
                get_bastille_epair_count
                local epair_num=1
                while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${epair_num}"; do
                    epair_num=$((epair_num + 1))
                done
                local host_epair="e0a_bastille${epair_num}"
                local jail_epair="e0b_bastille${epair_num}"
            fi
        elif [ "${interface_type}" = "standard" ]; then
            if [ "$(echo -n "e0a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                local host_epair=e0a_${jail_name}
                local jail_epair=e0b_${jail_name}
                local jib_epair=${jail_name}
            else
                get_bastille_epair_count
                local epair_num=1
                while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${epair_num}"; do
                    epair_num=$((epair_num + 1))
                done
                local host_epair="e0a_bastille${epair_num}"
                local jail_epair="e0b_bastille${epair_num}"
                local jib_epair="bastille${epair_num}"
            fi
        elif [ "${interface_type}" = "passthrough" ]; then
            host_epair="${external_interface}"
            jail_epair="${external_interface}"
        fi
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local ng_if=ng0_${jail_name}
        local jng_if=${jail_name}
    fi
    # VNET_JAIL_BRIDGE
    if [ "${interface_type}" = "bridge" ]; then
        if [ "${static_mac}" -eq 1 ]; then
            # Generate BRIDGE config with static MAC address
            generate_static_mac "${jail_name}" "${external_interface}"
            cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "epair0=\\\$(ifconfig epair create) && ifconfig \\\${epair0} up name ${host_epair} && ifconfig \\\${epair0%a}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${external_interface} addm ${host_epair}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
        else
            # Generate BRIDGE config without static MAC address
            cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "epair0=\\\$(ifconfig epair create) && ifconfig \\\${epair0} up name ${host_epair} && ifconfig \\\${epair0%a}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${external_interface} addm ${host_epair}";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
        fi
    # VNET_JAIL_STANDARD
    elif [ "${interface_type}" = "standard" ]; then
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
            if [ "${static_mac}" -eq 1 ]; then
                # Generate VNET config with static MAC address
                generate_static_mac "${jail_name}" "${external_interface}"
                cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "jib addm ${jib_epair} ${external_interface}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
            else
                # Generate VNET config without static MAC address
                cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "jib addm ${jib_epair} ${external_interface}";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
            fi
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
            if [ "${static_mac}" -eq 1 ]; then
                # Generate VNET config with static MAC address
                generate_static_mac "${jail_name}" "${external_interface}"
                cat <<-EOF
  vnet;
  vnet.interface = ${ng_if};
  exec.prestart += "jng bridge ${jng_if} ${external_interface}";
  exec.prestart += "ifconfig ${ng_if} ether ${macaddr}b";
  exec.poststop += "jng shutdown ${jng_if}";
EOF
            else
                # Generate VNET config without static MAC address
                cat <<-EOF
  vnet;
  vnet.interface = ${ng_if};
  exec.prestart += "jng bridge ${jng_if} ${external_interface}";
  exec.poststop += "jng shutdown ${jng_if}";
EOF
            fi
        fi
    # VNET_JAIL_PASSTHROUGH
    elif [ "${interface_type}" = "passthrough" ]; then
        cat <<-EOF
  vnet;
  vnet.interface = ${external_interface};
  exec.prestop += "ifconfig ${external_interface} -vnet ${jail_name}";
EOF
    fi
}

validate_ip() {
    local ip="${1}"
    local vnet_jail="${2}"
    local ip4="$(echo ${ip} | awk -F"/" '{print $1}')"
    local ip6="$(echo ${ip} | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)' | awk -F"/" '{print $1}')"
    local subnet="$(echo ${ip} | awk -F"/" '{print $2}')"
    local IFS
    if [ -n "${ip6}" ]; then
        if [ "${vnet_jail}" -eq 1 ]; then
            if [ -z "${subnet}" ]; then
                subnet="64"
            elif ! echo "${subnet}" | grep -Eq '^[0-9]+$'; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            elif [ "${subnet}" -lt 1 ] || [ "${subnet}" -gt 128 ]; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            fi
            ip6="${ip6}/${subnet}"
        fi
        info 1 "\nValid IP: ${ip6}"
        export IP6_ADDR="${ip6}"
    elif [ "${ip}" = "inherit" ] || [ "${ip}" = "ip_hostname" ]; then
            info 1 "\nValid IP: ${ip}"
            export IP4_ADDR="${ip}"
            export IP6_ADDR="${ip}"
    elif [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ] || [ "${ip}" = "SYNCDHCP" ]; then
            info 1 "\nValid IP: ${ip}"
            export IP4_ADDR="${ip}"
    elif [ -n "${ip4}" ]; then
        if [ "${vnet_jail}" -eq 1 ]; then
            if [ -z "${subnet}" ]; then
                subnet="24"
            elif ! echo "${subnet}" | grep -Eq '^[0-9]+$'; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            elif [ "${subnet}" -lt 1 ] || [ "${subnet}" -gt 32 ]; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            fi
            ip4="${ip4}/${subnet}"
        fi
        if echo "${ip4}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            test_ip=$(echo "${ip4}" | cut -d / -f1)
            IFS=.
            set ${test_ip}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "[ERROR]: Invalid IP: ${ip4}"
                fi
            done
            info 1 "\nValid IP: ${ip4}"
            export IP4_ADDR="${ip4}"
        else
            error_exit "[ERROR]: Invalid IP: ${ip4}"
        fi
    else
        error_exit "[ERROR]: IP incorrectly formatted: ${ip}"
    fi
}

validate_netconf() {
    # Add default 'bastille_network_vnet_type' on old config file
    # This is so we don't have to indtroduce a 'breaking change' statement
    if ! grep -oq "bastille_network_vnet_type=" "${BASTILLE_CONFIG}"; then
        sed -i '' "s|## Networking|&\nbastille_network_vnet_type=\"if_bridge\"                                ## default: \"if_bridge\"|" ${BASTILLE_CONFIG}
        # shellcheck disable=SC1090
        . ${BASTILLE_CONFIG}
    fi
    if [ "${bastille_network_vnet_type}" != "if_bridge" ] && [ "${bastille_network_vnet_type}" != "netgraph" ]; then
        error_exit "[ERROR]: 'bastille_network_vnet_type' not set properly: ${bastille_network_vnet_type}"
    fi
}

check_fib() {
    local jail="${1}"
    local fib="$(grep 'exec.fib' "${bastille_jailsdir}/${jail}/jail.conf" | awk '{print $3}' | sed 's/\;//g')"
    if [ -n "${fib}" ]; then
        SETFIB="setfib -F ${fib}"
    else
        SETFIB=""
    fi
    export SETFIB
}
