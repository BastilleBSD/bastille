#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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

if [ $# -ne 2 ]; then
    usage
fi

bastille_root_check

OPTION="${1}"
VALUE="${2}"

for _jail in ${JAILS}; do
    info "[${_jail}]:"

    _rctl_rule="jail:${_jail}:${OPTION}:deny=${VALUE}/jail"
    _rctl_rule_log="jail:${_jail}:${OPTION}:log=${VALUE}/jail"

    # Check whether the entry already exists and, if so, update it. -- cwells
    if grep -qs "jail:${_jail}:${OPTION}:deny" "${bastille_jailsdir}/${_jail}/rctl.conf"; then
    	_escaped_option=$(echo "${OPTION}" | sed 's/\//\\\//g')
    	_escaped_rctl_rule=$(echo "${_rctl_rule}" | sed 's/\//\\\//g')
        sed -i '' -E "s/jail:${_jail}:${_escaped_option}:deny.+/${_escaped_rctl_rule}/" "${bastille_jailsdir}/${_jail}/rctl.conf"
    else # Just append the entry. -- cwells
        echo "${_rctl_rule}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
        echo "${_rctl_rule_log}" >> "${bastille_jailsdir}/${_jail}/rctl.conf"
    fi

    echo -e "${OPTION} ${VALUE}"
    rctl -a "${_rctl_rule}" "${_rctl_rule_log}"
    echo -e "${COLOR_RESET}"
done
