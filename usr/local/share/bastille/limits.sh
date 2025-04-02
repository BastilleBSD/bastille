#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
# Ressource limits added by Sven R github.com/hackacad
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
    error_notify "Usage: bastille limits [option(s)] TARGET [add OPTION VALUE|remove OPTION|clear|reset|[list|show] (active)|stats]"
    echo -e "Example: bastille limits TARGET add memoryuse 1G"
    cat << EOF
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
	-h|--help|help)
	    usage
	    ;;
	-a|--auto)
	    AUTO=1
	    shift
	    ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
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

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    usage
fi

TARGET="${1}"
ACTION="${2}"
# Retain support for no action (will default to add) 
if [ "${ACTION}" != "add" ] && [ "${ACTION}" != "remove" ] && [ "${ACTION}" != "clear" ] && [ "${ACTION}" != "list" ] && [ "${ACTION}" != "show" ] && [ "${ACTION}" != "reset" ] && [ "${ACTION}" != "stats" ]; then
    ACTION="add"
    shift 1
else
    ACTION="${2}"
    shift 2
fi

RACCT_ENABLE="$(sysctl -n kern.racct.enable)"
if [ "${RACCT_ENABLE}" != '1' ]; then
    error_exit "Racct not enabled. Append 'kern.racct.enable=1' to /boot/loader.conf and reboot"
fi

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do

    info "[${_jail}]:"

    check_target_is_running "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    else   
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi
    
    case "${ACTION}" in
        add)
            OPTION="${1}"
            VALUE="${2}"
            # Add rctl rule to rctl.conf
            _rctl_rule="jail:${_jail}:${OPTION}:deny=${VALUE}/jail"
            _rctl_rule_log="jail:${_jail}:${OPTION}:log=${VALUE}/jail"

            # Check whether the entry already exists and, if so, update it. -- cwells
            if grep -qs "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf"; then
    	        _escaped_option=$(echo "${OPTION}" | sed 's/\//\\\//g')
    	        _escaped_rctl_rule=$(echo "${_rctl_rule}" | sed 's/\//\\\//g')
    	        _escaped_rctl_rule_log=$(echo "${_rctl_rule_log}" | sed 's/\//\\\//g')
                sed -i '' -E "s/jail:${_jail}:${_escaped_option}:deny.+/${_escaped_rctl_rule}/" "${bastille_jailsdir}/${_jail}/rctl.conf"
                sed -i '' -E "s/jail:${_jail}:${_escaped_option}:log.+/${_escaped_rctl_rule_log}/" "${bastille_jailsdir}/${_jail}/rctl.conf"
            else # Just append the entry. -- cwells
                echo "${_rctl_rule}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
                echo "${_rctl_rule_log}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
            fi

            echo -e "${OPTION} ${VALUE}"
            rctl -a "${_rctl_rule}" "${_rctl_rule_log}"
            ;;
        remove)
            OPTION="${1}"
            # Remove rule from rctl.conf
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                if grep -qs "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf"; then
                    _rctl_rule="$(grep "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf")"
                    _rctl_rule_log="$(grep "jail:${_jail}:${OPTION}:log" "${bastille_jailsdir}/${_jail}/rctl.conf")"
                    rctl -r "${_rctl_rule}" "${_rctl_rule_log}" 2>/dev/null
                    sed -i '' "/.*${_jail}:${OPTION}.*/d" "${bastille_jailsdir}/${_jail}/rctl.conf"
                fi
            fi
            ;;
        clear)
            # Remove limits
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                while read _limits; do
                    rctl -r "${_limits}" 2>/dev/null
                done < "${bastille_jailsdir}/${_jail}/rctl.conf"
                info "[${_jail}]: RCTL limits cleared."
            fi
	        ;;
        list|show)
            # Show limits
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
	        if [ "${1}" = "active" ]; then
	            rctl jail:${_jail} 2>/dev/null
	        else
	            cat "${bastille_jailsdir}/${_jail}/rctl.conf"
	        fi
            fi
            ;;
        stats)
            # Show statistics
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
	        rctl -hu jail:${_jail} 2>/dev/null
            fi
            ;;
        reset)
            # Remove limits and delete rctl.conf
	    if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                while read _limits; do
                    rctl -r "${_limits}" 2>/dev/null
                done < "${bastille_jailsdir}/${_jail}/rctl.conf"
	        info "[${TARGET}]: RCTL limits cleared."
            fi
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                rm -f "${bastille_jailsdir}/${_jail}/rctl.conf"
                info "[${TARGET}]: rctl.conf removed."
            else
                error_continue "[${TARGET}]: rctl.conf not found."
            fi
            ;;
    esac
done
