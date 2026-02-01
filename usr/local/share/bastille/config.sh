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


usage() {
    error_notify "Usage: bastille config [option(s)] TARGET set|add PROPERTY [VALUE]"
    error_notify "                                          get|remove PROPERTY"
    cat << EOF

    Options:

    -x | --debug     Enable debug mode.

EOF
    exit 1
}

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            error_notify "[ERROR]: Unknown Option: \"${1}\""
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    usage
fi

bastille_root_check

TARGET="${1}"
ACTION="${2}"
BASTILLE_PROPERTY=0
shift 2

set_target "${TARGET}"

case "${ACTION}" in
    get|remove)
        if [ "$#" -ne 1 ]; then
            error_exit "[ERROR]: Too many parameters for [get|remove] operation."
        fi
        ;;
    add|set)
        ;;
    *)
        error_exit "[ERROR]: Only (add|set), get and remove are supported."
        ;;
esac

if [ "${ACTION}" = "add" ]; then
    ACTION="set"
fi

PROPERTY="${1}"
shift
VALUE="$@"

# This is a list of all supported jail.conf property names
validate_property() {

    local property="${1}"

    case "${property}" in
        jid|name|path|interface|ip_hostname) ;;
        ip4.addr|ip4.saddrsel|ip4|ip6.addr|ip6.saddrsel|ip6) ;;
        vnet|vnet|vnet.interface) ;;
        host.hostname|host.domainname|host.hostuuid|host.hostid|host) ;;
        securelevel|devfs_ruleset|children.max|children.cur|enforce_statfs|persist|nopersist|cpuset.id|parent) ;;
        osrelease|osreldate|meta|env) ;;
        allow.set_hostname|allow.sysvipc|allow.raw_sockets|allow.chflags) ;;
        allow.noset_hostname|allow.nosysvipc|allow.noraw_sockets|allow.nochflags) ;;
        allow.mount|allow.mount.devfs|allow.quotas|allow.read_msgbuf) ;;
        allow.nomount|allow.nomount.devfs|allow.noquotas|allow.noread_msgbuf) ;;
        allow.socket_af|allow.mlock|allow.nfsd|allow.reserved_ports) ;;
        allow.nosocket_af|allow.nomlock|allow.nonfsd|allow.noreserved_ports) ;;
        allow.unprivileged_parent_tampering|allow.unprivileged_proc_debug) ;;
        allow.nounprivileged_parent_tampering|allow.nounprivileged_proc_debug) ;;
        allow.suser|allow.extattr|allow.adjtime|allow.settime|allow.routing|allow.setaudit) ;;
        allow.nosuser|allow.noextattr|allow.noadjtime|allow.nosettime|allow.norouting|allow.nosetaudit) ;;
        allow.mount.fdescfs|allow.mount.fusefs|allow.mount.nullfs|allow.mount.procfs|allow.mount.linprocfs) ;;
        allow.nomount.fdescfs|allow.nomount.fusefs|allow.nomount.nullfs|allow.nomount.procfs|allow.nomount.linprocfs) ;;
        allow.mount.linsysfs|allow.mount.tmpfs|allow.mount.zfs|allow.vmm) ;;
        allow.nomount.linsysfs|allow.nomount.tmpfs|allow.nomount.zfs|allow.novmm) ;;
        linux|linux.osname|linux.osrelease|linux.oss_version) ;;
        sysvmsg|sysvsem|sysvshm|zfs.mount_snapshot) ;;
        exec.prepare|exec.prestart|exec.created|exec.start|command|exec.poststart) ;;
        exec.prestop|exec.stop|exec.poststop|exec.release|exec.clean) ;;
        exec.jail_user|exec.system_jail_user|exec.system_user|exec.timeout) ;;
        exec.consolelog|exec.fib|stop.timeout) ;;
        zfs.dataset|mount|mount.fstab|mount.devfs|mount.fdescfs|mount.procfs) ;;
        dying|allow.dying);;
        *) error_exit "[ERROR]: Unsupported property: ${property}" ;;
    esac
}

case "${PROPERTY}" in
    boot|depend|depends|prio|priority)
        BASTILLE_PROPERTY=1
        ;;
    *)
        validate_property "${PROPERTY}"
        ;;
esac

# we need jail(8) to parse the config file so it can expand variables etc
print_jail_conf() {

    # we need to pass a literal \n to jail to get each parameter on its own
    # line
    jail -f "${1}" -e '
'
}

for jail in ${JAILS}; do

    # Backwards compatibility for specifying only an IP with ip[4|6].addr
    if [ "${ACTION}" = "set" ] && [ "${PROPERTY}" = "ip4.addr" ]; then
        if ! echo "${VALUE}" | grep -q "|"; then
            VALUE="$(bastille config ${jail} get ip4.addr | awk -F"|" '{print $1}')|${VALUE}"
        fi
    elif [ "${ACTION}" = "set" ] && [ "${PROPERTY}" = "ip6.addr" ]; then
        if ! echo "${VALUE}" | grep -q "|"; then
            VALUE="$(bastille config ${jail} get ip6.addr | awk -F"|" '{print $1}')|${VALUE}"
        fi
    fi

    # Handle Bastille specific properties
    # Currently only 'depend' 'priority' and 'boot'
    if [ "${PROPERTY}" = "priority" ] || [ "${PROPERTY}" = "prio" ]; then

        PROPERTY="priority"
        FILE="${bastille_jailsdir}/${jail}/settings.conf"

        if [ "${ACTION}" = "set" ]; then
            if echo "${VALUE}" | grep -Eq '^[0-9]+$'; then
                sysrc -f "${FILE}" "${PROPERTY}=${VALUE}"
            else
                error_exit "Priority value must be a number."
            fi
        elif [ "${ACTION}" = "remove" ]; then
            error_exit "[ERROR]: Cannot remove the 'priority' property."
        elif [ "${ACTION}" = "get" ]; then
            sysrc -f "${FILE}" -n "${PROPERTY}"
        fi

    # Boot property
    elif [ "${PROPERTY}" = "boot" ]; then

        FILE="${bastille_jailsdir}/${jail}/settings.conf"

        if [ "${ACTION}" = "set" ]; then
            if [ "${VALUE}" = "on" ] || [ "${VALUE}" = "off" ]; then
                sysrc -f "${FILE}" "${PROPERTY}=${VALUE}"
            else
                error_exit "Boot value must be 'on' or 'off'."
            fi
        elif [ "${ACTION}" = "remove" ]; then
            error_exit "[ERROR]: Cannot remove the 'boot' property."
        elif [ "${ACTION}" = "get" ]; then
            sysrc -f "${FILE}" -n "${PROPERTY}"
        fi

    # Depend property
    elif [ "${PROPERTY}" = "depend" ] || [ "${PROPERTY}" = "depends" ]; then

        PROPERTY="depend"
        FILE="${bastille_jailsdir}/${jail}/settings.conf"

        if [ "${ACTION}" = "set" ]; then

            if [ -z "${VALUE}" ]; then
                error_exit "[ERROR]: Adding a jail to the 'depend' property requires a TARGET."
            else
                set_target "${VALUE}"
            fi

            info "\n[${jail}]:"

            sysrc -f "${FILE}" "${PROPERTY}+=${JAILS}"

        elif [ "${ACTION}" = "remove" ]; then

            if [ -z "${VALUE}" ]; then
                error_exit "[ERROR]: Removing a jail from the 'depend' property requires a TARGET."
            else
                set_target "${VALUE}"
            fi

            info "\n[${jail}]:"

            sysrc -f "${FILE}" "${PROPERTY}-=${JAILS}"

        elif [ "${ACTION}" = "get" ]; then

            sysrc -f "${FILE}" -n "${PROPERTY}"

        fi
    else
        FILE="${bastille_jailsdir}/${jail}/jail.conf"
        if [ ! -f "${FILE}" ]; then
            error_notify "jail.conf does not exist for jail: ${jail}"
            continue
        fi
        if [ "${ACTION}" = 'get' ]; then
            _output=$(
                print_jail_conf "${FILE}" | awk -F= -v property="${PROPERTY}" '
                    $1 == property {
                        # note that we have found the property
                        found = 1;
                        # check if there is a value for this property
                        if (NF == 2) {
                            # remove any quotes surrounding the string
                            #sub(",[^|]*\\|", ",", $2);
                            sub(/^"/, "", $2);
                            sub(/"$/, "", $2);
                            print $2;
                        } else {
                            # no value, just the property name
                            print "enabled";
                        }
                        exit 0;
                    }
                    END {
                        # if we have not found anything we need to print a special
                        # string
                        if (! found) {
                            print("not set");
                            #  let the caller know that this is a warn condition
                            exit(120);
                        }
                    }'
                )
            # check if our output is a warning or regular
            if [ $? -eq 120 ]; then
                warn "${_output}"
            else
                echo "${_output}"
            fi
        elif [ "${ACTION}" = "remove" ]; then
            if [ "$(bastille config ${jail} get ${PROPERTY})" != "not set" ]; then

                info "\n[${jail}]:"

                sed -i '' "/.*${PROPERTY}.*/d" "${FILE}"

                echo "Property removed: ${PROPERTY}"

            else
                error_exit "[ERROR]: Value not present in jail.conf: ${PROPERTY}"
            fi

        else # Setting the value. -- cwells

            if [ -n "${VALUE}" ]; then
                if ! echo "${VALUE}" | grep -E '^([a-zA-Z0-9._/ :-]|\\\$|\\!|\\&)+$' > /dev/null 2>&1; then
                    error_exit "[ERROR]: VALUE contains unsupported characters."
                fi
                VALUE=$(echo "${VALUE}" | sed 's/\//\\\//g')
                if echo "${VALUE}" | grep ' ' > /dev/null 2>&1; then # Contains a space, so wrap in quotes. -- cwells
                    VALUE="'${VALUE}'"
                fi
                LINE="  ${PROPERTY} = ${VALUE};"
            else
                LINE="  ${PROPERTY};"
            fi

            # add the value to the config file, replacing any existing value or, if
            # there is none, at the end
            #
            # awk doesn't have "inplace" editing so we use a temp file
            tmpfile=$(mktemp) || error_exit "[ERROR]: Failed to create tmpfile."
            if awk -F= -v line="${LINE}" -v property="${PROPERTY}" '
                BEGIN {
                    # build RE as string as we can not expand vars in RE literals
                    prop_re = "^[[:space:]]*" property "[[:space:]]*;?$";
                }
                $1 ~ prop_re && !found {
                    # we already have an entry in the config for this property so
                    # we need to substitute our line here rather than keep the
                    # existing line
                    print(line);
                    # note we have already found the property
                    found = 1;
                    # move onto the next line
                    next;
                }
                $1 == "}" {
                    # reached the end of the stanza so if we have not already
                    # added our line we need to do so now
                    if (! found) {
                        print(line);
                    }
                }
                {
                    # print each uninteresting line unchanged
                    print;
                }
            ' "${FILE}" > "${tmpfile}"; then
                mv "${tmpfile}" "${FILE}"
            else
                rm "${tmpfile}"
                error_exit "[ERROR]: Failed to update jail.conf"
            fi
        fi
    fi

done

# Only display this message once at the end (not for every jail). -- cwells
if { [ "${ACTION}" = "set" ] || [ "${ACTION}" = "remove" ]; } && [ "${BASTILLE_PROPERTY}" -eq 0 ]; then
    info "A restart is required for the changes to be applied. See 'bastille restart'."
fi

exit 0
