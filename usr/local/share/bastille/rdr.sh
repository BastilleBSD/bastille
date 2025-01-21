#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille rdr [option(s)] TARGET [clear|reset|list|(tcp|udp)] HOST_PORT JAIL_PORT [log ['(' logopts ')'] ]"
    cat << EOF
    Options:

    -d | --destination [destination ip]          Limit rdr to a destination IP. Useful if you have multiple IPs on one interface.
    -i | --interface   [interface]               Set the interface to create the rdr rule on. Useful if you have multiple interfaces.
    -s | --source      [source ip]               Limit rdr to a source IP. Useful to only allow access from a certian IP or subnet.
    -t | --type        [ipv4|ipv6]               Specify IP type. Must be used if -s or -d are used. Defaults to both.
    -x | --debug                                 Enable debug mode.

EOF
    exit 1
}

check_jail_validity() {
    # Validate jail network type and set IP4/6
    if [ "$( bastille config ${TARGET} get vnet )" != 'enabled' ]; then
        _ip4_interfaces="$(bastille config ${TARGET} get ip4.addr | sed 's/,/ /g')"
        _ip6_interfaces="$(bastille config ${TARGET} get ip6.addr | sed 's/,/ /g')"
        # Check if jail ip4.addr is valid (non-VNET only)
        if [ "${_ip4_interfaces}" != "not set" ] && [ "${_ip4_interfaces}" != "disable" ]; then
            if echo "&{_ip4_interfaces}" | grep -q "|"; then
                JAIL_IP="$(echo ${_ip4_interfaces} | awk '{print $1}' | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
            else
                JAIL_IP="$(echo ${_ip4_interfaces} | sed -E 's#/[0-9]+$##g')"
            fi
        fi
        # Check if jail ip6.addr is valid (non-VNET only)
        if [ "${_ip6_interfaces}" != "not set" ] && [ "${_ip6_interfaces}" != "disable" ]; then
            if echo "&{_ip6_interfaces}" | grep -q "|"; then
                JAIL_IP6="$(echo ${_ip6_interfaces} | awk '{print $1}' | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
            else
                JAIL_IP6="$(echo ${_ip6_interfaces} | sed -E 's#/[0-9]+$##g')"
            fi
        fi
    else
        error_exit "VNET jails do not support rdr."
    fi
    
    # Check if rdr-anchor is defined in pf.conf
    if ! (pfctl -sn | grep rdr-anchor | grep 'rdr/\*' >/dev/null); then
        error_exit "rdr-anchor not found in pf.conf"
    fi
}

check_rdr_ip_validity() {
    local ip="${1}"
    local ip6="$( echo "${ip}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)' )"
    if [ -n "${ip6}" ]; then
        info "Valid: (${ip6})."
    else
        local IFS
        if echo "${ip}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${ip}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "Invalid: (${TEST_IP})"
                fi
            done
            info "Valid: (${ip})."
        else
            error_exit "Invalid: (${ip})."
        fi
    fi
}

validate_rdr_rule() {
    local if="${1}"
    local src="${2}"
    local dst="${3}"
    local proto="${4}"
    local host_port="${5}"
    local jail_port="${6}"
    if grep -qs "$if $src $dst $proto $host_port $jail_port" "${bastille_jailsdir}/${TARGET}/rdr.conf"; then
        error_notify "Error: Ports already in use on this interface."
        error_exit "See 'bastille list ports' or 'bastille rdr TARGET reset'."
    fi
}

persist_rdr_rule() {
    local inet="${1}"
    local if="${2}"
    local src="${3}"
    local dst="${4}"
    local proto="${5}"
    local host_port="${6}"
    local jail_port="${7}"
    if ! grep -qs "$inet $if $src $dst $proto $host_port $jail_port" "${bastille_jailsdir}/${TARGET}/rdr.conf"; then
        echo "$inet $if $src $dst $proto $host_port $jail_port" >> "${bastille_jailsdir}/${TARGET}/rdr.conf"
    fi
}

persist_rdr_log_rule() {
    local inet="${1}"
    local if="${2}"
    local src="${3}"
    local dst="${4}"
    local proto="${5}"
    local host_port="${6}"
    local jail_port="${7}"
    shift 7;
    log=$@;
    if ! grep -qs "$inet $if $src $dst $proto $host_port $jail_port $log" "${bastille_jailsdir}/${TARGET}/rdr.conf"; then
        echo "$inet $if $src $dst $proto $host_port $jail_port $log" >> "${bastille_jailsdir}/${TARGET}/rdr.conf"
    fi
}

load_rdr_rule() {
    local inet="${1}"
    local if_name="${2}"
    local if=ext_if=\"${2}\"
    local src="${3}"
    local dst="${4}"
    local proto="${5}"
    local host_port="${6}"
    local jail_port="${7}"
    # Create IPv4 rdr rule
    # shellcheck disable=SC2193
    if { [ "${inet}" = "ipv4" ] || [ "${inet}" = "dual" ]; } then
        if ! ( pfctl -a "rdr/${TARGET}" -Psn 2>/dev/null;
            printf '%s\nrdr pass on $%s inet proto %s from %s to %s port %s -> %s port %s\n' "$if" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP" "$jail_port" ) \
            | pfctl -a "rdr/${TARGET}" -f-; then
            error_exit "Failed to create IPv4 rdr rule \"${if_name} ${src} ${dst} ${proto} ${host_port} ${jail_port}\""
        else
            info "[${TARGET}]:"
            echo "IPv4 ${proto}/${host_port}:${jail_port} on ${if_name}" 
        fi
    fi
    # Create IPv6 rdr rule (if ip6.addr is enabled)
    # shellcheck disable=SC2193
    if [ -n "${JAIL_IP6}" ] && { [ "${inet}" = "ipv6" ] || [ "${inet}" = "dual" ]; } then
        if ! ( pfctl -a "rdr/${TARGET}" -Psn;
            printf '%s\nrdr pass on $%s inet6 proto %s from %s to %s port %s -> %s port %s\n' "$if" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP6" "$jail_port" ) \
            | pfctl -a "rdr/${TARGET}" -f-; then
            error_exit "Failed to create IPv6 rdr rule \"${if_name} ${src} ${dst} ${proto} ${host_port} ${jail_port}\""
        else
            info "[${TARGET}]:"
            echo "IPv6 ${proto}/${host_port}:${jail_port} on ${if_name}"
        fi
    fi
}

load_rdr_log_rule() {
    local inet="${1}"
    local if_name="${2}"
    local if=ext_if=\"${2}\"
    local src="${3}"
    local dst="${4}"
    local proto="${5}"
    local host_port="${6}"
    local jail_port="${7}"
    shift 7;
    log=$@
    # Create IPv4 rule with log
    # shellcheck disable=SC2193
    if { [ "${inet}" = "ipv4" ] || [ "${inet}" = "dual" ]; } then
        if ! ( pfctl -a "rdr/${TARGET}" -Psn;
            printf '%s\nrdr pass %s on $%s inet proto %s from %s to %s port %s -> %s port %s\n' "$if" "$log" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP" "$jail_port" ) \
            | pfctl -a "rdr/${TARGET}" -f-; then
            error_exit "Failed to create logged IPv4 rdr rule \"${if_name} ${src} ${dst} ${proto} ${host_port} ${jail_port}\""
        else
            info "[${TARGET}]:"
            echo "IPv4 ${proto}/${host_port}:${jail_port} on ${if_name}"
        fi
    fi
    # Create IPv6 rdr rule with log (if ip6.addr is enabled)
    # shellcheck disable=SC2193
    if [ -n "${JAIL_IP6}" ] && { [ "${inet}" = "ipv6" ] || [ "${inet}" = "dual" ]; } then 
        if ! ( pfctl -a "rdr/${TARGET}" -Psn;
            printf '%s\nrdr pass %s on $%s inet6 proto %s from %s to %s port %s -> %s port %s\n' "$if" "$log" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP6" "$jail_port" ) \
            | pfctl -a "rdr/${TARGET}" -f-; then
            error_exit "Failed to create logged IPv6 rdr rule \"${if_name} ${src} ${dst} ${proto} ${host_port} ${jail_port}\""
        else
            info "[${TARGET}]:"
            echo "IPv6 ${proto}/${host_port}:${jail_port} on ${if_name}"
        fi
    fi
}

# Handle options.
RDR_IF="$(grep "^[[:space:]]*${bastille_network_pf_ext_if}[[:space:]]*=" ${bastille_pf_conf} | awk -F'"' '{print $2}')"
RDR_SRC="any"
RDR_DST="any"
RDR_INET="dual"
OPTION_IF=0
OPTION_SRC=0
OPTION_DST=0
OPTION_INET_TYPE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -d|--destination)
            if ifconfig | grep -owq "inet ${2}"; then
	        OPTION_DST=1
                RDR_DST="${2}"
                shift 2
            else
                error_exit "${2} is not an IP on this system."
            fi
            ;;
        -i|--interface)
            if ifconfig | grep -owq "${2}:"; then
                OPTION_IF=1
                RDR_IF="${2}"
                shift 2
            else
                error_exit "${2} is not a valid interface."
            fi
            ;;
        -s|--source)
            check_rdr_ip_validity "${2}"
            OPTION_SRC=1
            RDR_SRC="${2}"
            shift 2
            ;;
        -t|--type)
            if [ "${2}" != "ipv4" ] && [ "${2}" != "ipv6" ]; then
                error_exit "[-t|--type] must be [ipv4|ipv6]"
            else
                OPTION_INET_TYPE=1
                RDR_INET="${2}"
                shift 2
            fi
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            error_exit "Unknown option: \"${1}\""
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 2 ]; then
    usage
fi

TARGET="${1}"
JAIL_IP=""
JAIL_IP6=""
shift

bastille_root_check
set_target_single "${TARGET}"

while [ "$#" -gt 0 ]; do
    case "${1}" in
        list)
            if [ "${OPTION_IF}" -eq 1 ] || [ "${OPTION_SRC}" -eq 1 ] || [ "${OPTION_DST}" -eq 1 ] || [ "${OPTION_INET_TYPE}" -eq 1 ];then
                error_exit "Command \"${1}\" cannot be used with options."
	        elif [ -n "${2}" ]; then
                usage
            else
                check_jail_validity
                pfctl -a "rdr/${TARGET}" -Psn 2>/dev/null
            fi
            shift
            ;;
        clear)
            if [ "${OPTION_IF}" -eq 1 ] || [ "${OPTION_SRC}" -eq 1 ] || [ "${OPTION_DST}" -eq 1 ] || [ "${OPTION_INET_TYPE}" -eq 1 ];then
                error_exit "Command \"${1}\" cannot be used with options."
	        elif [ -n "${2}" ]; then
                usage
            else
                check_jail_validity
                echo "${TARGET} redirects:"
                pfctl -a "rdr/${TARGET}" -Fn
            fi
            shift
            ;;
        reset)
            if [ "${OPTION_IF}" -eq 1 ] || [ "${OPTION_SRC}" -eq 1 ] || [ "${OPTION_DST}" -eq 1 ] || [ "${OPTION_INET_TYPE}" -eq 1 ];then
                error_exit "Command \"${1}\" cannot be used with options."
	        elif [ -n "${2}" ]; then
                usage
            else
                check_jail_validity
                echo "${TARGET} redirects:"
                pfctl -a "rdr/${TARGET}" -Fn
		if rm -f "${bastille_jailsdir}/${_jail}/rdr.conf"; then
                    info "[${TARGET}]: rdr.conf removed"
	        fi
            fi
            shift
            ;;	    
        tcp|udp)
            if [ "$#" -lt 3 ]; then
                usage
            elif [ "${OPTION_SRC}" -eq 1 ] || [ "${OPTION_DST}" -eq 1 ] && [ "${OPTION_INET_TYPE}" -ne 1 ];then
                error_exit "[-t|--type] must be set when using [-s|--source] or [-d|--destination]"
            elif [ "$#" -eq 3 ]; then
                check_jail_validity
                validate_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                persist_rdr_rule $RDR_INET $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                load_rdr_rule $RDR_INET $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                shift "$#"
            else
                case "${4}" in
                    log)
                        proto=$1
                        host_port=$2
                        jail_port=$3
                        shift 3
                        if [ "$#" -gt 3 ]; then
                            for last in "$@"; do
                                true
                            done
                            if [ "${2}" = "(" ] && [ "${last}" = ")" ] ; then
                                check_jail_validity
                                validate_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                                persist_rdr_log_rule $RDR_INET $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
                                load_rdr_log_rule $RDR_INET $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"                                
                                shift $#
                            else
                                usage
                            fi
                        elif [ $# -eq 1 ]; then
                            check_jail_validity
                            validate_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                            persist_rdr_log_rule $RDR_INET $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
                            load_rdr_log_rule $RDR_INET $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
                            shift 1
                        else
                            usage
                        fi
                        ;;
                    *)
                        usage
                        ;;
                esac
            fi
            ;;
        *)
            if [ "${1}" = "dual" ] || [ "${1}" = "ipv4" ] || [ "${1}" = "ipv6" ]; then
                RDR_INET="${1}"
            else 
                usage
            fi
            if [ "$#" -eq 7 ] && { [ "${5}" = "tcp" ] || [ "${5}" = "udp" ]; } then
                check_jail_validity
                validate_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                persist_rdr_rule "$@"
                load_rdr_rule "$@"
                shift "$#"
            elif [ "$#" -ge 8 ] && [ "${8}" = "log" ]; then
                check_jail_validity
                validate_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                persist_rdr_log_rule "$@"
                load_rdr_log_rule "$@"
                shift "$#"
            else
                usage
            fi
            ;;
    esac
done
