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
    error_exit "Usage: bastille list [-j][-a] [release|template|(jail|container)|log|limit|(import|export|backup)]"
}

if [ $# -eq 0 ]; then
   jls -N
fi

if [ "$1" == "-j" ]; then
    jls -N --libxo json
    exit 0
fi

if [ $# -gt 0 ]; then
    # Handle special-case commands first.
    case "$1" in
    help|-h|--help)
        usage
        ;;
    all|-a|--all)
        if [ -d "${bastille_jailsdir}" ]; then
            DEFAULT_VALUE="-"
            SPACER=4
            MAX_LENGTH_JAIL_NAME=$(find "${bastille_jailsdir}" -maxdepth 2 -type f -name jail.conf | sed "s/^.*\/\(.*\)\/jail.conf$/\1/" | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_NAME=${MAX_LENGTH_JAIL_NAME:-3}
            if [ ${MAX_LENGTH_JAIL_NAME} -lt 3 ]; then MAX_LENGTH_JAIL_NAME=3; fi
            MAX_LENGTH_JAIL_IP=$(find "${bastille_jailsdir}" -maxdepth 2 -type f -name jail.conf -exec sed -n "s/^[ ]*ip4.addr[ ]*=[ ]*\(.*\);$/\1/p" {} \; | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_IP=${MAX_LENGTH_JAIL_IP:-10}
            if [ ${MAX_LENGTH_JAIL_IP} -lt 10 ]; then MAX_LENGTH_JAIL_IP=10; fi
            MAX_LENGTH_JAIL_HOSTNAME=$(find "${bastille_jailsdir}" -maxdepth 2 -type f -name jail.conf -exec sed -n "s/^[ ]*host.hostname[ ]*=[ ]*\(.*\);$/\1/p" {} \; | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_HOSTNAME=${MAX_LENGTH_JAIL_HOSTNAME:-8}
            if [ ${MAX_LENGTH_JAIL_HOSTNAME} -lt 8 ]; then MAX_LENGTH_JAIL_HOSTNAME=8; fi
            MAX_LENGTH_JAIL_PORTS=$(find "${bastille_jailsdir}" -maxdepth 2 -type f -name rdr.conf -exec awk '{ lines++; chars += length($0)} END { chars += lines - 1; print chars }' {} \; | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_PORTS=${MAX_LENGTH_JAIL_PORTS:-15}
            if [ ${MAX_LENGTH_JAIL_PORTS} -lt 15 ]; then MAX_LENGTH_JAIL_PORTS=15; fi
            if [ ${MAX_LENGTH_JAIL_PORTS} -gt 30 ]; then MAX_LENGTH_JAIL_PORTS=30; fi
            MAX_LENGTH_JAIL_RELEASE=$(find "${bastille_jailsdir}" -maxdepth 2 -type f -name fstab -exec sed "s/^.*releases\/\(.*\) \/.*$/\1/" {} \; | awk '{ print length($0) }' | sort -nr | head -n 1)
            MAX_LENGTH_JAIL_RELEASE=${MAX_LENGTH_JAIL_RELEASE:-7}
            if [ ${MAX_LENGTH_JAIL_RELEASE} -lt 7 ]; then MAX_LENGTH_JAIL_RELEASE=7; fi
            printf " JID%*sState%*sIP Address%*sPublished Ports%*sHostname%*sRelease%*sPath\n" "$((${MAX_LENGTH_JAIL_NAME} + ${SPACER} - 3))" "" "$((${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} + ${SPACER} - 10))" "" "$((${MAX_LENGTH_JAIL_PORTS} + ${SPACER} - 15))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} + ${SPACER} - 8))" "" "$((${MAX_LENGTH_JAIL_RELEASE} + ${SPACER} - 7))" ""
            JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
            for _JAIL in ${JAIL_LIST}; do
                if [ -f "${bastille_jailsdir}/${_JAIL}/jail.conf" ]; then
                        if [ "$(jls name | awk "/^${_JAIL}$/")" ]; then
                                JAIL_STATE="Up"
                                JAIL_IP=$(jls -j ${_JAIL} ip4.addr 2> /dev/null)
                                JAIL_HOSTNAME=$(jls -j ${_JAIL} host.hostname 2> /dev/null)
                                JAIL_PORTS=$(pfctl -a "rdr/${_JAIL}" -Psn 2> /dev/null | awk '{ printf "%s/%s:%s"",",$7,$14,$18 }' | sed "s/,$//")
                                JAIL_PATH=$(jls -j ${_JAIL} path 2> /dev/null)
                        else
                                JAIL_STATE=$(if [ "$(sed -n "/^${_JAIL} {$/,/^}$/p" "${bastille_jailsdir}/${_JAIL}/jail.conf" | awk '$0 ~ /^'${_JAIL}' \{|\}/ { printf "%s",$0 }')" == "${_JAIL} {}" ]; then echo "Down"; else echo "n/a"; fi)
                                JAIL_IP=$(sed -n "s/^[ ]*ip4.addr[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${_JAIL}/jail.conf")
                                JAIL_HOSTNAME=$(sed -n "s/^[ ]*host.hostname[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${_JAIL}/jail.conf")
                                if [ -f "${bastille_jailsdir}/${_JAIL}/rdr.conf" ]; then JAIL_PORTS=$(awk '$1 ~ /^[tcp|udp]/ { printf "%s/%s:%s,",$1,$2,$3 }' "${bastille_jailsdir}/${_JAIL}/rdr.conf" | sed "s/,$//"); else JAIL_PORTS=""; fi
                                JAIL_PATH=$(sed -n "s/^[ ]*path[ ]*=[ ]*\(.*\);$/\1/p" "${bastille_jailsdir}/${_JAIL}/jail.conf")
                        fi
                        if [ ${#JAIL_PORTS} -gt ${MAX_LENGTH_JAIL_PORTS} ]; then JAIL_PORTS="$(echo ${JAIL_PORTS} | cut -c-$((${MAX_LENGTH_JAIL_PORTS} - 3)))..."; fi
                        if [ -f "${bastille_jailsdir}/${_JAIL}/fstab" ]; then JAIL_RELEASE=$(sed "s/^.*releases\/\(.*\) \/.*$/\1/" "${bastille_jailsdir}/${_JAIL}/fstab"); else JAIL_RELEASE=""; fi
                        JAIL_NAME=${JAIL_NAME:-${DEFAULT_VALUE}}
                        JAIL_STATE=${JAIL_STATE:-${DEFAULT_VALUE}}
                        JAIL_IP=${JAIL_IP:-${DEFAULT_VALUE}}
                        JAIL_PORTS=${JAIL_PORTS:-${DEFAULT_VALUE}}
                        JAIL_HOSTNAME=${JAIL_HOSTNAME:-${DEFAULT_VALUE}}
                        JAIL_RELEASE=${JAIL_RELEASE:-${DEFAULT_VALUE}}
                        JAIL_PATH=${JAIL_PATH:-${DEFAULT_VALUE}}
                        printf " ${_JAIL}%*s${JAIL_STATE}%*s${JAIL_IP}%*s${JAIL_PORTS}%*s${JAIL_HOSTNAME}%*s${JAIL_RELEASE}%*s${JAIL_PATH}\n" "$((${MAX_LENGTH_JAIL_NAME} - ${#_JAIL} + ${SPACER}))" "" "$((5 - ${#JAIL_STATE} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_IP} - ${#JAIL_IP} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_PORTS} - ${#JAIL_PORTS} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_HOSTNAME} - ${#JAIL_HOSTNAME} + ${SPACER}))" "" "$((${MAX_LENGTH_JAIL_RELEASE} - ${#JAIL_RELEASE} + ${SPACER}))" ""
                fi
            done
        fi
        ;;
    release|releases)
        if [ -d "${bastille_releasesdir}" ]; then
            REL_LIST=$(ls "${bastille_releasesdir}" | sed "s/\n//g")
            for _REL in ${REL_LIST}; do
                if [ -f "${bastille_releasesdir}/${_REL}/root/.profile" ]; then
                    echo "${_REL}"
                fi
            done
        fi
        ;;
    template|templates)
        find "${bastille_templatesdir}" -type d -maxdepth 2
        ;;
    jail|jails|container|containers)
        if [ -d "${bastille_jailsdir}" ]; then
            JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
            for _JAIL in ${JAIL_LIST}; do
                if [ -f "${bastille_jailsdir}/${_JAIL}/jail.conf" ]; then
                    echo "${_JAIL}"
                fi
            done
        fi
        ;;
    log|logs)
        find "${bastille_logsdir}" -type f -maxdepth 1
        ;;
    limit|limits)
        rctl -h jail:
        ;;
    import|imports|export|exports|backup|backups)
        ls "${bastille_backupsdir}" | grep -Ev "*.sha256"
    exit 0
    ;;
    *)
        usage
        ;;
    esac
fi
