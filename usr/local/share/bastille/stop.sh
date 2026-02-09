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

    -v | --verbose     Enable verbose mode.
    -x | --debug       Enable debug mode.

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
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
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
set_target "${TARGET}" "reverse"

for jail in ${JAILS}; do

    # Validate that all jails that 'depend' on this one are stopped
    for depend_jail in $(ls -v --color=never ${bastille_jailsdir} | sed -e 's/\n//g'); do
    if ! grep -hoqsw "depend=" ${bastille_jailsdir}/${depend_jail}/settings.conf; then
        sysrc -q -f ${bastille_jailsdir}/${depend_jail}/settings.conf depend="" >/dev/null
    fi
        if [ "${jail}" = "${depend_jail}" ]; then
            continue
        elif grep -hoqsw "${jail}" "${bastille_jailsdir}/${depend_jail}/settings.conf"; then
            bastille stop ${depend_jail}
        fi
    done

    if check_target_is_stopped "${jail}"; then
        info 1 "\n[${jail}]:"
        error_continue "Jail is already stopped."
    fi

    info 1 "\n[${jail}]:"

    # Remove RDR rules
    if [ "$(bastille config ${jail} get vnet)" != "enabled" ] && [ -f "${bastille_pf_conf}" ]; then
        ip4="$(bastille config ${jail} get ip4.addr | sed 's/,/ /g')"
        ip6="$(bastille config ${jail} get ip6.addr | sed 's/,/ /g')"
        if [ "${ip4}" != "not set" ] || [ "${ip6}" != "not set" ]; then
            if which -s pfctl; then
                if bastille rdr ${jail} list >/dev/null 2>&1; then
                    bastille rdr "${jail}" clear
                fi
            fi
        fi
    fi

    # Remove rctl limits
    if [ -s "${bastille_jailsdir}/${jail}/rctl.conf" ]; then
        bastille limits "${jail}" clear
    fi

    # Stop jail
    jail ${OPTION} -f "${bastille_jailsdir}/${jail}/jail.conf" -r "${jail}"

    # Remove (captured above) IPs from firewall table
    if [ "${ip4}" != "not set" ] && [ -f "${bastille_pf_conf}" ]; then
        for ip in ${ip4}; do
            if echo "${ip}" | grep -q "|"; then
                ip="$(echo ${ip} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
            else
                ip="$(echo ${ip} | sed -E 's#/[0-9]+$##g')"
            fi
            pfctl -q -t "${bastille_network_pf_table}" -T delete "${ip}"
        done
    fi
    if [ "${ip6}" != "not set" ] && [ -f "${bastille_pf_conf}" ]; then
        for ip in ${ip6}; do
            if echo "${ip}" | grep -q "|"; then
                ip="$(echo ${ip} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
            else
                ip="$(echo ${ip} | sed -E 's#/[0-9]+$##g')"
            fi
            pfctl -q -t "${bastille_network_pf_table}" -T delete "${ip}"
        done
    fi

    update_jail_syntax_v1 "${jail}"

done
