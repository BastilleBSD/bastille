#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

bastille_root_check

TARGET="${1}"
shift

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(bastille list jails)
fi
if [ "${TARGET}" != 'ALL' ]; then
    JAILS=$(bastille list jails | awk "/^${TARGET}$/")
    ## check if exist
    if [ ! -d "${bastille_jailsdir}/${TARGET}" ]; then
        error_exit "[${TARGET}]: Not found."
    fi
fi

for _jail in ${JAILS}; do
    ## test if running
    if [ "$(/usr/sbin/jls name | awk "/^${_jail}$/")" ]; then
        error_notify "[${_jail}]: Already started."

    ## test if not running
    elif [ ! "$(/usr/sbin/jls name | awk "/^${_jail}$/")" ]; then
        # Verify that the configured interface exists. -- cwells
        if [ "$(bastille config $_jail get vnet)" != 'enabled' ]; then
            _interface=$(bastille config $_jail get interface)
            if ! ifconfig | grep "^${_interface}:" >/dev/null; then
                error_notify "Error: ${_interface} interface does not exist."
                continue
            fi
        fi

        ## warn if matching configured (but not online) ip4.addr, ignore if there's no ip4.addr entry
        ip=$(bastille config "${_jail}" get ip4.addr)
        if [ -n "${ip}" ]; then
            if ifconfig | grep -wF "${ip}" >/dev/null; then
                error_notify "Error: IP address (${ip}) already in use."
                continue
            fi
            ## add ip4.addr to firewall table
            pfctl -q -t "${bastille_network_pf_table}" -T add "${ip}"
        fi

        ## start the container
        info "[${_jail}]:"
        jail -f "${bastille_jailsdir}/${_jail}/jail.conf" -c "${_jail}"

        ## add rctl limits
        if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
            while read _limits; do
                rctl -a "${_limits}"
            done < "${bastille_jailsdir}/${_jail}/rctl.conf"
        fi

        ## add rdr rules
        if [ -s "${bastille_jailsdir}/${_jail}/rdr.conf" ]; then
            while read _rules; do
                bastille rdr "${_jail}" ${_rules}
            done < "${bastille_jailsdir}/${_jail}/rdr.conf"
        fi
    fi
    echo
done
