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
    error_notify "Usage: bastille stop [option(s)] TARGET"
    cat << EOF
    Options:

    -v | --verbose           Print every action on jail stop.
    -x | --debug             Enable debug mode.

EOF
    exit 1
}

# Handle options.
OPTION=""
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
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
                    v) OPTION="-v" ;;
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

if [ "$#" -ne 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do

    info "[${_jail}]:"
    check_target_is_running "${_jail}" || error_continue "Jail is already stopped."

    # Remove RDR rules
    if [ "$(bastille config ${_jail} get vnet)" != "enabled" ] && [ -f "${bastille_pf_conf}" ]; then
        _ip4="$(bastille config ${_jail} get ip4.addr | sed 's/,/ /g')"
        _ip6="$(bastille config ${_jail} get ip6.addr | sed 's/,/ /g')"
        if [ "${_ip4}" != "not set" ] || [ "${_ip6}" != "not set" ]; then
            if which -s pfctl; then
                if [ "$(bastille rdr ${_jail} list)" ]; then
                    bastille rdr "${_jail}" clear
                fi
            fi
        fi
    fi

    # Remove rctl limits
    if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
        while read _limits; do
            rctl -r "${_limits}"
        done < "${bastille_jailsdir}/${_jail}/rctl.conf"
    fi

    # Stop jail
    jail ${OPTION} -f "${bastille_jailsdir}/${_jail}/jail.conf" -r "${_jail}"

    # Remove (captured above) IPs from firewall table
    if [ "${_ip4}" != "not set" ] && [ -f "${bastille_pf_conf}" ]; then
        for _ip in ${_ip4}; do
            if echo "${_ip}" | grep -q "|"; then
                _ip="$(echo ${_ip} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
            else
                _ip="$(echo ${_ip} | sed -E 's#/[0-9]+$##g')"
            fi
            pfctl -q -t "${bastille_network_pf_table}" -T delete "${_ip}"
        done
    fi
    if [ "${_ip6}" != "not set" ] && [ -f "${bastille_pf_conf}" ]; then
        for _ip in ${_ip6}; do
            if echo "${_ip}" | grep -q "|"; then
                _ip="$(echo ${_ip} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
            else
                _ip="$(echo ${_ip} | sed -E 's#/[0-9]+$##g')"
            fi
            pfctl -q -t "${bastille_network_pf_table}" -T delete "${_ip}" 
        done
    fi
done
