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
    error_exit "Usage: bastille hosts TARGET"
}

ipv6_err() {
    error_exit "Only support IPv4"
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

for _jail in ${JAILS}; do
        ## ipv6 check
        if [ "$(bastille config ${_jail} get vnet)" = 'enabled' ]; then
                IP6ADDR=$(jexec -l ${_jail} ifconfig -n vnet0 inet6 | awk '/inet6 / && (!/fe80::/ || !/%vnet0/)' | sed -n "/.inet6 /{s///;s/ .*//;p;}")
                if [ -n "${IP6ADDR}" ]; then
                	ipv6_err
                else
                	IP4ADDR=$(jexec -l ${_jail} ifconfig -n vnet0 inet | sed -n "/.inet /{s///;s/ .*//;p;}")
                fi
        elif [ "$(bastille config ${_jail} get ip6)" = 'new' ]; then
                ipv6_err
        else
                IP4ADDR=$(bastille config ${_jail} get ip4.addr)
        fi
        
        HOSTNAME=$(bastille config ${_jail} get host.hostname)
        HOSTSFILE="${bastille_jailsdir}/${_jail}/root/etc/hosts"
        EXISTINGENTRY=$(grep '^10\|^172\|^192' "${HOSTSFILE}")
        UPDATEENTRY="${IP4ADDR} ${HOSTNAME}"

        if [ -z "${EXISTINGENTRY}" ]; then
                sed -i '' "15s/^.*/${UPDATEENTRY}/" "${HOSTSFILE}"
        else
                sed -i '' "15s/^10.*/${UPDATEENTRY}/; 15s/^172.*/${UPDATEENTRY}/; 15s/^192.*/${UPDATEENTRY}/" "${HOSTSFILE}"
        fi
done
