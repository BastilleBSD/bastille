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

. /usr/local/share/bastille/common.sh

usage() {
    error_notify "Usage: bastille vlan [option(s)] TARGET add VLAN INTERFACE [IP]"
    cat << EOF

    Options:

    -a | --auto            Start/stop jail(s) if required.
    -n | --no-ip           Add VLAN withouth an IP.
    -t | --tagged          Add a tagged VLAN (bridge interface only).
    -u | --untagged        Add an untagged VLAN (bridge interface only).

EOF
    exit 1
}

# Handle options
AUTO=0
VLAN=""
NO_IP=0
VLAN_LEGACY=1
VLAN_TAGGED=0
VLAN_UNTAGGED=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -n|--no-ip)
            NO_IP=1
            shift
            ;;
        -t|--tagged)
            VLAN_LEGACY=0
            VLAN_TAGGED=1
            shift
            ;;
        -u|--untagged)
            VLAN_LEGACY=0
            VLAN_UNTAGGED=1
            shift
            ;;
        -*)
            for opt in $(echo ${1} 2>/dev/null | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    a) AUTO=1 ;;
                    n) NO_IP=1 ;;
                    t) VLAN_LEGACY=0 VLAN_TAGGED=1 ;;
                    u) VLAN_LEGACY=0 VLAN_UNTAGGED=1 ;;
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
VLAN="${3}"
INTERFACE="${4}"
IP="${5}"

# Verify parameter count
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    usage
fi

# Validate options
if [ "${ACTION}" != "add" ] && [ "${ACTION}" != "remove" ]; then
    error_exit "[ERROR]: Unsupported action: ${ACTION}"
fi
if ! echo "${VLAN}" | grep -Eoqs "^[0-9]+$"; then
    error_exit "[ERROR]: Invalid VLAN: ${VLAN}"
fi
if [ "$(bastille config ${TARGET} get vnet)" != "enabled" ];  then
    error_exit "[ERROR]: VLAN does not support non-VNET jails."
fi
if [ "${VLAN_TAGGED}" -eq 1 ] && [ "${VLAN_UNTAGGED}" -eq 1 ]; then
    error_exit "[ERROR]: Only one of [-t|--tagged] or [-u|--untagged] should be set."
elif [ "${VLAN_TAGGED}" -eq 1 ] || [ "${VLAN_UNTAGGED}" -eq 1 ]; then
    if ! ifconfig -g bridge | grep -Eoqs "^${INTERFACE}$"; then
        error_exit "[ERROR]: [-t|--tagged] and [-u|--untagged] requires a bridge interface."
    elif ! ifconfig "${INTERFACE}" | grep -Eoqs "flags.*\<VLANFILTER\>"; then
        error_exit "[ERROR]: [-t|--tagged] and [-u|--untagged] requries a bridge with 'vlanfilter' enabled."
    fi
fi
if [ "${ACTION}" = "add" ] && [ "${NO_IP}" -eq 1 ] && [ -n "${IP}" ]; then
    error_exit "[ERROR]: IP should not be specifed when using [-n|--no-ip]"
elif [ "${ACTION}" = "add" ] && [ "${NO_IP}" -eq 0 ] && [ -z "${IP}" ]; then
    error_exit "[ERROR]: IP is required when not using [-n|--no-ip]"
fi
if ! echo "${VLAN}" | grep -Eoq "^[0-9]+$"; then
    error_exit "[ERROR]: VLAN must be a numerical VLAN ID"
fi

bastille_root_check
set_target_single "${TARGET}"

add_vlan() {

    local jail_name="${1}"
    local interface="${2}"
    local vlan="${3}"
    local ip="${4}"
    local jail_config="${bastille_jailsdir}/${jail_name}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jail_name}/root/etc/rc.conf"

    if [ "${VLAN_LEGACY}" -eq 1 ]; then
        if ifconfig -g bridge | grep -Eoq "^${interface}$"; then
            local host_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
            local jail_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+' | sed 's/a_/b_/')"
            local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
        elif ! ifconfig -g bridge | grep -Eoq "^${interface}$"; then
            if grep -Eoq "ifconfig_${interface}" "${jail_rc_config}"; then
                local jail_vnet="${interface}"
            else
                local jib_epair="$(grep "jib addm.*${interface}" ${jail_config} | awk '{print $3}' | sed 's|^\\!||')"
                local host_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config} | sed 's/b_/a_/')"
                local jail_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config})"
                local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
            fi
        fi
		if [ "${NO_IP}" -eq 1 ]; then
            local ifconfig=""
		else
		    local ifconfig="inet ${ip}"
		fi
		sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="up"
		sysrc -f "${jail_rc_config}" vlans_${jail_vnet}+="${vlan}"
		sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_${vlan}="${ifconfig}"
    elif [ "${VLAN_TAGGED}" -eq 1 ]; then
        local host_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
        local jail_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+' | sed 's/a_/b_/')"
        local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
		local tagged_vlans="$(grep -Eo "ifconfig ${interface} addm ${host_epair}.* tagged.*" "${jail_config}" | grep -Eo " tagged [0-9,]+" | sed 's/ tagged //')"
		if [ "${NO_IP}" -eq 1 ]; then
            local ifconfig=""
		else
		    local ifconfig="inet ${ip}"
		fi
		if [ -z "${tagged_vlans}" ]; then
		    local tagged_vlans="${vlan}"
	        sed -i '' "/ifconfig ${interface} addm ${host_epair}/ s%addm ${host_epair}%addm ${host_epair} tagged ${tagged_vlans}%" "${jail_config}"
		else
		    local tagged_vlans="$(printf "%s,%s" "${tagged_vlans}" "${vlan}")"
	        sed -E -i '' "/ifconfig ${interface} addm ${host_epair}/ s% tagged [0-9,]+% tagged ${tagged_vlans}%" "${jail_config}"
		fi
		sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="up"
		sysrc -f "${jail_rc_config}" vlans_${jail_vnet}+="${vlan}"
		sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}_${vlan}="${ifconfig}"
    elif [ "${VLAN_UNTAGGED}" -eq 1 ]; then
		local host_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
        local jail_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+' | sed 's/a_/b_/')"
        local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
        sed -i '' "/ifconfig ${interface} addm ${host_epair}/ s%addm ${host_epair}%addm ${host_epair} untagged ${vlan}%" "${jail_config}"
		if [ "${NO_IP}" -eq 1 ]; then
            local ifconfig=""
		else
		    local ifconfig="inet ${ip}"
		fi
		sysrc -f "${jail_rc_config}" ifconfig_${jail_vnet}="${ifconfig}"
    fi

    info 2 "Added VLAN ${vlan_id} to interface: ${interface}"
}

remove_vlan() {

    local jail_name="${1}"
    local interface="${2}"
    local vlan="${3}"
    local jail_config="${bastille_jailsdir}/${jail_name}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jail_name}/root/etc/rc.conf"

    if [ "${VLAN_LEGACY}" -eq 1 ]; then
        if ifconfig -g bridge | grep -Eoq "^${interface}$"; then
            local host_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
            local jail_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+' | sed 's/a_/b_/')"
            local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
        elif ! ifconfig -g bridge | grep -Eoq "^${interface}$"; then
            if grep -Eoq "ifconfig_${interface}" "${jail_rc_config}"; then
                local jail_vnet="${interface}"
            else
                local jib_epair="$(grep "jib addm.*${interface}" ${jail_config} | awk '{print $3}' | sed 's|^\\!||')"
                local host_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config} | sed 's/b_/a_/')"
                local jail_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config})"
                local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
            fi
        fi
		sysrc -f "${jail_rc_config}" vlans_${jail_vnet}-="${vlan}"
		sed -i '' "/ifconfig_${jail_vnet}_${vlan}=.*/d" "${jail_rc_config}"
    elif [ "${VLAN_TAGGED}" -eq 1 ]; then
        local host_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
        local jail_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+' | sed 's/a_/b_/')"
        local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
		local tagged_vlans="$(grep -Eo "ifconfig ${interface} addm ${host_epair}.* tagged.*" "${jail_config}" | grep -Eo " tagged [0-9,]+" | sed 's/ tagged //')"
		if [ -z "${tagged_vlans}" ]; then
		    error_exit "[ERROR]: No VLANs found."
		else
		    local tagged_vlans="$(echo "${tagged_vlans}" | tr ',' '\n' | grep -ovx "${vlan}" | paste -sd, -)"
	        sed -i '' -E "/ifconfig ${interface} addm ${host_epair}/ s% tagged [0-9,]+% tagged ${tagged_vlans}%" "${jail_config}"
		fi
		sysrc -f "${jail_rc_config}" vlans_${jail_vnet}-="${vlan}"
		sed -i '' "/ifconfig_${jail_vnet}_${vlan}=.*/d" "${jail_rc_config}"
    elif [ "${VLAN_UNTAGGED}" -eq 1 ]; then
		sed -i '' "/ifconfig.*${interface}.*untagged.*${vlan}/ s% untagged ${vlan}%%" "${jail_config}"
	fi
}

check_interface_added() {

    local jail_name="${1}"
    local interface="${2}"
    local jail_config="${bastille_jailsdir}/${jail_name}/jail.conf"

	if grep -oq "${interface}" "${jail_config}"; then
		return 0
	else
	    return 1
	fi
}

check_vlan_added() {

    local jail_name="${1}"
    local interface="${2}"
    local vlan="${3}"
    local jail_config="${bastille_jailsdir}/${jail_name}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jail_name}/root/etc/rc.conf"

    if [ "${VLAN_LEGACY}" -eq 1 ]; then
        if grep -Eoq "ifconfig_.*_${vlan}" "${jail_rc_config}"; then
            return 0
		else
		    return 1
		fi
    elif [ "${VLAN_TAGGED}" -eq 1 ]; then
        if grep -Eo "${interface}.* tagged [0-9,]+" "${jail_config}" | grep -Eo "\btagged [0-9,]+" | grep -Eoq "\b${vlan}\b"; then
			return 0
		else
		    return 1
		fi
	elif [ "${VLAN_UNTAGGED}" -eq 1 ]; then
        if grep -Eo "${interface}.* untagged ${vlan}\b" "${jail_config}"; then
			return 0
        elif grep -Eoq "${interface}.* untagged [0-9]+" "${jail_config}"; then
		    if [ "${ACTION}" = "add" ]; then
		        error_exit "[ERROR]: Only one untagged VLAN can be added to an interface."
			elif [ "${ACTION}" = "remove" ]; then
		        error_exit "[ERROR]: VLAN has not been assigned to jail: ${vlan}"
            fi
		else
		    return 1
		fi
    fi
}

validate_netif() {

    local interface="${1}"

    if ! ifconfig -l | grep -qwo ${interface}; then
        error_exit "[ERROR]: Invalid interface: ${interface}"
    fi

    # Don't allow dots in INTERFACE if -V
    if echo "${INTERFACE}" | grep -q "\."; then
        error_exit "[ERROR]: Bastille does not support dots (.) in VNET interface names."
    fi
}

define_ips() {

    IP4_ADDR=""
    IP6_ADDR=""

    for ip in ${IP}; do
        validate_ip "${ip}" "1"
    done

    if [ -n "${IP4_ADDR}" ]; then
        if [ "${IP4_ADDR}" = "inherit" ] || [ "${IP4_ADDR}" = "ip_hostname" ]; then
            error_exit "[ERROR]: Unsupported IP option for VNET jail: ${IP4_ADDR}"
		fi
        if ifconfig | grep -qwF "${IP4_ADDR}"; then
            warn 1 "\n[WARNING]: IP address already in use: ${IP4_ADDR}"
        fi
    fi
}

info 1 "\n[${TARGET}]:"

# Validate interface
validate_netif "${INTERFACE}"

# Validate interface existence
if ! check_interface_added "${TARGET}" "${INTERFACE}"; then
    error_exit "[ERROR]: Interface is not assigned to jail: ${INTERFACE}"
fi

# Validate VLAN status
if [ "${ACTION}" = "add" ]; then
    if check_vlan_added "${TARGET}" "${INTERFACE}" "${VLAN}"; then
	    info 2 "VLAN has already been assinged: ${VLAN}"
		exit 0
	fi
elif [ "${ACTION}" = "remove" ]; then
    if ! check_vlan_added "${TARGET}" "${INTERFACE}" "${VLAN}"; then
	    error_exit "[ERROR]: VLAN is not assinged to jail: ${VLAN}"
    fi
fi

if [ -n "${IP}" ]; then
    define_ips "${IP}"
fi

# Validate jail state
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else
    info 1 "\n[${TARGET}]:"
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

if [ "${ACTION}" = "add" ]; then
	add_vlan "${TARGET}" "${INTERFACE}" "${VLAN}" "${IP4_ADDR}"
elif [ "${ACTION}" = "remove" ]; then
	remove_vlan "${TARGET}" "${INTERFACE}" "${VLAN}"
fi
if [ "${AUTO}" -eq 1 ]; then
	bastille start "${TARGET}"
fi
