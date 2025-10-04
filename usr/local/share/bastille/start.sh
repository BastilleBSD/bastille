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

usage() {
    error_notify "Usage: bastille start [option(s)] TARGET"
    cat << EOF

    Options:

    -b | --boot                 Respect jail boot setting.
    -d | --delay VALUE          Time (seconds) to wait after starting each jail.
    -v | --verbose              Print every action on jail start.
    -x | --debug                Enable debug mode.

EOF
    exit 1
}

# Handle options.
BOOT=0
DELAY_TIME=0
OPTION=""
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -b|--boot)
            BOOT=1
            shift
            ;;
        -d|--delay)
            if [ -z "${2}" ] && ! echo "${2}" | grep -Eq '^[0-9]+$'; then
                error_exit "[-d|--delay] requires a value."
            else
                DELAY_TIME="${2}"
            fi
            shift 2
            ;;
        -v|--verbose)
            OPTION="-v"
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    b) BOOT=1 ;;
                    v) OPTION="-v" ;;
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

if [ "$#" -ne 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do

    # Continue if '-b|--boot' is set and 'boot=off'
    if [ "${BOOT}" -eq 1 ]; then
        BOOT_ENABLED="$(sysrc -f ${bastille_jailsdir}/${_jail}/settings.conf -n boot)"
        if [ "${BOOT_ENABLED}" = "off" ]; then
            continue
        fi
    fi

    # Validate that all 'depends' jails are running
    _depend_jails="$(sysrc -f ${bastille_jailsdir}/${_jail}/settings.conf -n depend)"
    for _depend_jail in ${_depend_jails}; do
        if check_target_is_running; then
            continue
        else
            bastille start ${_depend_jail}
        fi
    done

    if check_target_is_running "${_jail}"; then
        info "\n[${_jail}]:"
        error_continue "Jail is already running."
    fi

    info "\n[${_jail}]:"

    # Validate interfaces and add IPs to firewall table
    if [ "$(bastille config ${_jail} get vnet)" != 'enabled' ]; then
        _ip4_interfaces="$(bastille config ${_jail} get ip4.addr | sed 's/,/ /g')"
        _ip6_interfaces="$(bastille config ${_jail} get ip6.addr | sed 's/,/ /g')"
        # IP4
        if [ "${_ip4_interfaces}" != "not set" ]; then
            for _interface in ${_ip4_interfaces}; do
                if echo "${_interface}" | grep -q "|"; then
                    _if="$(echo ${_interface} 2>/dev/null | awk -F"|" '{print $1}')"
                    _ip="$(echo ${_interface} 2>/dev/null | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
                else
                    _if="$(bastille config ${_jail} get interface)"
                    _ip="$(echo ${_interface} | sed -E 's#/[0-9]+$##g')"
                fi
                if ifconfig | grep "^${_if}:" >/dev/null; then
                    if ifconfig | grep -qwF "${_ip}"; then
                        warn "[WARNING]: IP address (${_ip}) already in use, continuing..."
                    fi
                    ## add ip to firewall table if it is not reachable through local interface (assumes NAT/rdr is needed)
                    if route -n get ${_ip} | grep "gateway" >/dev/null; then
                        pfctl -q -t "${bastille_network_pf_table}" -T add "${_ip}"
                    fi
                else
                    error_continue "[ERROR]: ${_if} interface does not exist."
                fi
            done
        fi
        # IP6
        if [ "${_ip6_interfaces}" != "not set" ]; then
            for _interface in ${_ip6_interfaces}; do
                if echo "${_interface}" | grep -q "|"; then
                    _if="$(echo ${_interface} | awk -F"|" '{print $1}')"
                    _ip="$(echo ${_interface} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
                else
                    _if="$(bastille config ${_jail} get interface)"
                    _ip="$(echo ${_interface} | sed -E 's#/[0-9]+$##g')"
                fi
                if ifconfig | grep "^${_if}:" >/dev/null; then
                    if ifconfig | grep -qwF "${_ip}"; then
                        warn "[WARNING]: IP address (${_ip}) already in use, continuing..."
                    fi
                    ## add ip to firewall table if it is not reachable through local interface (assumes NAT/rdr is needed)
                    if route -6 -n get ${_ip} | grep "gateway" >/dev/null; then
                        pfctl -q -t "${bastille_network_pf_table}" -T add "${_ip}"
                    fi
                else
                    error_continue "[ERROR]: ${_if} interface does not exist."
                fi
            done
        fi
    fi

    # Start jail
    jail ${OPTION} -f "${bastille_jailsdir}/${_jail}/jail.conf" -c "${_jail}"

    # Add ZFS jailed datasets
    if [ -s "${bastille_jailsdir}/${_jail}/zfs.conf" ]; then
        while read _dataset _mount; do
            zfs set jailed=on "${_dataset}"
            zfs jail ${_jail} "${_dataset}"
            jexec -l -U root "${_jail}" zfs set mountpoint="${_mount}" "${_dataset}"
            jexec -l -U root "${_jail}" zfs mount "${_dataset}" 2>/dev/null
        done < "${bastille_jailsdir}/${_jail}/zfs.conf"
    fi

    # Add rctl limits
    if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
        while read _limits; do
            rctl -a "${_limits}"
        done < "${bastille_jailsdir}/${_jail}/rctl.conf"
    fi

    # Add cpuset limits
    if [ -s "${bastille_jailsdir}/${_jail}/cpuset.conf" ]; then
        while read _limits; do
            cpuset -l "${_limits}" -j "${_jail}"
        done < "${bastille_jailsdir}/${_jail}/cpuset.conf"
    fi

    # Add rdr rules
    if [ -s "${bastille_jailsdir}/${_jail}/rdr.conf" ]; then
        while read _rules; do
            eval "bastille rdr ${_jail} ${_rules}"
        done < "${bastille_jailsdir}/${_jail}/rdr.conf"
    fi

    # Delay between jail action
    sleep "${DELAY_TIME}"

done
