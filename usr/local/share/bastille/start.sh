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
    error_exit "Usage: bastille start TARGET"
}

# Handle special-case commands first.
case "${1}" in
    help|-h|--help)
        usage
        ;;
esac

if [ "$#" -ne 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do

    info "[${_jail}]:"        
    check_target_is_stopped "${_jail}" || error_continue "Jail is already running."

    # Validate interfaces
    if [ "$(bastille config ${_jail} get vnet)" != 'enabled' ]; then
        _ip4_interfaces="$(bastille config ${_jail} get ip4.addr | sed 's/,/ /g')"
        _ip6_interfaces="$(bastille config ${_jail} get ip6.addr | sed 's/,/ /g')"
        # IP4
        if [ "${_ip4_interfaces}" != "not set" ]; then
            for _interface in ${_ip4_interfaces}; do
                _interface="$(echo ${_interface} 2>/dev/null | awk -F"|" '{print $1}')"
                if ! ifconfig | grep "^${_interface}:" >/dev/null; then
                    error_notify "Error: ${_interface} interface does not exist."
                    continue
                fi
            done
        fi
        # IP6
        if [ "${_ip6_interfaces}" != "not set" ]; then
            for _interface in ${_ip6_interfaces}; do
                _interface="$(echo ${_interface} 2>/dev/null | awk -F"|" '{print $1}')"
                if ! ifconfig | grep "^${_interface}:" >/dev/null; then
                    error_notify "Error: ${_interface} interface does not exist."
                    continue
                fi
            done
        fi
    fi

    # Validate and/or add IP to firewall table (in use or not in use)
    _ip4="$(bastille config "${_jail}" get ip4.addr | sed 's/,/ /g')"
    _ip6="$(bastille config "${_jail}" get ip6.addr | sed 's/,/ /g')"
    # IP4
    if [ "${_ip4}" != "not set" ]; then
        for _ip in ${_ip4}; do
            _ip="$(echo ${_ip} 2>/dev/null | awk -F"|" '{print $2}')"
            if ifconfig | grep -wF "${_ip}" >/dev/null; then
                error_notify "Error: IP address (${_ip}) already in use."
                continue
            else
                pfctl -q -t "${bastille_network_pf_table}" -T add "${_ip}"
            fi
        done
    fi
    # IP6
    if [ "${_ip6}" != "not set" ]; then
        for _ip in ${_ip6}; do
            _ip="$(echo ${_ip} 2>/dev/null | awk -F"|" '{print $2}')"
            if ifconfig | grep -wF "${_ip}" >/dev/null; then
                error_notify "Error: IP address (${_ip}) already in use."
                continue
            else
                pfctl -q -t "${bastille_network_pf_table}" -T add "${_ip}"
            fi
        done
    fi

    # Start jail
    jail -f "${bastille_jailsdir}/${_jail}/jail.conf" -c "${_jail}"

    # Add rctl limits
    if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
        while read _limits; do
            rctl -a "${_limits}"
        done < "${bastille_jailsdir}/${_jail}/rctl.conf"
    fi

    # Add rdr rules
    if [ -s "${bastille_jailsdir}/${_jail}/rdr.conf" ]; then
        while read _rules; do
            bastille rdr ${_jail} ${_rules}
        done < "${bastille_jailsdir}/${_jail}/rdr.conf"
    fi
done
