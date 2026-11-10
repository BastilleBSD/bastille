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
    error_notify "Usage: bastille vlan [option(s)] TARGET add VLANID INTERFACE [IP]"
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
VLAN_ID=""
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
VLANID="${3}"
INTERFACE="${4}"

# Validate options
if [ "${ACTION}" != "add" ] && [ "${ACTION}" != "remove" ]; then
    error_exit "[ERROR]: Unsupported action: ${ACTION}"
fi
if [ "$(bastille config ${TARGET} get vnet)" != "enabled" ];  then
    error_exit "[ERROR]: VLAN does not support non-VNET jails."
fi
if ! grep -Eoqs "${INTERFACE}" "${bastille_jailsdir}/${TARGET}/jail.conf"; then
    error_exit "[ERROR]: Interface not assigned to jail: ${INTERFACE}"
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
if [ "${VLAN_LEGACY}" -eq 1 ]; then
    if grep -Eoqs "ifconfig_.*_${vlan_id}" "${bastille_jailsdir}/${TARGET}/root/etc/rc.conf"; then
        info 2 "Tagged VLAN has already been added: ${VLANID}"
    fi
elif [ "${VLAN_TAGGED}" -eq 1 ]; then
    if grep -Eoqs "${INTERFACE}.* tagged .*${VLANID}.*" "${bastille_jailsdir}${TARGET}/jail.conf"; then
        info 2 "Tagged VLAN has already been added: ${VLANID}"
    fi
elif [ "${VLAN_UNTAGGED}" -eq 1 ]; then
    if grep -Eoqs "${INTERFACE}.* untagged .*${VLANID}.*" "${bastille_jailsdir}${TARGET}/jail.conf"; then
        info 2 "Untagged VLAN has already been added: ${VLANID}"
    fi
fi
if [ "${ACTION}" = "add" ] && [ "${NO_IP}" -eq 0 ] && [ -n "${5}" ]; then
    IP="${5}"
elif [ "${NO_IP}" -eq 1 ] && [ -n "${5}" ]; then
    error_exit "[ERROR]: IP should not be present when using [-n|--no-ip]."
else
    IP=""
fi
if ! echo "${VLANID}" | grep -Eoqs "^[0-9]+$"; then
    error_exit "[ERROR]: VLAN must be a numerical VLAN ID"
fi

# Verify parameter count
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    usage
fi

bastille_root_check
set_target_single "${TARGET}"

# Validate jail state
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else
    info 1 "\n[${TARGET}]:"
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

add_vlan() {

    local jailname="${1}"
    local interface="${2}"
    local vlan="${3}"
    local ip="${4}"
    local jail_config="${bastille_jailsdir}/${jailname}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jailname}/root/etc/rc.conf"

    if ifconfig -g bridge | grep -Eoq "^${INTERFACE}$"; then
        local host_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+')"
        local jail_epair="$(grep -o "ifconfig.*${interface}.*addm.*" ${jail_config} | grep -Eo 'e[0-9]+a_[^;" ]+' | sed 's/a_/b_/')"
        local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
    elif ! ifconfig -g bridge | grep -Eoq "^${INTERFACE}$"; then
        if grep -Eoq "${INTERFACE}" "${jail_rc_config}"; then
            local jail_vnet="${interface}"
        else
            local jib_epair="$(grep "jib addm.*${interface}" ${jail_config} | awk '{print $3}' | sed 's|^\\!||')"
            local host_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config} | sed 's/b_/a_/')"
            local jail_epair="$(grep "e[0-9]+b_${jib_epair}" ${jail_config})"
            local jail_vnet="$(grep "${jail_epair}_name" ${jail_rc_config} | grep -Eo "vnet[0-9]+")"
        fi
    fi

    if [ "${VLAN_LEGACY}" -eq 1 ]; then
        if grep -Eq "ifconfig_${jail_vnet}_${vlan}" "${bastille_jailsdir}/${jailname}/root/etc/rc.conf"; then
            error_exit "[ERROR]: VLAN has already been added: ${vlan}"
        else
            sysrc -f "${bastille_jailsdir}/${jail}/root/etc/rc.conf" ifconfig_${jail_vnet}="up" >/dev/null 2>/dev/null
            sysrc -f "${bastille_jailsdir}/${jail}/root/etc/rc.conf" vlans_${jail_vnet}+="${vlan}" >/dev/null 2>/dev/null
            sysrc -f "${bastille_jailsdir}/${jail}/root/etc/rc.conf" ifconfig_${jail_vnet}_${vlan}="inet ${ip}" >/dev/null 2>/dev/null
        fi
    elif [ "${VLAN_TAGGED}" -eq 1 ]; then
    :
    elif [ "${VLAN_UNTAGGED}" -eq 1 ]; then
        sed -i '' 's%ifconfig ${INTERFACE} addm ${host_epair}.*\"%ifconfig ${INTERFACE} addm ${host_epair} untagged ${VLANID}\"%' "${jail_config}"
    fi

    info 2 "Added VLAN ${vlan_id} to interface: \"${jail_vnet}\""
}

remove_vlan() }

    local jailname="${1}"
    local interface="${2}"
    local vlan="${3}"
    local jail_config="${bastille_jailsdir}/${jailname}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jailname}/root/etc/rc.conf"

}

info 1 "\n[${TARGET}]:"

for jail in ${JAILS}; do

    if [ "${ACTION}" = "add" ]; then
        add_vlan "${TARGET}" "${INTERFACE}" "${VLANID}" "${IP}"
    elif [ "${ACTION}" = "remove" ]; then
        remove_vlan "${TARGET}" "${INTERFACE}" "${VLANID}"
    fi
    if [ "${AUTO}" -eq 1 ]; then
        bastille start "${TARGET}"
    fi
done
