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

# Load config. This only has to be done here
# because all commands load this file
# shellcheck disable=SC1090
. ${BASTILLE_CONFIG}
	
COLOR_RED=
COLOR_GREEN=
COLOR_YELLOW=
COLOR_RESET=

bastille_root_check() {
    if [ "$(id -u)" -ne 0 ]; then
        ## permission denied
        error_notify "Bastille: Permission Denied"
        error_exit "root / sudo / doas required"
    fi
}

enable_color() {
    . /usr/local/share/bastille/colors.pre.sh
}

enable_debug() {
    # Enable debug mode.
    warn "***DEBUG MODE***"
    set -x
} 

# If "NO_COLOR" environment variable is present, or we aren't speaking to a
# tty, disable output colors.
if [ -z "${NO_COLOR}" ] && [ -t 1 ]; then
    enable_color
fi

# Notify message on error
# Do not echo blank line
error_continue() {
    error_notify "$@"
    # shellcheck disable=SC2104
    continue
}

# Notify message on error, but do not exit
error_notify() {
    echo -e "${COLOR_RED}$*${COLOR_RESET}" 1>&2
}

# Notify message on error and exit
# Echo blank line when exiting
error_exit() {
    error_notify "$@"
    echo
    exit 1
}

info() {
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}"
}

warn() {
    echo -e "${COLOR_YELLOW}$*${COLOR_RESET}"
}

check_target_exists() {
    local _TARGET="${1}"
    local _jaillist="$(bastille list jails)"
    if ! echo "${_jaillist}" | grep -Eq "^${_TARGET}$"; then
        return 1
    else
        return 0
    fi
}

check_target_is_running() {
    _TARGET="${1}"
    if ! jls name | grep -Eq "^${_TARGET}$"; then
        return 1
    else
        return 0
    fi
}

check_target_is_stopped() {
    _TARGET="${1}"
    if jls name | grep -Eq "^${_TARGET}$"; then
        return 1
    else
        return 0
    fi
}

get_bastille_if_count() {
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        for _config in /usr/local/etc/bastille/*.conf; do
            local bastille_jailsdir="$(sysrc -f "${_config}" -n bastille_jailsdir)"
            _bastille_if_list="$(printf '%s\n%s' "$( (grep -Ehos '(epair[0-9]+|bastille[0-9]+)' ${bastille_jailsdir}/*/jail.conf; ifconfig -g epair | grep -Eos "_bastille[0-9]+$"; ifconfig -g epair | grep -vs 'bastille' | grep -Eos 'e[0-9]+a_') | grep -Eos '[0-9]+')" "${_bastille_if_list}")"
        done
        _bastille_if_count=$(printf '%s' "${_bastille_if_list}" | sort -u | wc -l | awk '{print $1}')
        export _bastille_if_list
        export _bastille_if_count
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        for _config in /usr/local/etc/bastille/*.conf; do
            local bastille_jailsdir="$(sysrc -f "${_config}" -n bastille_jailsdir)"
            _bastille_if_list="$(printf '%s\n%s' "$( (grep -Ehos 'ng[0-9]+_bastille[0-9]+' ${bastille_jailsdir}/*/jail.conf | grep -Eos 'bastille[0-9]+'; ngctl list -n | grep "eiface" | grep -Eos 'ng[0-9]+_bastille[0-9]+' | grep -Eos 'bastille[0-9]+') | grep -Eos '[0-9]+')" "${_bastille_if_list}")"
        done
        _bastille_if_count=$(printf '%s' "${_bastille_if_list}" | sort -u | wc -l | awk '{print $1}')
        export _bastille_if_list
        export _bastille_if_count
    fi
}

get_jail_name() {
    local _JID="${1}"
    local _jailname="$(jls -j ${_JID} name 2>/dev/null)"
    if [ -z "${_jailname}" ]; then
        return 1
    else
        echo "${_jailname}"
    fi
}

jail_autocomplete() {
    local _TARGET="${1}"
    local _jaillist="$(bastille list jails)"
    local _AUTOTARGET="$(echo "${_jaillist}" | grep -E "^${_TARGET}")"
    if [ -n "${_AUTOTARGET}" ]; then
        if [ "$(echo "${_AUTOTARGET}" | wc -l)" -eq 1 ]; then
            echo "${_AUTOTARGET}"
        else
            error_continue "Multiple jails found for ${_TARGET}:\n${_AUTOTARGET}"
            return 1
        fi
    else
        return 2
    fi
}

list_jail_priority() {
    local _jail_list="${1}"
    if [ -d "${bastille_jailsdir}" ]; then
        for _jail in ${_jail_list}; do
            local _boot_file=${bastille_jailsdir}/${_jail}/boot.conf
            # Set defaults if boot file does not exist
            if [ ! -f ${_boot_file} ]; then
                sysrc -f ${_boot_file} boot=on > /dev/null 2>&1
                sysrc -f ${_boot_file} priority=99 > /dev/null 2>&1
            fi
            _priority="$(sysrc -f ${bastille_jailsdir}/${_jail}/boot.conf -n priority)"
            echo "${_jail} ${_priority}"
        done
    fi
}

set_target() {
    local _TARGET=${1}
    if [ "${2}" = "reverse" ]; then
        local _order="${2}"
    else
        local _order="forward"
    fi
    JAILS=""
    TARGET=""
    if [ "${_TARGET}" = ALL ] || [ "${_TARGET}" = all ]; then
        target_all_jails
    else
        for _jail in ${_TARGET}; do
            if [ ! -d "${bastille_jailsdir}/${_TARGET}" ] && echo "${_jail}" | grep -Eq '^[0-9]+$'; then
                if get_jail_name "${_jail}" > /dev/null; then
                    _jail="$(get_jail_name ${_jail})"
                else
                    error_continue "Error: JID \"${_jail}\" not found. Is jail running?"
                fi
            elif ! check_target_exists "${_jail}"; then
                if jail_autocomplete "${_jail}" > /dev/null; then
                    _jail="$(jail_autocomplete ${_jail})"
                elif [ $? -eq 2 ]; then
                    error_continue "Jail not found \"${_jail}\""
                else
                    echo
                    exit 1
                fi
            fi
            TARGET="${TARGET} ${_jail}"
            JAILS="${JAILS} ${_jail}"
        done
        if [ "${_order}" = "forward" ]; then
            TARGET="$(list_jail_priority "${TARGET}" | sort -k2 -n | awk '{print $1}')"
            JAILS="$(list_jail_priority "${TARGET}" | sort -k2 -n | awk '{print $1}')"
        elif [ "${_order}" = "reverse" ]; then
            TARGET="$(list_jail_priority "${TARGET}" | sort -k2 -nr | awk '{print $1}')"
            JAILS="$(list_jail_priority "${TARGET}" | sort -k2 -nr | awk '{print $1}')"
        fi
        export TARGET
        export JAILS
    fi
}

set_target_single() {
    local _TARGET="${1}"
    if [ "${_TARGET}" = ALL ] || [ "${_TARGET}" = all ]; then
        error_exit "[all|ALL] not supported with this command."
    elif [ "$(echo ${_TARGET} | wc -w)" -gt 1 ]; then
        error_exit "Error: Command only supports a single TARGET."
    elif [ ! -d "${bastille_jailsdir}/${_TARGET}" ] && echo "${_TARGET}" | grep -Eq '^[0-9]+$'; then
        if get_jail_name "${_TARGET}" > /dev/null; then
            _TARGET="$(get_jail_name ${_TARGET})"
        else
            error_exit "Error: JID \"${_TARGET}\" not found. Is jail running?"
        fi
    elif ! check_target_exists "${_TARGET}"; then
            if jail_autocomplete "${_TARGET}" > /dev/null; then
                _TARGET="$(jail_autocomplete ${_TARGET})"
            elif [ $? -eq 2 ]; then
                error_exit "Jail not found \"${_TARGET}\""
            else
                echo
                exit 1
            fi
    fi
    TARGET="${_TARGET}"
    JAILS="${_TARGET}"
    export TARGET
    export JAILS
}

target_all_jails() {
    local _JAILS="$(bastille list jails)"
    JAILS=""
    for _jail in ${_JAILS}; do
        if [ -d "${bastille_jailsdir}/${_jail}" ]; then
            JAILS="${JAILS} ${_jail}"
        fi
    done
    if [ "${_order}" = "forward" ]; then
        JAILS="$(list_jail_priority "${JAILS}" | sort -k2 -n | awk '{print $1}')"
    elif [ "${_order}" = "reverse" ]; then
        JAILS="$(list_jail_priority "${JAILS}" | sort -k2 -nr | awk '{print $1}')"
    fi
    export JAILS
}

update_fstab() {
    local _oldname="${1}"
    local _newname="${2}"
    local _fstab="${bastille_jailsdir}/${_newname}/fstab"
    if [ -f "${_fstab}" ]; then
        sed -i '' "s|${bastille_jailsdir}/${_oldname}/root/|${bastille_jailsdir}/${_newname}/root/|" "${_fstab}"
    else
        error_notify "Error: Failed to update fstab: ${_newmane}"
    fi
}

generate_static_mac() {
    local jail_name="${1}"
    local external_interface="${2}"
    local external_interface_mac="$(ifconfig ${external_interface} | grep ether | awk '{print $2}')"
    # Use FreeBSD vendor MAC prefix (58:9c:fc) for jail MAC prefix
    local macaddr_prefix="58:9c:fc"
    # Use hash of interface+jailname for jail MAC suffix
    local macaddr_suffix="$(echo -n "${external_interface_mac}${jail_name}" | sed 's#:##g' | sha256 | cut -b -5 | sed 's/\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F]\)/\1:\2:\3/')"
    if [ -z "${macaddr_prefix}" ] || [ -z "${macaddr_suffix}" ]; then
        error_notify "Failed to generate MAC address."
    fi
    macaddr="${macaddr_prefix}:${macaddr_suffix}"
    export macaddr
}

generate_vnet_jail_netblock() {
    local jail_name="${1}"
    local use_unique_bridge="${2}"
    local external_interface="${3}"
    local static_mac="${4}"
    # Get number of epairs on the system
    get_bastille_if_count
    local _bastille_if_num_range=$((_bastille_if_count + 1))
    if [ -n "${use_unique_bridge}" ]; then
        if [ "${_bastille_if_count}" -gt 0 ]; then  
            for _num in $(seq 0 "${_bastille_if_num_range}"); do
                if ! echo "${_bastille_if_list}" | grep -oqswx "${_num}"; then
                    if [ "$(echo -n "e${_num}a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                        local host_epair=e${_num}a_${jail_name}
                        local jail_epair=e${_num}b_${jail_name}
                    else
                        local host_epair=epair${_num}a
                        local jail_epair=epair${_num}b
                    fi
                    break
                fi
            done
        else
            if [ "$(echo -n "e0a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                local _num=0
                local host_epair=e${_num}a_${jail_name}
                local jail_epair=e${_num}b_${jail_name}
            else
                local _num=0
                local host_epair=epair${_num}a
                local jail_epair=epair${_num}b
            fi
        fi
    else
        if [ "${_bastille_if_count}" -gt 0 ]; then  
            for _num in $(seq 0 "${_bastille_if_num_range}"); do
                if ! echo "${_bastille_if_list}" | grep -oqswx "${_num}"; then
                    local _jail_if="bastille${_num}"
                    break
                fi
            done
        else
            local _jail_if="bastille0"
        fi
    fi
    ## If BRIDGE is enabled, generate bridge config, else generate VNET config
    if [ -n "${use_unique_bridge}" ]; then
        if [ -n "${static_mac}" ]; then
            ## Generate bridged VNET config with static MAC address
            generate_static_mac "${jail_name}" "${external_interface}"
            cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "ifconfig epair${_num} create";
  exec.prestart += "ifconfig ${external_interface} addm epair${_num}a";
  exec.prestart += "ifconfig epair${_num}a up name ${host_epair}";
  exec.prestart += "ifconfig epair${_num}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${external_interface} deletem ${host_epair}";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
        else
            ## Generate bridged VNET config without static MAC address
            cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "ifconfig epair${_num} create";
  exec.prestart += "ifconfig ${external_interface} addm epair${_num}a";
  exec.prestart += "ifconfig epair${_num}a up name ${host_epair}";
  exec.prestart += "ifconfig epair${_num}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${external_interface} deletem ${host_epair}";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
        fi
    else
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
            if [ -n "${static_mac}" ]; then
                ## Generate VNET config with static MAC address
                generate_static_mac "${jail_name}" "${external_interface}"
                cat <<-EOF
  vnet;
  vnet.interface = e0b_${_jail_if};
  exec.prestart += "jib addm ${_jail_if} ${external_interface}";
  exec.prestart += "ifconfig e0a_${_jail_if} ether ${macaddr}a";
  exec.prestart += "ifconfig e0b_${_jail_if} ether ${macaddr}b";
  exec.prestart += "ifconfig e0a_${_jail_if} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "jib destroy ${_jail_if}";
EOF
            else
                ## Generate VNET config without static MAC address
                cat <<-EOF
  vnet;
  vnet.interface = e0b_${_jail_if};
  exec.prestart += "jib addm ${_jail_if} ${external_interface}";
  exec.prestart += "ifconfig e0a_${_jail_if} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "jib destroy ${_jail_if}";
EOF
            fi
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
            if [ -n "${static_mac}" ]; then
                ## Generate VNET config with static MAC address
                generate_static_mac "${jail_name}" "${external_interface}"
                cat <<-EOF
  vnet;
  vnet.interface = ng0_${_jail_if};
  exec.prestart += "jng bridge ${_jail_if} ${external_interface}";
  exec.prestart += "ifconfig ng0_${_jail_if} ether ${macaddr}a";
  exec.poststop += "jng shutdown ${_jail_if}";
EOF
            else
                ## Generate VNET config without static MAC address
                cat <<-EOF
  vnet;
  vnet.interface = ng0_${_jail_if};
  exec.prestart += "jng bridge ${_jail_if} ${external_interface}";
  exec.poststop += "jng shutdown ${_jail_if}";
EOF
            fi
        fi
    fi
}

validate_netconf() {
    if [ -n "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
        error_exit "[ERROR]: 'bastille_network_loopback' and 'bastille_network_shared' cannot both be set."
    fi
    if [ "${bastille_network_vnet_type}" != "if_bridge" ] && [ "${bastille_network_vnet_type}" != "netgraph" ]; then
        error_exit "[ERROR]: 'bastille_network_vnet_type' not set properly: ${bastille_network_vnet_type}"
    fi
}

checkyesno() {
    ## copied from /etc/rc.subr -- cedwards (20231125)
    ## issue #368 (lowercase values should be parsed)
    ## now used for all bastille_zfs_enable=YES|NO tests
    ## example: if checkyesno bastille_zfs_enable; then ...
    ## returns 0 for enabled; returns 1 for disabled
    eval _value=\$${1}
    case $_value in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
        return 0
        ;;
    [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
        return 1
        ;;
    *)
        warn "\$${1} is not set properly - see rc.conf(5)."
        return 1
        ;;
    esac
}