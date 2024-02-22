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
    error_exit "Usage: bastille rdr TARGET \
[(dev <net_device>)|(ip <destination_ip>)] \
(clear [persistent])|(list [persistent])|\
(tcp|udp <host_port> <jail_port> [log ['(' logopts ')'] ] )"
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
shift

JAIL_NAME=""
JAIL_IP=""
JAIL_IP6=""
EXT_IF=""
EXT_IP="any"
RDR_LOG=""
RDR_CMD="$@"

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
    if [ -n "${bastille_pf_conf}" ] && [ -z $EXT_IF ]; then
        EXT_IF=$(grep "^[[:space:]]*${bastille_network_pf_ext_if}[[:space:]]*=" ${bastille_pf_conf} | cut -d= -f2 | sed 's/"//g')
        if [ -z "${EXT_IF}" ]; then
            error_exit "bastille_network_pf_ext_if (${bastille_network_pf_ext_if}) not defined in pf.conf"
        fi
    fi
}

# function: write rule to rdr.conf
persist_rdr_rule() {
    if ! grep -qs "^$RDR_CMD$" "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"; then
        echo "$RDR_CMD" >> "${bastille_jailsdir}/${JAIL_NAME}/rdr.conf"
    fi
}

# function: load rdr rule via pfctl
load_rdr_rule() {
    proto=$1
    host_port=$2
    jail_port=$3

    rule="rdr pass $RDR_LOG on $EXT_IF inet proto $proto from any to $EXT_IP port $host_port -> $JAIL_IP port $jail_port"

    (pfctl -a "rdr/${JAIL_NAME}" -Psn ; echo $rule) | pfctl -a "rdr/${JAIL_NAME}" -f-
}

port_rdr_rule() {
    if [ $# -lt 3 ]; then
        usage
    fi

    check_jail_validity

    if [ $# -eq 3 ]; then
        persist_rdr_rule
        load_rdr_rule $@
        if [ -n "$JAIL_IP6" ]; then
            JAIL_IP=$JAIL_IP6
            load_rdr_rule $@
        fi
    else
        case "$4" in
            log)
                proto=$1
                host_port=$2
                jail_port=$3
                shift 3
                RDR_LOG="$@"
                if [ $# -gt 3 ]; then
                    for last in $@; do
                        true
                    done
                    if [ $2 == "(" ] && [ $last == ")" ] ; then
                        persist_rdr_rule
                        load_rdr_rule $proto $host_port $jail_port
                        if [ -n "$JAIL_IP6" ]; then
                            JAIL_IP=$JAIL_IP6
                            load_rdr_rule $proto $host_port $jail_port
                        fi
                    else
                        usage
                    fi
                elif [ $# -eq 1 ]; then
                    persist_rdr_rule
                    load_rdr_rule $proto $host_port $jail_port
                    if [ -n "$JAIL_IP6" ]; then
                        JAIL_IP=$JAIL_IP6
                        load_rdr_rule $proto $host_port $jail_port
                    fi
                else
                    usage
                fi
                ;;
            *)
                usage
                ;;
        esac
    fi
}

list_rules() {
    jail_name=$1
    persistent=$2

    if [ -z $persistent ]; then
        pfctl -a "rdr/${jail_name}" -Psn 2>/dev/null
    else
        cat ${bastille_jailsdir}/${jail_name}/rdr.conf 2>/dev/null
    fi
}

clear_rules() {
    jail_name=$1
    persistent=$2

    echo "Clearing ${jail_name} redirects."
    pfctl -a "rdr/${jail_name}" -Fn
    if [ ! -z $persistent ]; then
        echo "Clearing ${jail_name} rdr.conf."
        rm -f ${bastille_jailsdir}/${jail_name}/rdr.conf
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        list)
            persistent=""
            if [ "$2" = 'persistent' ]; then
                persistent="true"
            fi
            if [ "${TARGET}" = 'ALL' ]; then
                for NAME in $(ls "${bastille_jailsdir}" | sed "s/\n//g"); do
                    echo "$NAME redirects:"
                    list_rules $NAME $persistent
                done
            else
                check_jail_validity
                list_rules $JAIL_NAME $persistent
            fi
            break
            ;;
        clear)
            persistent=""
            if [ "$2" = 'persistent' ]; then
                persistent="true"
            fi
            if [ "${TARGET}" = 'ALL' ]; then
                for NAME in $(ls "${bastille_jailsdir}" | sed "s/\n//g"); do
                    clear_rules $NAME $persistent
                done
            else
                check_jail_validity
                clear_rules $JAIL_NAME $persistent
            fi
            break
            ;;
        tcp|udp)
            port_rdr_rule $@
            break
            ;;
        dev)
            # dev is a modifier not a final command so at least 3 args
            if [ $# -lt 3 ]; then
                usage
            fi
            EXT_IF=$2
            shift 2
            ;;
        ip)
            # ip is a modifier not a final command so at least 3 args
            if [ $# -lt 3 ]; then
                usage
            fi
            EXT_IP=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done
