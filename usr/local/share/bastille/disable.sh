#!/bin/sh
#
# Copyright (c) 2018-2021, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille disable TARGET"
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

# Gather bastille list info(sysrc targets /etc/rc.conf by default).
# Default bastille rc vars are bastille_enable and bastille_list.
BASTILLE_DISABLE_STAT=$(sysrc -qn bastille_enable)
BASILLE_LIST_CURRENT=$(sysrc -qn bastille_list)
BASTILLE_LIST_TARGET=$(sysrc -qn bastille_list | tr -s " " "\n" | awk "/^${TARGET}$/")

bastille_disable_check(){
    # Check bastille disable status.
    if [ "${BASTILLE_DISABLE_STAT}" != "NO" ]; then
        sysrc bastille_enable="NO"
    fi
}

if [ "${TARGET}" = 'ALL' ]; then
    if [ -n "${BASILLE_LIST_CURRENT}" ]; then
        # Clear current startup list.
        info "Disabling all jails..."
        sysrc bastille_list=
        info "All jails disabled."
    elif [ -z "${BASILLE_LIST_CURRENT}" ]; then
        error_exit "All jails already disabled."
    fi
    bastille_disable_check
fi

if [ "${TARGET}" != 'ALL' ]; then
    # Check if jail exist.
    if [ ! -d "${bastille_jailsdir}/${TARGET}" ]; then
        error_exit "[${TARGET}]: Not found."
    fi

    # Check if jail is already disabled.
    if [ -z "${BASTILLE_LIST_TARGET}" ]; then
        error_exit "${TARGET} already disabled"
    fi

    # Disable the jail.
    info "Disabling ${TARGET}..."
    sysrc bastille_list-="${TARGET}"
    info "${TARGET} disabled."
fi
