#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
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

usage() {
    echo -e "${COLOR_RED}Usage: bastille console TARGET [user]'.${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 2 ] || [ $# -lt 1 ]; then
    usage
fi

TARGET="${1}"
shift
USER="${1}"

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(jls name)
fi
if [ "${TARGET}" != 'ALL' ]; then
    JAILS=$(jls name | awk "/^${TARGET}$/")
fi

validate_user() {
    if jexec -l "${_jail}" id "${USER}" >/dev/null 2>&1; then
        USER_SHELL="$(jexec -l "${_jail}" getent passwd "${USER}" | cut -d: -f7)"
        if [ -n "${USER_SHELL}" ]; then
            if jexec -l "${_jail}" grep -qwF "${USER_SHELL}" /etc/shells; then
                jexec -l "${_jail}" /usr/bin/login -f "${USER}"
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

for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
    if [ -n "${USER}" ]; then
        validate_user
    else
        jexec -l "${_jail}" /usr/bin/login -f root
    fi
    echo
done
