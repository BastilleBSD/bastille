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
    error_notify "Usage: bastille limits [option(s)] TARGET [add|remove|clear|reset|(list|show [active])|stats] OPTION [VALUE]"
    cat << EOF
	
	Example: bastille limits TARGET add memoryuse 1G
    Example: bastille limits TARGET add cpu 0,1,2
	
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -l | --log            Enable logging for the specified rule (rctl only).
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
OPT_LOG=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -l|--log)
            OPT_LOG=1
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
                    l) OPT_LOG=1 ;;
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
    error_exit "[ERROR]: Racct not enabled. Append 'kern.racct.enable=1' to /boot/loader.conf and reboot"
fi

bastille_root_check
set_target "${TARGET}"

validate_cpus() {

    local _cpus="${1}"

    for _cpu in $(echo ${_cpus} | sed 's/,/ /g'); do
        if ! cpuset -l ${_cpu} 2>/dev/null; then
            error_notify "[ERROR]: CPU is not available: ${_cpu}"
            return 1
        fi
    done

}

add_cpuset() {

    local _jail="${1}"
    local _cpus="${2}"
    local _cpuset_rule="$(echo ${_cpus} | sed 's/ /,/g')"

    # Persist cpuset value
    echo "${_cpuset_rule}" >> "${bastille_jailsdir}/${_jail}/cpuset.conf"
    echo -e "Limits: ${OPTION} ${VALUE}"

    # Restart jail to apply cpuset
    bastille restart ${_jail}

}

for _jail in ${JAILS}; do

    (

    check_target_is_running "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    else
        info "\n[${_jail}]:"
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi

    info "\n[${_jail}]:"
    
    case "${ACTION}" in

        add)

            OPTION="${1}"
            VALUE="${2}"

            # Limit cpus for jail
            if [ "${OPTION}" = "cpu" ] || [ "${OPTION}" = "cpus" ] || [ "${OPTION}" = "cpuset" ]; then
                validate_cpus "${VALUE}" || continue
                add_cpuset "${_jail}" "${VALUE}"
            else
                # Add rctl rule to rctl.conf
                _rctl_rule="jail:${_jail}:${OPTION}:deny=${VALUE}/jail"
                _rctl_rule_log="jail:${_jail}:${OPTION}:log=${VALUE}/jail"
                # Check whether the entry already exists and, if so, update it. -- cwells
                if grep -qs "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf"; then
    	            _escaped_option=$(echo "${OPTION}" | sed 's/\//\\\//g')
    	            _escaped_rctl_rule=$(echo "${_rctl_rule}" | sed 's/\//\\\//g')
    	            _escaped_rctl_rule_log=$(echo "${_rctl_rule_log}" | sed 's/\//\\\//g')
                    sed -i '' -E "s/jail:${_jail}:${_escaped_option}:deny.+/${_escaped_rctl_rule}/" "${bastille_jailsdir}/${_jail}/rctl.conf"
                    if [ "${OPT_LOG}" -eq 1 ]; then
                        sed -i '' -E "s/jail:${_jail}:${_escaped_option}:log.+/${_escaped_rctl_rule_log}/" "${bastille_jailsdir}/${_jail}/rctl.conf"
                    fi
                else # Just append the entry. -- cwells
                    echo "${_rctl_rule}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
                    if [ "${OPT_LOG}" -eq 1 ]; then
                        echo "${_rctl_rule_log}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
                    fi
                    if [ "${OPT_LOG}" -eq 1 ]; then
                        echo -e "[LOGGING]: ${OPTION} ${VALUE}"
                    else
                        echo -e "${OPTION} ${VALUE}"
                    fi
                    rctl -a "${_rctl_rule}"
                    if [ "${OPT_LOG}" -eq 1 ]; then
                        rctl -a "${_rctl_rule_log}"
                    fi
                fi
            fi
            ;;

        remove)

            OPTION="${1}"

            if [ "${OPTION}" = "cpu" ] || [ "${OPTION}" = "cpus" ] || [ "${OPTION}" = "cpuset" ]; then

                # Remove cpuset.conf
                if [ -s "${bastille_jailsdir}/${_jail}/cpuset.conf" ]; then
                    rm -f "${bastille_jailsdir}/${_jail}/cpuset.conf"
                    echo "cpuset.conf removed."
                else
                    error_continue "[ERROR]: cpuset.conf not found."
                fi

                # Restart jail to clear cpuset
                bastille restart ${_jail}

            else
                if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then

                    # Remove rule from rctl.conf
                    if grep -qs "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf"; then
                        _rctl_rule="$(grep "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf")"
                        _rctl_rule_log="$(grep "jail:${_jail}:${OPTION}:log" "${bastille_jailsdir}/${_jail}/rctl.conf")"
                        rctl -r "${_rctl_rule}" "${_rctl_rule_log}" 2>/dev/null
                        sed -i '' "/.*${_jail}:${OPTION}.*/d" "${bastille_jailsdir}/${_jail}/rctl.conf"
                    fi
                fi
            fi
            ;;

        clear)

            # Remove rctl limits (rctl only)
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                while read _limits; do
                    rctl -r "${_limits}" 2>/dev/null
                done < "${bastille_jailsdir}/${_jail}/rctl.conf"
                echo "RCTL limits cleared."
            fi
	        ;;

        list|show)

            # Show rctl limits
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then

                echo "-------------"
                echo "[RCTL Limits]"

	        if [ "${1}" = "active" ]; then
	            rctl jail:${_jail} 2>/dev/null
	        else
	            cat "${bastille_jailsdir}/${_jail}/rctl.conf"
	        fi
            fi

            # Show cpuset limits
            if [ -s "${bastille_jailsdir}/${_jail}/cpuset.conf" ]; then

                echo "-------------"
                echo "[CPU Limits]"

	        if [ "${1}" = "active" ]; then
	            cpuset -g -j ${_jail} | head -1 2>/dev/null
	        else
	            cat "${bastille_jailsdir}/${_jail}/cpuset.conf"
	        fi
            fi
            ;;

        stats)

            # Show statistics (rctl only)
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
	            rctl -hu jail:${_jail} 2>/dev/null
            fi
            ;;

        reset)

            # Remove active limits
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                while read _limits; do
                    rctl -r "${_limits}" 2>/dev/null
                done < "${bastille_jailsdir}/${_jail}/rctl.conf"
	            echo "RCTL limits cleared."
            fi

            # Remove rctl.conf
            if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
                rm -f "${bastille_jailsdir}/${_jail}/rctl.conf"
                echo "rctl.conf removed."
            else
                error_continue "[ERROR]: rctl.conf not found."
            fi

            # Remove cpuset.conf
            if [ -s "${bastille_jailsdir}/${_jail}/cpuset.conf" ]; then
                rm -f "${bastille_jailsdir}/${_jail}/cpuset.conf"
                echo "cpuset.conf removed."
            else
                error_continue "[ERROR]: cpuset.conf not found."
            fi

            # Restart jail to clear cpuset
            bastille restart ${_jail}
            ;;

    esac

    ) &
	
    bastille_running_jobs "${bastille_process_limit}"
	
done
wait
