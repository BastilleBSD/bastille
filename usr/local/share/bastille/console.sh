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
    error_exit "Usage: bastille console TARGET [user]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 1 ]; then
    usage
fi

bastille_root_check

USER="${1}"

validate_user() {
    if jexec -l "${_jail}" id "${USER}" >/dev/null 2>&1; then
        USER_SHELL="$(jexec -l "${_jail}" getent passwd "${USER}" | cut -d: -f7)"
        if [ -n "${USER_SHELL}" ]; then
            if jexec -l "${_jail}" grep -qwF "${USER_SHELL}" /etc/shells; then
                jexec -l "${_jail}" $LOGIN -f "${USER}"
            else
                echo "Invalid shell for user ${USER}"
            fi
        else
            echo "User ${USER} has no shell"
        fi
    else
        echo "Unknown user ${USER}"
    fi
}

check_fib() {
    fib=$(grep 'exec.fib' "${bastille_jailsdir}/${_jail}/jail.conf" | awk '{print $3}' | sed 's/\;//g')
        if [ -n "${fib}" ]; then
            _setfib="setfib -F ${fib}"
        else
            _setfib=""
        fi
}

for _jail in ${JAILS}; do
    info "[${_jail}]:"
    LOGIN="$(jexec -l "${_jail}" which login)"
    if [ -n "${USER}" ]; then
        validate_user
    else
        LOGIN="$(jexec -l "${_jail}" which login)"
        ${_setfib} jexec -l "${_jail}" $LOGIN -f root
    fi
    echo
done
