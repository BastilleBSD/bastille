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
    error_exit "Usage: bastille enable TARGET"
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
BASTILLE_LIST_CURRENT=$(sysrc -qn bastille_list)
BASTILLE_LIST_TARGET=$(sysrc -qn bastille_list | tr -s " " "\n" | awk "/^${TARGET}$/")

bastille_enable_check(){
    # Check bastille enable status.
    BASTILLE_ENABLE_STAT=$(sysrc -qn bastille_enable)
    if [ "${BASTILLE_ENABLE_STAT}" != "YES" ]; then
        sysrc bastille_enable="YES"
    fi
}

if [ "${TARGET}" = 'ALL' ]; then
    if [ -n "${BASTILLE_LIST_CURRENT}" ]; then
        # Clear current list to re-apply default jail startup list.
        info "Clearing current startup list..."
        sysrc bastille_list=
    fi

    info "Enabling all jails..."
    bastille_enable_check
    BASTILLE_LIST_ALL=$(echo $(bastille list jails))
    sysrc bastille_list="${BASTILLE_LIST_ALL}"
    info "All jails enabled."
fi

if [ "${TARGET}" != 'ALL' ]; then
    # Check if jail exist.
    if [ ! -d "${bastille_jailsdir}/${TARGET}" ]; then
        error_exit "[${TARGET}]: Not found."
    fi

    # Check if jail is already enabled.
    if [ -n "${BASTILLE_LIST_TARGET}" ]; then
        error_exit "${TARGET} already enabled"
    fi

    # Enable the jail.
    info "Enabling ${TARGET}..."
    bastille_enable_check
    sysrc bastille_list+="${TARGET}"
    info "${TARGET} enabled."
fi
