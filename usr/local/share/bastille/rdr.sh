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
    error_exit "Usage: bastille rdr TARGET [clear|list|(tcp|udp host_port jail_port)]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -lt 2 ]; then
    usage
fi

TARGET="${1}"
shift

# Can only redirect to single jail
if [ "${TARGET}" = 'ALL' ]; then
    error_exit "Can only redirect to a single jail."
fi

# Check if jail name is valid
JAIL_NAME=$(jls -j "${TARGET}" name 2>/dev/null)
if [ -z "${JAIL_NAME}" ]; then
    error_exit "Jail not found: ${TARGET}"
fi

# The rdr feature is non-VNET only
if [ "$(bastille config $TARGET get vnet)" = 'enabled' ]; then
    error_exit "The rdr feature is for non-VNET jails only"
fi

JAIL_IP=$(jls -j "${TARGET}" ip4.addr 2>/dev/null)
JAIL_IP6=$(jls -j "${TARGET}" ip6.addr 2>/dev/null)
# Check if the jail has either a valid ip4.addr or a valid ip6.addr (or both)
if [ \( -z "${JAIL_IP}" -o "${JAIL_IP}" = "-" \) -a \( -z "${JAIL_IP6}" -o "${JAIL_IP6}" = "-" \) ]; then
    error_exit "Jail IP not found: ${TARGET}"
fi

# Check if rdr-anchor is defined in pf.conf
if ! (pfctl -sn | grep rdr-anchor | grep 'rdr/\*' >/dev/null); then
    error_exit "rdr-anchor not found in pf.conf"
fi

# Check if ext_if is defined in pf.conf
EXT_IF=$(grep '^[[:space:]]*ext_if[[:space:]]*=' /etc/pf.conf)
if [ -z "${EXT_IF}" ]; then
    error_exit "ext_if not defined in pf.conf"
fi

# function: write rule to rdr.conf
persist_rdr_rule() {
if ! grep -qs "$1 $2 $3" "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"; then
    echo "$1 $2 $3" >> "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"
fi
}

# function: load rdr rule via pfctl
load_rdr_rule() {
    (   pfctl -a "rdr/${JAIL_NAME}" -Psn;
        printf '%s\n' "${EXT_IF}"
        if [ -n "${JAIL_IP}" -a "${JAIL_IP}" != "-" ]; then
            printf 'rdr pass on $ext_if inet proto %s to port %s -> %s port %s\n' "$1" "$2" "$JAIL_IP" "$3"
        fi
        if [ -n "${JAIL_IP6}" -a "${JAIL_IP6}" != "-" ]; then
            printf 'rdr pass on $ext_if inet6 proto %s to port %s -> %s port %s\n' "$1" "$2" "$JAIL_IP6" "$3"
        fi
    ) | pfctl -a "rdr/${JAIL_NAME}" -f-
}

while [ $# -gt 0 ]; do
    case "$1" in
        list)
            pfctl -a "rdr/${JAIL_NAME}" -Psn 2>/dev/null
            shift
            ;;
        clear)
            pfctl -a "rdr/${JAIL_NAME}" -Fn
            shift
            ;;
        tcp|udp)
            if [ $# -lt 3 ]; then
                usage
            fi
            persist_rdr_rule $1 $2 $3
            load_rdr_rule $1 $2 $3
            shift 3
            ;;
        *)
            usage
            ;;
    esac
done
