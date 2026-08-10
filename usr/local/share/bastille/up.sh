#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2026, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille up [option(s)]"
    cat << EOF
	
    Options:

    -d | --data-path PATH     Override path to persistent data (OCI only).

EOF
    exit 1
}

# Handle options
OPT_DATA_PATH=""
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -d|--data-path)
            OPT_DATA_PATH="${2}"
            if [ ! -d "${OPT_DATA_PATH}" ]; then
                error_exit "[ERROR]: Invalid path: ${OPT_DATA_PATH}"
            fi
            shift 2
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
if [ $# -ne 0 ]; then
    usage
fi

FILE="${PWD}/podman-compose.yml"
COMPOSE_CONF="${PWD}/bastille-compose.conf"
ENV_FILE="${PWD}/.env"

# Validate file existence
if [ ! -f "${FILE}" ]; then
    error_exit "[ERROR]: File not found: ${FILE}"
fi

indent_count() {

    local line="${1}"
    local indent="$(printf "%s" "${line}" | sed 's/[^ ].*//' | wc -c)"

    printf "%s\n" "${indent}"
}

process_line() {

    local indent="${1}"
    local line="${2}"
    if echo "${line}" | grep -Eq '^[[:blank:]]*\-'; then
        local line="$(printf "%s\n" "${line}" | sed -e 's/^[[:blank:]]*-[[:blank:]]*//g' -e 's/^[[:blank:]]*//g' -e 's/[[:blank:]]*#.*//g')"
        if echo "${line}" | grep -q ':'; then
            local option="$(printf "%s\n" "${line}" | sed 's/:/ /g' | awk '{print $1}')"
            local value="$(printf "%s\n" "${line}" | sed 's/:/ /g' | awk '{print $2}')"
        elif echo "${line}" | grep -q '='; then
            local option="$(printf "%s\n" "${line}" | sed 's/=/ /g' | awk '{print $1}')"
            local value="$(printf "%s\n" "${line}" | sed 's/=/ /g' | awk '{print $2}')"
        else
            local option="$(printf "%s\n" "${line}")"
            local value="$(printf "%s\n" "${line}")"
        fi
    else
        local line="$(printf "%s\n" "${line}" | sed -e 's/^[[:blank:]]*-[[:blank:]]*//g' -e 's/^[[:blank:]]*//g' -e 's/[[:blank:]]*#.*//g')"
        local option="$(printf "%s\n" "${line}" | awk -F":" '{print $1}')"
        local value="$(printf "%s\n" "${line}" | awk -F": " '{print $2}')"
    fi

    case ${indent} in
        *0)
            :
            ;;
        *2)
            #if [ -z "${SERVICE}" ]; then
            SERVICE="${option}"
            echo "service=${SERVICE}" >> "${COMPOSE_CONF}"
            #elif [ "${LAST_INDENT}" -gt 2 ]; then
            #    SERVICE="${option}"
            #fi
            ;;            
        *4)
            SERVICE_OPTION="${option}"
            if [ -n "${value}" ]; then
                SERVICE_VALUE="${value}"
                echo "${SERVICE}_${SERVICE_OPTION}=${SERVICE_VALUE}" >> "${COMPOSE_CONF}"
            fi
            ;;
        *6)
            SERVICE_VALUE_HOST="${option}"
            SERVICE_VALUE_JAIL="${value}"
            if [ "${SERVICE_VALUE_HOST}" = "${SERVICE_VALUE_JAIL}" ]; then
                echo "${SERVICE}_${SERVICE_OPTION}=${SERVICE_VALUE_HOST}" >> "${COMPOSE_CONF}"
            elif [ -n "${SERVICE_VALUE_HOST}" ] && [ -n "${SERVICE_VALUE_JAIL}" ]; then
                echo "${SERVICE}_${SERVICE_OPTION}=${SERVICE_VALUE_HOST}:${SERVICE_VALUE_JAIL}" >> "${COMPOSE_CONF}"
            fi
            ;;
    esac                        
}

: > "${COMPOSE_CONF}"
while IFS= read -r line; do
    if echo "${line}" | grep -Eq '^[[:space:]]*#'; then
        continue
    fi
    indent="$(indent_count "${line}")"
    process_line "${indent}" "${line}" 
done < "${FILE}"

if [ -f "${ENV_FILE}" ]; then
    while IFS= read -r line; do
        if printf "%s\n" "${line}" | grep -Eq '^[[:blank:]]*(#|$)'; then
            continue
        fi
        line="$(printf "%s\n" "${line}" | sed -e 's/^[[:blank:]]*//g' -e 's/[[:blank:]]*#.*//g')"
        name="$(printf "%s\n" "${line}" | cut -d= -f1)"
        value="$(printf "%s\n" "${line}" | cut -d= -f2-)"
        sed -i '' "s%\${${name}}%${value}%g" "${COMPOSE_CONF}"
    done < "${ENV_FILE}"
fi

for service in $(grep -E "^service=" "${COMPOSE_CONF}" | cut -d= -f2-); do
    jail_name="$(grep -E "^${service}_container_name" "${COMPOSE_CONF}" | cut -d= -f2-)"
    ip="$(grep -E "^${service}_network_mode" "${COMPOSE_CONF}" | cut -d= -f2-)"
    if [ "${ip}" = "host" ] || [ -z "${ip}" ]; then
        ip="inherit"
    fi
    cmd="bastille create -O"
    for var in $(grep -E "^${service}_environment" "${COMPOSE_CONF}" | cut -d= -f2-); do
        var="$(printf "%s" "${var}" | sed -e 's/:/=/' -e 's/\"//g')"
        cmd="$(printf "%s %s %s" "${cmd}" "--env" "${var}")"
    done
    if [ -n "${OPT_DATA_PATH}" ]; then
        cmd="$(printf "%s %s %s" "${cmd}" "--data-path" "${OPT_DATA_PATH}")"
    fi
    cmd="$(printf "%s %s" "${cmd}" "${jail_name}")"
    cmd="$(printf "%s %s" "${cmd}" "$(grep -E "^${service}_image" "${COMPOSE_CONF}" | cut -d= -f2-)")"
    cmd="$(printf "%s %s" "${cmd}" "${ip}")"

    eval "${cmd}" || exit 1

    # RDR
    if [ "${ip}" != "inherit" ] && ! route -n get "${ip}" | grep "gateway" >/dev/null 2>/dev/null; then
        if grep -Eq "^${service}_ports" "${COMPOSE_CONF}"; then
            for port in $(grep -E "^${service}_ports" "${COMPOSE_CONF}" | cut -d= -f2- | sed 's/\"//g'); do
                host_port="$(echo "${port}" | awk -F":" '{print $1}')"
                jail_port="$(echo "${port}" | awk -F":" '{print $2}')"
                bastille rdr "${jail_name}" tcp "${host_port}" "${jail_port}"
            done
        fi
    fi

    # Depend
    if grep -Eq "^${service}_depends_on" "${COMPOSE_CONF}"; then
        REQUIRE_START="${REQUIRE_START} ${jail_name}"
        bastille stop "${jail_name}"
        for depend_service in $(grep -E "^${service}_depends_on" "${COMPOSE_CONF}" | cut -d= -f2- | sed 's/\"//g'); do
            depend_jail="$(grep -E "^${depend_service}_container_name" "${COMPOSE_CONF}" | cut -d= -f2-)"
            sysrc -f "${bastille_jailsdir}/${jail_name}/settings.conf" depend+="${depend_jail}"
        done
    fi
done

for jail in ${REQUIRE_START}; do
    bastille start "${jail}"
done
