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
    error_exit "Usage: bastille stop TARGET"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -ne 0 ]; then
    usage
fi

bastille_root_check

for _jail in ${JAILS}; do
    ## test if running
    if [ "$(/usr/sbin/jls name | awk "/^${_jail}$/")" ]; then
        ## Capture ip4.addr address while still running
        _ip="$(/usr/sbin/jls -j ${_jail} ip4.addr)"

        # Check if pfctl is present
        if which -s pfctl; then
            if [ "$(bastille rdr ${_jail} list)" ]; then
                bastille rdr ${_jail} clear
            fi
        fi

        ## remove rctl limits
        if [ -s "${bastille_jailsdir}/${_jail}/rctl.conf" ]; then
            while read _limits; do
                rctl -r "${_limits}"
            done < "${bastille_jailsdir}/${_jail}/rctl.conf"
        fi

        ## stop container
        info "[${_jail}]:"
        jail -f "${bastille_jailsdir}/${_jail}/jail.conf" -r "${_jail}"

        ## remove (captured above) ip4.addr from firewall table
        if [ -n "${bastille_network_loopback}" -a ! -z "${_ip}" ]; then
            if grep -qw "interface.*=.*${bastille_network_loopback}" "${bastille_jailsdir}/${_jail}/jail.conf"; then
                pfctl -q -t "${bastille_network_pf_table}" -T delete "${_ip}"
            fi
        fi
    fi
    echo
done
