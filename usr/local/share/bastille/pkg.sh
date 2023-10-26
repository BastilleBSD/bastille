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

usage() {
    error_exit "Usage: bastille pkg [-H|--host] TARGET command [args]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -lt 1 ]; then
    usage
fi

bastille_root_check

errors=0

for _jail in ${JAILS}; do
    info "[${_jail}]:"
    bastille_jail_path=$(/usr/sbin/jls -j "${_jail}" path)
    if [ -f "/usr/sbin/mport" ]; then
        if ! jexec -l -U root "${_jail}" /usr/sbin/mport "$@"; then
            errors=1
        fi
    elif [ -f "${bastille_jail_path}/usr/bin/apt" ]; then
        if ! jexec -l "${_jail}" /usr/bin/apt "$@"; then
            errors=1
        fi
    elif [ "${USE_HOST_PKG}" = 1 ]; then
        if ! /usr/sbin/pkg -j "${_jail}" "$@"; then
            errors=1
        fi
    else
        if ! jexec -l -U root "${_jail}" /usr/sbin/pkg "$@"; then
            errors=1
        fi
    fi
    echo
done

if [ $errors -ne 0 ]; then
    error_exit "Failed to apply on some jails, please check logs"
    exit 1
fi
