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
    error_notify "                                          get PROPERTY[,PROPERTY]"
    error_notify "                                          remove PROPERTY"
    error_notify "                                          show"
    exit 1
}

# Handle options
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -*)
            error_exit "[ERROR]: Unknown Option: \"${1}\""
            ;;
        *)
            break
            ;;
    esac
done

# Verify parameter count
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    usage
fi

TARGET="${1}"
ACTION="${2}"
BASTILLE_PROPERTY=0
shift 2

bastille_root_check
set_target "${TARGET}"

case "${ACTION}" in
    get)
        if [ "$#" -ne 1 ]; then
            error_exit "[ERROR]: Too many parameters for [get|remove] operation."
        fi
        ;;
    remove)
        # 'depend' removal takes a TARGET value; all other properties take
        # only the property name
        case "${1}" in
            depend|depends)
                if [ "$#" -gt 2 ]; then
                    error_exit "[ERROR]: Too many parameters for [get|remove] operation."
                fi
                ;;
            *)
                if [ "$#" -ne 1 ]; then
                    error_exit "[ERROR]: Too many parameters for [get|remove] operation."
                fi
                ;;
        esac
        ;;
    add|set|show)
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

# See if property includes an equal (=) sign
if echo "${PROPERTY}" | grep -q '='; then
    raw_property="${PROPERTY}"
    PROPERTY="$(echo ${raw_property} | awk -F"=" '{print $1}')"
    VALUE="$(echo ${raw_property} | awk -F"=" '{print $2}')"
fi

# This is a list of all supported jail.conf property names
validate_property() {
    local property="${1}"
    if ! grep -Fxq "${property}" "${bastille_sharedir}/lib/properties"; then
        error_exit "[ERROR]: Unsupported property: ${property}"
    fi
}

# boot/depend/priority live in settings.conf (sysrc), not jail.conf.
is_bastille_property() {
    case "${1}" in
        all|boot|depend|depends|prio|priority)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Canonical names so `get prio` and `get priority` hit the same sysrc key.
normalize_property() {
    case "${1}" in
        prio)
            printf '%s\n' "priority"
            ;;
        depends)
            printf '%s\n' "depend"
            ;;
        *)
            printf '%s\n' "${1}"
            ;;
    esac
}

# we need jail(8) to parse the config file so it can expand variables etc
print_jail_conf() {
    # we need to pass a literal \n to jail to get each parameter on its own
    # line
    jail -f "${1}" -e '
'
}

# Comma lists are get-only (like `zfs get atime,compression`). set/remove
# still take one property so we never partially apply a mutation.
PROPERTIES=""
PROP_COUNT=0
if [ "${ACTION}" = "get" ]; then
    # `name,` never yields an empty token in the loop below (the comma is
    # consumed and _rest becomes empty), so catch leading/trailing commas here.
    case "${PROPERTY}" in
		all)
		    PROPERTY="$(printf "%s\n%s" "$(print_jail_conf "${bastille_jailsdir}/${jail}/jail.conf" | awk -F"=" '{print $1}')" "$(cat "${bastille_jailsdir}/${jail}/settings.conf" | awk -F"=" '{print $1}')" | tr '\n' ',')"
            ;;
        ,*|*,)
            error_exit "[ERROR]: Empty property in list."
            ;;
    esac
    rest="${PROPERTY}"
    while [ -n "${rest}" ]; do
        case "${rest}" in
		    all)
				PROPERTIES="$(printf "%s\n%s" "$(print_jail_conf "${bastille_jailsdir}/${jail}/jail.conf" | awk -F"=" '{print $1}')" "$(cat "${bastille_jailsdir}/${jail}/settings.conf" | awk -F"=" '{print $1}')")"
				break
                ;;
            *,*)
                one="${rest%%,*}"
                rest="${rest#*,}"
                ;;
            *)
                one="${rest}"
                rest=""
                ;;
        esac
        # Allow `get 'name, boot'` (quoted spaces); unquoted spaces are
        # extra argv and already rejected by the get argc check.
        one="$(printf '%s' "${one}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [ -z "${one}" ]; then
            error_exit "[ERROR]: Empty property in list."
        fi
        if ! is_bastille_property "${one}"; then
            validate_property "${one}"
        fi
        one="$(normalize_property "${one}")"
        PROPERTIES="${PROPERTIES} ${one}"
        PROP_COUNT=$((PROP_COUNT + 1))
    done
    PROPERTIES="${PROPERTIES# }"
    if [ "${PROP_COUNT}" -eq 0 ]; then
        error_exit "[ERROR]: Empty property in list."
    fi
else
    if [ "${BASTILLE_PROPERTY}" -eq 0 ]; then
            validate_property "${PROPERTY}"
    fi
fi

# Exit 120 is the historic "not set" signal so 1x1 get can warn (yellow)
# without changing the printed text scripts already match.
query_jail_conf() {
    awk -F= -v property="${1}" '
        $1 == property {
            found = 1;
            if (NF == 2) {
                sub(/^"/, "", $2);
                sub(/"$/, "", $2);
                print $2;
            } else {
                print "enabled";
            }
            exit 0;
        }
        END {
            if (! found) {
                print("not set");
                exit(120);
            }
        }'
}

# Returns 120 when a jail.conf property is unset, 2 when jail.conf is missing.
config_get_value() {

    local jail="${1}"
    local property="${2}"
    local file
    local output
    local status

    case "${property}" in
        boot|depend|priority)
            file="${bastille_jailsdir}/${jail}/settings.conf"
            sysrc -f "${file}" -n "${property}" 2>/dev/null
            return 0
            ;;
    esac

    # jail -f is relatively expensive; parse once per jail and reuse the dump
    # for every requested jail.conf property.
    file="${bastille_jailsdir}/${jail}/jail.conf"
    if [ "${JAIL_CONF_LOADED}" -eq 0 ]; then
        if [ ! -f "${file}" ]; then
            return 2
        fi
        JAIL_CONF_TEXT="$(print_jail_conf "${file}")"
        JAIL_CONF_LOADED=1
    fi

    output="$(printf '%s\n' "${JAIL_CONF_TEXT}" | query_jail_conf "${property}")"
    status=$?
    printf '%s\n' "${output}"
    return "${status}"
}

# Stopped jails have no jls entry. Human tables use "-" like `bastille list`;
# JSON still emits null via json_record.
config_jail_jid() {

    local jid="$(jls -j "${1}" jid 2>/dev/null || :)"
	
    if [ -n "${jid}" ]; then
        printf '%s\n' "${jid}"
    else
        printf '%s\n' "-"
    fi
}

handle_get() {

    local jail="${1}"
	local jid
	local status
    local property
	local value

    JAIL_CONF_LOADED=0
    JAIL_CONF_TEXT=""

    for property in ${PROPERTIES}; do
        case "${property}" in
			boot|depend|priority) ;;
            *)
			    if [ ! -f "${bastille_jailsdir}/${jail}/jail.conf" ]; then
                    error_continue "[ERROR]: jail.conf not found for jail: ${jail}"
                fi
				;;
        esac
    done

    if [ "${BASTILLE_JSON:-0}" -eq 1 ]; then
        set -- name "${jail}"
        for property in ${PROPERTIES}; do
            value="$(config_get_value "${jail}" "${property}")"
            set -- "$@" "${property}" "${value}"
        done
        json_record "$@"
        return 0
    fi

    if [ "${TABLE_MODE}" -eq 2 ]; then
        jid="$(config_jail_jid "${jail}")"
    fi

    for property in ${PROPERTIES}; do
        value="$(config_get_value "${jail}" "${property}")"
        status=$?
        if [ "${TABLE_MODE}" -eq 0 ]; then
            # Yellow "not set" is only useful when it is the entire output.
            if [ "${status}" -eq 120 ]; then
                warn 3 "${value}"
            else
                info 3 "${value}"
            fi
        elif [ "${TABLE_MODE}" -eq 1 ]; then
            # Color on a single cell would shift column padding.
            info 3 "$(printf '%-*s %s' "${MAX_PROP}" "${property}" "${value}")"
        else
            info 3 "$(printf '%-*s %-*s %-*s %s' \
                "${MAX_JID}" "${jid}" \
                "${MAX_JAIL}" "${jail}" \
                "${MAX_PROP}" "${property}" \
                "${value}")"
        fi
    done
}

# 0 = bare value (scripts depend on one line, no header)
# 1 = PROPERTY VALUE  (one jail, several properties — identity is already known)
# 2 = JID JAIL PROPERTY VALUE  (several jails; same shape as `zfs get`)
JAIL_COUNT=0
TABLE_MODE=0
if [ "${ACTION}" = "get" ]; then
    for jail in ${JAILS}; do
        JAIL_COUNT=$((JAIL_COUNT + 1))
    done
    if [ "${JAIL_COUNT}" -gt 1 ]; then
        TABLE_MODE=2
    elif [ "${PROP_COUNT}" -gt 1 ] || [ "${PROPERTY}" = "all" ]; then
        TABLE_MODE=1
    fi
fi

# Emit JSON only for the 'get' action (a query); other actions are unchanged.
[ "${ACTION}" = "get" ] && json_open jail

# Header once, before the jail loop. Floor widths at the header labels so a
# short name like "jid" does not under-align "PROPERTY". VALUE is the last
# column and unpadded so spaces in ip4.addr / depend stay in one field.
if [ "${ACTION}" = "get" ] && [ "${BASTILLE_JSON:-0}" -ne 1 ] && [ "${TABLE_MODE}" -gt 0 ]; then
    MAX_PROP=8
    for property in ${PROPERTIES}; do
        [ "${#property}" -gt "${MAX_PROP}" ] && MAX_PROP="${#property}"
    done
    if [ "${TABLE_MODE}" -eq 1 ]; then
        info 3 "$(printf '%-*s %s' "${MAX_PROP}" "PROPERTY" "VALUE")"
    else
        MAX_JID=3
        MAX_JAIL=4
        for jail in ${JAILS}; do
            [ "${#jail}" -gt "${MAX_JAIL}" ] && MAX_JAIL="${#jail}"
            jid="$(config_jail_jid "${jail}")"
            [ "${#jid}" -gt "${MAX_JID}" ] && MAX_JID="${#jid}"
        done
        info 3 "$(printf '%-*s %-*s %-*s %s' \
            "${MAX_JID}" "JID" \
            "${MAX_JAIL}" "JAIL" \
            "${MAX_PROP}" "PROPERTY" \
            "VALUE")"
    fi
fi

for jail in ${JAILS}; do

    if [ "${ACTION}" = "get" ]; then
        handle_get "${jail}"
        continue
    fi

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
    # Currently only 'depend', 'priority' and 'boot'. All stored in settings.conf
    if [ "${BASTILLE_PROPERTY}" -eq 1 ]; then

        FILE="${bastille_jailsdir}/${jail}/settings.conf"

        # Normalize property aliases
        case "${PROPERTY}" in
            prio) PROPERTY="priority" ;;
            depends) PROPERTY="depend" ;;
        esac

        if [ "${ACTION}" = "remove" ]; then
            # Only 'depend' supports removing a value; the rest are permanent
            if [ "${PROPERTY}" != "depend" ]; then
                error_exit "[ERROR]: Cannot remove the '${PROPERTY}' property."
            fi
            if [ -z "${VALUE}" ]; then
                error_exit "[ERROR]: Removing a jail from the 'depend' property requires a TARGET."
            fi
            set_target "${VALUE}"
            info 1 "\n[${jail}]:"
            sysrc -f "${FILE}" "${PROPERTY}-=${JAILS}"

        else # set

            case "${PROPERTY}" in
                priority)
                    echo "${VALUE}" | grep -Eq '^[0-9]+$' || error_exit "Priority value must be a number."
                    sysrc -f "${FILE}" "${PROPERTY}=${VALUE}"
                    ;;
                boot)
                    { [ "${VALUE}" = "on" ] || [ "${VALUE}" = "off" ]; } || error_exit "Boot value must be 'on' or 'off'."
                    sysrc -f "${FILE}" "${PROPERTY}=${VALUE}"
                    ;;
                depend)
                    if [ -z "${VALUE}" ]; then
                        error_exit "[ERROR]: Adding a jail to the 'depend' property requires a TARGET."
                    fi
                    set_target "${VALUE}"
                    info 1 "\n[${jail}]:"
                    sysrc -f "${FILE}" "${PROPERTY}+=${JAILS}"
                    ;;
            esac

        fi

    else
        FILE="${bastille_jailsdir}/${jail}/jail.conf"
        if [ ! -f "${FILE}" ]; then
            error_notify "jail.conf does not exist for jail: ${jail}"
            continue
        fi
        if [ "${ACTION}" = "remove" ]; then
            if [ "$(bastille config ${jail} get ${PROPERTY})" != "not set" ]; then

                info 1 "\n[${jail}]:"

                sed -i '' "/.*${PROPERTY}.*/d" "${FILE}"

                info 2 "Property removed: ${PROPERTY}"

            else
                error_exit "[ERROR]: Value not present in jail.conf: ${PROPERTY}"
            fi

        else # Setting the value. -- cwells

            if [ -n "${VALUE}" ]; then
                if ! echo "${VALUE}" | grep -E '^[A-Za-z0-9._/:| $!&%=(){}-]+$' > /dev/null 2>&1; then
                    error_exit "[ERROR]: Value contains unsupported characters: ${VALUE}"
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

[ "${ACTION}" = "get" ] && json_close

# Only display this message once at the end (not for every jail). -- cwells
if { [ "${ACTION}" = "set" ] || [ "${ACTION}" = "remove" ]; } && [ "${BASTILLE_PROPERTY}" -eq 0 ]; then
    info 1 "A restart is required for the changes to be applied. See 'bastille restart'."
fi

exit 0
