#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_notify "Usage: bastille limits TARGET option value"
    echo -e "Example: bastille limits JAILNAME memoryuse 1G"
    exit 1
}

RACCT_ENABLE=$(sysctl -n kern.racct.enable)
if [ "${RACCT_ENABLE}" != '1' ]; then
    echo "Racct not enabled. Append 'kern.racct.enable=1' to /boot/loader.conf and reboot"
#    exit 1
fi

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -lt 3 ]; then
    usage
fi

TARGET="${1}"
OPTION="${2}"
VALUE="${3}"
shift

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(jls name)
fi

if [ "${TARGET}" != 'ALL' ]; then
    JAILS=$(jls name | awk "/^${TARGET}$/")
fi

for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"

    _rctl_rule="jail:${_jail}:${OPTION}:deny=${VALUE}/jail"

    ## if entry doesn't exist, add; else show existing entry
    if ! grep -qs "${_rctl_rule}" "${bastille_jailsdir}/${_jail}/rctl.conf"; then
        echo "${_rctl_rule}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
    fi

    echo -e "${OPTION} ${VALUE}"
    rctl -a "${_rctl_rule}"
    echo -e "${COLOR_RESET}"
done
