#!/bin/sh
# 
# Copyright (c) 2018-2019, Christer Edwards <christer.edwards@gmail.com>
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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille start TARGET${COLOR_RESET}"
    exit 1
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

TARGET="${1}"
shift

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(bastille list jails)
fi
if [ "${TARGET}" != 'ALL' ]; then
    JAILS=$(bastille list jails | awk "/^${TARGET}$/")
fi

for _jail in ${JAILS}; do
    ## test if running
    if [ "$(jls name | awk "/^${_jail}$/")" ]; then
        echo -e "${COLOR_RED}[${_jail}]: Already started.${COLOR_RESET}"

    ## test if not running
    elif [ ! "$(jls name | awk "/^${_jail}$/")" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
        jail -f "${bastille_jailsdir}/${_jail}/jail.conf" -c ${_jail}

        ## add ip4.addr to firewall table:jails
        if [ ! -z "${bastille_jail_loopback}" ]; then
            pfctl -q -t jails -T add $(jls -j ${_jail} ip4.addr)
        fi
    fi
    echo
done
