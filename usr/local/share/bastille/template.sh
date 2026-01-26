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

    error_notify "Usage: bastille template [option(s)] TARGET|convert TEMPLATE"
    cat << EOF

    Options:

    -a | --auto      Auto mode. Start/stop jail(s) if required.
    -x | --debug     Enable debug mode.

EOF
    exit 1
}

post_command_hook() {

    local jail=$1
    local cmd=$2
    local args=$3

    case $cmd in
        rdr)
            info 3 ${args}
    esac
}

get_arg_name() {

    local name_value_pair="${1}"

    echo "${name_value_pair}" | sed -E 's/=.*//'
}

parse_arg_value() {

    local arg="${1}"

    # Parses the value after = and then escapes back/forward slashes and single quotes in it. -- cwells
    eval echo "${arg}" | \
	sed -E 's/[^=]+=?//' | \
	sed -e 's/\\/\\\\/g' \
	    -e 's/\//\\\//g' \
		-e 's/'\''/'\''\\'\'\''/g' \
		-e 's/&/\\&/g' \
		-e 's/"//g'
}

get_arg_value() {

    local name_value_pair="${1}"
    shift
    arg_name="$(get_arg_name "${name_value_pair}")"

    # Remaining arguments in $@ are the script arguments, which take precedence. -- cwells
    for script_arg in "$@"; do
        case ${script_arg} in
            --arg)
                # Parse whatever is next. -- cwells
                next_arg='true' ;;
            *)
                if [ "${next_arg}" = 'true' ]; then # This is the parameter after --arg. -- cwells
                    next_arg=''
                    if [ "$(get_arg_name "${script_arg}")" = "${arg_name}" ]; then
                        parse_arg_value "${script_arg}"
                        return
                    fi
                fi
                ;;
        esac
    done

    # Check the ARG_FILE if one was provided. --cwells
    if [ -n "${ARG_FILE}" ]; then
        # To prevent a false empty value, only parse the value if this argument exists in the file. -- cwells
        if grep "^${arg_name}=" "${ARG_FILE}" > /dev/null 2>&1; then
            parse_arg_value "$(grep "^${arg_name}=" "${ARG_FILE}")"
            return
        fi
    fi

    # Return the default value, which may be empty, from the name=value pair. -- cwells
    parse_arg_value "${name_value_pair}"
}

render() {

    local file_path="${1}/${2}"

    if [ -d "${file_path}" ]; then # Recursively render every file in this directory. -- cwells
        info 2 "Rendering Directory: ${file_path}"
        find "${file_path}" \( -type d -name .git -prune \) -o -type f -print0 | eval "xargs -0 sed -i '' ${ARG_REPLACEMENTS}"
    elif [ -f "${file_path}" ]; then
        info 2 "Rendering File: ${file_path}"
        eval "sed -i '' ${ARG_REPLACEMENTS} '${file_path}'"
    else
        warn 1 "[WARNING]: Path not found for render: ${2}"
    fi
}

line_in_file() {

    local jail_path="${1}"
    eval set -- "${2}"
    local line="${1}"
    local file_path="${2}"
    local file_in_jail_path="${jail_path}/${file_path}"
    local file_in_jail_dir="$(dirname "${file_in_jail_path}")"

    if [ -f "${file_in_jail_path}" ]; then
        if ! grep -qxF "${line}" "${file_in_jail_path}"; then
            echo "${line}" >> "${file_in_jail_path}"
	fi
    else
        mkdir -p "${file_in_jail_dir}"
        echo "${line}" > "${file_in_jail_path}"
    fi
}

# Handle options.
AUTO=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    a) AUTO=1 ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\"" ;;
                esac
            done
            shift
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
TEMPLATE="${2}"
bastille_template=${bastille_templatesdir}/${TEMPLATE}

bastille_root_check

# We set the target only if it is not --convert
# Special case conversion of hook-style template files into a Bastillefile. -- cwells
if [ "${TARGET}" = "convert" ]; then
    if [ -d "${TEMPLATE}" ]; then # A relative path was provided. -- cwells
        cd "${TEMPLATE}" || error_exit "[ERROR]: Failed to change to directory: ${TEMPLATE}"
    elif [ -d "${bastille_template}" ]; then
        cd "${bastille_template}" || error_exit "[ERROR]: Failed to change to directory: ${TEMPLATE}"
    else
        error_exit "[ERROR]: Template not found: ${TEMPLATE}"
    fi

    info 2 "Converting template: ${TEMPLATE}"

    # Convert legacy template to Bastillefile
    HOOKS='ARG LIMITS INCLUDE PRE FSTAB PF PKG OVERLAY CONFIG SYSRC SERVICE CMD RENDER'
    for hook in ${HOOKS}; do
        if [ -s "${hook}" ]; then
            # Default command is the hook name and default args are the line from the file. -- cwells
            cmd="${hook}"
            args_template='${line}'

            # Replace old hook names with Bastille command names. -- cwells
            case ${hook} in
                CONFIG|OVERLAY)
                    cmd='CP'
                    args_template='${line} /'
                    ;;
                FSTAB)
                    cmd='MOUNT' ;;
                PF)
                    cmd='RDR' ;;
                PRE)
                    cmd='CMD' ;;
            esac

            while read line; do
                if [ -z "${line}" ]; then
                    continue
                fi
                eval "args=\"${args_template}\""
                echo "${cmd} ${args}" >> Bastillefile
            done < "${hook}"
            echo '' >> Bastillefile
            rm "${hook}"
        fi
    done

    info 1 "\nTemplate converted: ${TEMPLATE}"
    exit 0
else
    set_target "${TARGET}"
fi

case ${TEMPLATE} in
    http?://*/*/*)
        TEMPLATE_DIR=$(echo "${TEMPLATE}" | awk -F / '{ print $4 "/" $5 }')
        if [ ! -d "${bastille_templatesdir}/${TEMPLATE_DIR}" ]; then
            info 1 "Bootstrapping ${TEMPLATE}..."
            if ! bastille bootstrap "${TEMPLATE}"; then
                error_exit "[ERROR]: Failed to bootstrap template: ${TEMPLATE}"
            fi
        fi
        TEMPLATE="${TEMPLATE_DIR}"
        bastille_template=${bastille_templatesdir}/${TEMPLATE}
        ;;
    */*)
        if [ ! -d "${bastille_templatesdir}/${TEMPLATE}" ]; then
            if [ ! -d ${TEMPLATE} ]; then
                error_exit "[ERROR]: ${TEMPLATE} not found."
            else
                bastille_template=${TEMPLATE}
            fi
        fi
        ;;
    *)
        error_exit "[ERROR]: Template name/URL not recognized."
esac

# Check for an --arg-file parameter. -- cwells
for script_arg in "$@"; do
    case ${script_arg} in
        --arg-file)
            # Parse whatever is next. -- cwells
            next_arg='true' ;;
        *)
            if [ "${next_arg}" = 'true' ]; then # This is the parameter after --arg-file. -- cwells
                next_arg=''
                ARG_FILE="${script_arg}"
                break
            fi
            ;;
    esac
done

# Check if ARG_FILE exists
if [ -n "${ARG_FILE}" ] && [ ! -f "${ARG_FILE}" ]; then
    error_exit "[ERROR]: File not found: ${ARG_FILE}"
fi

for jail in ${JAILS}; do

    check_target_is_running "${jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${jail}"
    else
        info 1 "\n[${jail}]:"
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi

    info 1 "\n[${jail}]:"

    info 2 "Applying template: ${TEMPLATE}..."

    # Get non-VNET IP
    bastille_jail_path=$(/usr/sbin/jls -j "${jail}" path)
    if [ "$(bastille config ${jail} get vnet)" != 'enabled' ]; then
        jail_ip4="$(bastille config ${jail} get ip4.addr | sed 's/,/ /g' | awk '{print $1}')"
        jail_ip6="$(bastille config ${jail} get ip6.addr | sed 's/,/ /g' | awk '{print $1}')"
    # Get VNET IP
	else
        jail_ip4="$(jexec -l ${jail} ifconfig -an | grep "^[[:space:]]*inet " | grep -v "127.0.0.1" | awk '{print $2}')"
        jail_ip6="$(jexec -l ${jail} ifconfig -an | grep "^[[:space:]]*inet6" | grep -Ev 'lo[0-9]+| ::1 | fe80::' | awk '{print $2}' | sed 's/%.*//g')"
    fi

    ## remove value if ip4 was not set or disabled, otherwise get value
    if [ "${jail_ip4}" = "not set" ] || [ "${jail_ip4}" = "disable" ]; then
        jail_ip4='' # In case it was -. -- cwells
    elif echo "${jail_ip4}" | grep -q "|"; then
        jail_ip4="$(echo ${jail_ip4} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
    else
        jail_ip4="$(echo ${jail_ip4} | sed -E 's#/[0-9]+$##g')"
    fi

    ## remove value if ip6 was not set or disabled, otherwise get value
    if [ "${jail_ip6}" = "not set" ] || [ "${jail_ip6}" = "disable" ]; then
        jail_ip6='' # In case it was -. -- cwells
    elif echo "${jail_ip6}" | grep -q "|"; then
        jail_ip6="$(echo ${jail_ip6} | awk -F"|" '{print $2}' | sed -E 's#/[0-9]+$##g')"
    else
        jail_ip6="$(echo ${jail_ip6} | sed -E 's#/[0-9]+$##g')"
    fi

    # print error when both ip4 and ip6 are not set
    if { [ "${jail_ip4}" = "not set" ] || [ "${jail_ip4}" = "disable" ]; } && \
       { [ "${jail_ip6}" = "not set" ] || [ "${jail_ip6}" = "disable" ]; } then
        error_notify "Jail IP not found for jail: ${jail}"
    fi

    # Build a list of sed commands like this: -e 's/${username}/root/g' -e 's/${domain}/example.com/g'
    # Values provided by default (without being defined by the user) are listed here. -- cwells
    ARG_REPLACEMENTS="-e 's/\${JAIL_IP}/${jail_ip4}/g' -e 's/\${JAIL_IP6}/${jail_ip6}/g' -e 's/\${JAIL_NAME}/${jail}/g'"

    ### Bastillefile ###
    if [ -s "${bastille_template}/Bastillefile" ]; then

        # Ignore blank lines and comments. -- cwells
        SCRIPT=$(awk '{ if (substr($0, length, 1) == "\\") { printf "%s", substr($0, 1, length-1); } else { print $0; } }' "${bastille_template}/Bastillefile" | grep -v '^[[:blank:]]*$' | grep -v '^[[:blank:]]*#')
        SKIP_ARGS=""

        # Use a newline as the separator. -- cwells
        IFS='
'
        set -f
        for line in ${SCRIPT}; do

            # First word converted to lowercase is the Bastille command. -- cwells
            cmd=$(echo "${line}" | awk '{print tolower($1);}')

            # Rest of the line with "arg" variables replaced will be the arguments. -- cwells
            args=$(echo "${line}" | awk -F '[ ]' '{$1=""; sub(/^ */, ""); print;}' | eval "sed ${ARG_REPLACEMENTS}")

			# Skip any args that don't have a value
            for arg in ${SKIP_ARGS}; do
                if echo "${line}" | grep -qo "\${${arg}}"; then
                    continue
                fi
            done

            # Apply overrides for commands/aliases and arguments. -- cwells
            case $cmd in
                arg+)
                    arg_name=$(get_arg_name "${args}")
                    arg_value=$(get_arg_value "${args}" "$@")
                    if [ -z "${arg_value}" ]; then
                        error_exit "[ERROR]: No value provided for mandatory arg: ${arg_name}"
                    else
                        ARG_REPLACEMENTS="${ARG_REPLACEMENTS} -e 's/\${${arg_name}}/${arg_value}/g'"
                    fi
                    continue
                    ;;
                arg)
                    arg_name=$(get_arg_name "${args}")
                    arg_value=$(get_arg_value "${args}" "$@")
                    if [ -z "${arg_value}" ]; then
                        warn 1 "[WARNING]: No value provided for arg: ${arg_name}"
                        SKIP_ARGS=$(printf '%s\n%s' "${SKIP_ARGS}" "${arg_name}")
                    else
                        ARG_REPLACEMENTS="${ARG_REPLACEMENTS} -e 's/\${${arg_name}}/${arg_value}/g'"
                    fi
                    continue
                    ;;
                cmd)
                    # Escape single-quotes in the command being executed. -- cwells
                    args=$(echo "${args}" | sed "s/'/'\\\\''/g")
                    # Allow redirection within the jail. -- cwells
                    # shellcheck disable=SC2089
                    args="sh -c '${args}'"
                    ;;
                cp|copy)
                    cmd='cp'
                    # Convert relative "from" path into absolute path inside the template directory. -- cwells
                    if [ "${args%"${args#?}"}" != '/' ] && [ "${args%"${args#??}"}" != '"/' ]; then
                        args="${bastille_template}/${args}"
                    fi
                    ;;
                fstab|mount)
                    cmd='mount' ;;
                include)
                    cmd='template' ;;
                overlay)
                    cmd='cp'
                    args="${bastille_template}/${args} /"
                    ;;
                pkg)
                    args="install -y ${args}"
                    ;;
                tag|tags)
                    cmd='tags'
                    # shellcheck disable=SC2090
                    args="add $(echo ${args} | tr ' ' ,)"
                    ;;
                render) # This is a path to one or more files needing arguments replaced by values. -- cwells
                    render "${bastille_jail_path}" "${args}"
                    continue
                    ;;
                lif|lineinfile|line_in_file)
                    line_in_file "${bastille_jail_path}" "${args}"
                    continue
                    ;;
            esac

            if ! eval "bastille ${cmd} ${jail} ${args}"; then
                set +f
                unset IFS
                error_exit "[ERROR]: Failed to execute command: ${cmd}"
            fi

            post_command_hook "${jail}" "${cmd}" "${args}"
        done
        set +f
        unset IFS
    fi

    info 1 "\nTemplate applied: ${TEMPLATE}"
done
