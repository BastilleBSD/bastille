#!/bin/sh
#
# Copyright (c) 2018-2024, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille rdr TARGET [options(s)] [clear|list|(tcp|udp host_port jail_port [log ['(' logopts ')'] ] )]"

    cat << EOF
    Options:

    -i [interface]      |      -- Set the interface to create the rdr rule on. Useful if you have multiple interfaces.
    -s [source ip]      |      -- Limit rdr to a source IP. Useful to only allow access from a certian IP or subnet.
    -d [destination ip] | -- Limit rdr to a destination IP. Useful if you have multiple IPs on one interface.

EOF
    exit 1
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

bastille_root_check

TARGET="${1}"
JAIL_NAME=""
JAIL_IP=""
JAIL_IP6=""
EXT_IF=""
RDR_IF=""
RDR_SRC=""
RDR_DST=""
shift

check_jail_validity() {
    # Can only redirect to single jail
    if [ "${TARGET}" = 'ALL' ]; then
        error_exit "Can only redirect to a single jail."
    fi

    # Check if jail name is valid
    JAIL_NAME=$(/usr/sbin/jls -j "${TARGET}" name 2>/dev/null)
    if [ -z "${JAIL_NAME}" ]; then
        error_exit "Jail not found: ${TARGET}"
    fi

    # Check if jail ip4 address (ip4.addr) is valid (non-VNET only)
    if [ "$(bastille config $TARGET get vnet)" != 'enabled' ]; then
        JAIL_IP=$(/usr/sbin/jls -j "${TARGET}" ip4.addr 2>/dev/null)
        if [ -z "${JAIL_IP}" -o "${JAIL_IP}" = "-" ]; then
            error_exit "Jail IP not found: ${TARGET}"
        fi
    fi
    # Check if jail ip6 address (ip6.addr) is valid (non-VNET only)
    if [ "$(bastille config $TARGET get vnet)" != 'enabled' ]; then
        if [ "$(bastille config $TARGET get ip6)" != 'disable' ] && [ "$(bastille config $TARGET get ip6)" != 'not set' ]; then
            JAIL_IP6=$(/usr/sbin/jls -j "${TARGET}" ip6.addr 2>/dev/null)
        fi
    fi

    # Check if rdr-anchor is defined in pf.conf
    if ! (pfctl -sn | grep rdr-anchor | grep 'rdr/\*' >/dev/null); then
        error_exit "rdr-anchor not found in pf.conf"
    fi

    # Check if ext_if is defined in pf.conf
    # If EXT_IF is set, use it instead of the default
    if [ -n "${bastille_pf_conf}" ]; then
        if [ -z "${EXT_IF}" ]; then
            EXT_IF=$(grep "^[[:space:]]*${bastille_network_pf_ext_if}[[:space:]]*=" ${bastille_pf_conf})
        else
            error_exit "bastille_network_pf_ext_if (${bastille_network_pf_ext_if}) not defined in pf.conf"
        fi
    fi
}

# function: write rule to rdr.conf
persist_rdr_rule() {
  local if="${1}"
  local src="${2}"
  local dst="${3}"
  local proto="${4}"
  local host_port="${5}"
  local jail_port="${6}"
if ! grep -qs "$if $src $dst $proto $host_port $jail_port" "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"; then
    echo "$if $src $dst $proto $host_port $jail_port" >> "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"
fi
}

persist_rdr_log_rule() {
  local if="${1}"
  local src="${2}"
  local dst="${3}"
  local proto="${4}"
  local host_port="${5}"
  local jail_port="${6}"
shift 6;
log=$@;
if ! grep -qs "$if $src $dst $proto $host_port $jail_port $log" "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"; then
    echo "$if $src $dst $proto $host_port $jail_port $log" >> "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"
fi
}

# function: load rdr rule via pfctl
load_rdr_rule() {
  local if=ext_if=\"${1}\"
  local src="${2}"
  local dst="${3}"
  local proto="${4}"
  local host_port="${5}"
  local jail_port="${6}"
( pfctl -a "rdr/${JAIL_NAME}" -Psn 2>/dev/null;
  printf '%s\nrdr pass on $%s inet proto %s from %s to %s port %s -> %s port %s\n' "$if" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP" "$jail_port" ) \
      | pfctl -a "rdr/${JAIL_NAME}" -f-
if [ -n "$JAIL_IP6" ]; then
( pfctl -a "rdr/${JAIL_NAME}" -Psn;
  printf '%s\nrdr pass on $%s inet proto %s to port %s -> %s port %s\n' "$if" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP6" "$jail_port" ) \
    | pfctl -a "rdr/${JAIL_NAME}" -f-
fi
info "[${JAIL_NAME}]:"
info "Redirecting:"
info "${src}:${host_port} -> ${dst}:${jail_port} on ${1}" 
}

# function: load rdr rule with log via pfctl
load_rdr_log_rule() {
  local if=ext_if=\"${1}\"
  local src="${2}"
  local dst="${3}"
  local proto="${4}"
  local host_port="${5}"
  local jail_port="${6}"
shift 6;
log=$@
( pfctl -a "rdr/${JAIL_NAME}" -Psn;
  printf '%s\nrdr pass %s on $%s inet proto %s from %s to %s port %s -> %s port %s\n' "$if" "$log" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP" "$jail_port" ) \
      | pfctl -a "rdr/${JAIL_NAME}" -f-
if [ -n "$JAIL_IP6" ]; then
  ( pfctl -a "rdr/${JAIL_NAME}" -Psn;
  printf '%s\nrdr pass %s on $%s inet proto %s from %s to %s port %s -> %s port %s\n' "$if" "$log" "${bastille_network_pf_ext_if}" "$proto" "$src" "$dst" "$host_port" "$JAIL_IP6" "$jail_port" ) \
    | pfctl -a "rdr/${JAIL_NAME}" -f-
fi
info "[${JAIL_NAME}]:"
info "Redirecting:"
info "${src}:${host_port} -> ${dst}:${jail_port} on ${1}" 
}


while [ $# -gt 0 ]; do
  while getopts "i:s:d:" opt; do
    case $opt in
        i) if ifconfig | grep -ow "${OPTARG}:"; then
             RDR_IF="${OPTARG}"
           else
             error_exit "$OPTARG is not a valid interface on this system."
           fi 
           ;;
        s) RDR_SRC="$OPTARG"
           ;;
        d) if ifconfig | grep -ow "inet ${OPTARG}"; then
            RDR_DST="$OPTARG"
           else
             error_exit "$OPTARG is not an IP on this system."
           fi
           ;;
        *) usage ;;
    esac
  done
  shift $((OPTIND - 1))

  # Set default interface, source, and destination if not set by options
  if [ -z $RDR_IF ]; then    
    RDR_IF="$(grep "^[[:space:]]*${bastille_network_pf_ext_if}[[:space:]]*=" ${bastille_pf_conf} | awk -F'"' '{print $2}')"
  fi
  if [ -z $RDR_SRC ]; then
    RDR_SRC="any"
  fi
  if [ -z $RDR_DST ]; then
    RDR_DST="any"
  fi

    case "$1" in
        list)
            if [ "${TARGET}" = 'ALL' ]; then
                for JAIL_NAME in $(ls "${bastille_jailsdir}" | sed "s/\n//g"); do
                    echo "${JAIL_NAME} redirects:"
                    pfctl -a "rdr/${JAIL_NAME}" -Psn 2>/dev/null
                done
            else
                check_jail_validity
                pfctl -a "rdr/${JAIL_NAME}" -Psn 2>/dev/null
            fi
            shift
            ;;
        clear)
            if [ "${TARGET}" = 'ALL' ]; then
                for JAIL_NAME in $(ls "${bastille_jailsdir}" | sed "s/\n//g"); do
                    echo "${JAIL_NAME} redirects:"
                    pfctl -a "rdr/${JAIL_NAME}" -Fn
                done
            else
                check_jail_validity
                pfctl -a "rdr/${JAIL_NAME}" -Fn
            fi
            shift
            ;;
        tcp|udp)
            if [ $# -lt 3 ]; then
                usage
            elif [ $# -eq 3 ]; then
                check_jail_validity
                persist_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                load_rdr_rule $RDR_IF $RDR_SRC $RDR_DST $1 $2 $3
                shift "$#"
            else
                case "$4" in
                    log)
                        proto=$1
                        host_port=$2
                        jail_port=$3
                        shift 3
                        if [ $# -gt 3 ]; then
                            for last in "$@"; do
                                true
                            done
                            if [ $2 == "(" ] && [ $last == ")" ] ; then
                                check_jail_validity
                                persist_rdr_log_rule $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
                                load_rdr_log_rule $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
                                shift $#
                            else
                                usage
                            fi
                        elif [ $# -eq 1 ]; then
                            check_jail_validity
                            persist_rdr_log_rule $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
                            load_rdr_log_rule $RDR_IF $RDR_SRC $RDR_DST $proto $host_port $jail_port "$@"
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
            if [ $# -gt 5 ]; then
              check_jail_validity
              persist_rdr_rule "$@"
              load_rdr_rule "$@"
              shift $#
            else
              usage
            fi
            ;;
    esac
done
