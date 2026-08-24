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
    exit 1
}

# Handle options
OPT_DATA_PATH=""
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
if [ $# -ne 0 ]; then
    usage
fi

FILE="${PWD}/bastille-compose.yml"
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

    # Strip leading '-' character if present
    if echo "${line}" | grep -Eq '^[[:blank:]]*\-'; then
        local line="$(printf "%s\n" "${line}" | sed -e 's/^[[:blank:]]*-[[:blank:]]*//g' -e 's/^[[:blank:]]*//g' -e 's/[[:blank:]]*#.*//g')"
        if echo "${line}" | grep -q ':'; then
            local option="$(printf "%s\n" "${line}" | sed 's/:/ /g' | awk '{print $1}')"
            local value="$(printf "%s\n" "${line}" | sed 's/:/ /g' | awk '{print $2}')"
        else
            local option="$(printf "%s\n" "${line}")"
            local value="$(printf "%s\n" "${line}")"
        fi
    # Else line is 'opt: value'
    else
        local line="$(printf "%s\n" "${line}" | sed -e 's/^[[:blank:]]*-[[:blank:]]*//g' -e 's/^[[:blank:]]*//g' -e 's/[[:blank:]]*#.*//g')"
        local option="$(printf "%s\n" "${line}" | awk -F":" '{print $1}')"
        local value="$(printf "%s\n" "${line}" | awk -F": " '{print $2}')"
    fi

    case ${indent} in
        *0)
            case "${line}" in
                project*)
                    PROJECT_NAME="$(echo ${line} | awk -F": " '{print $2}')"
                    ;;
                services*)
                    PROJECT_SERVICES="$(grep '^  [^ ]' ${FILE} | sed -e 's/^[[:blank:]]*//g' -e 's/:.*$//g' | paste -sd ' ' -)"
                    ;;
                *)
                    :
                    ;;
            esac
            ;;
        *2)
            SERVICE="${option}"
            echo "${PROJECT_NAME}.service=${SERVICE}" >> "${COMPOSE_CONF}"
            ;;            
        *4)
            SERVICE_OPTION="${option}"
            SERVICE_VALUE="${value}"
            case "${SERVICE_OPTION}" in
                name|image|network|environment|volumes|ports|depend) ;;
                *) error_exit "[ERROR]: Invalid service option: ${SERVICE_OPTION}" ;;
            esac
            if [ -n "${SERVICE_VALUE}" ]; then 
                echo "${PROJECT_NAME}.${SERVICE}.${SERVICE_OPTION}=${SERVICE_VALUE}" >> "${COMPOSE_CONF}"
            fi
            ;;
        *6)
            LIST_OPTION="${option}"
            LIST_VALUE="${value}"
            case "${SERVICE_OPTION}" in
                name|image) ;;
                network)
                    case "${LIST_OPTION}" in
                        mode|ip|interface)
                            echo "${PROJECT_NAME}.${SERVICE}.${SERVICE_OPTION}.${LIST_OPTION}=${LIST_VALUE}" >> "${COMPOSE_CONF}"
                            ;;
                        *)
                            error_exit "[ERROR]: Invalid option for ${SERVICE_OPTION}: ${LIST_OPTION}"
                            ;;
                    esac
                    ;;
                environment)
                    echo "${PROJECT_NAME}.${SERVICE}.${SERVICE_OPTION}.${LIST_OPTION}=${LIST_VALUE}" >> "${COMPOSE_CONF}"
                    ;;
                volumes)
                    echo "${PROJECT_NAME}.${SERVICE}.${SERVICE_OPTION}.${LIST_OPTION}=${LIST_VALUE}" >> "${COMPOSE_CONF}"
                    ;;
                ports)
                    echo "${PROJECT_NAME}.${SERVICE}.${SERVICE_OPTION}.${LIST_OPTION}=${LIST_VALUE}" >> "${COMPOSE_CONF}"
                    ;;
                depend)
                    echo "${PROJECT_NAME}.${SERVICE}.${SERVICE_OPTION}=${LIST_OPTION}" >> "${COMPOSE_CONF}"
                    ;;
            esac
            ;;
        *)
            error_exit "[ERROR]: Invalid indentaion."
            ;;
    esac                        
}

# Process bastille-compose.yml
: > "${COMPOSE_CONF}"
while IFS= read -r line; do
    if printf '%s\n' "${line}" | grep -Eq '^[[:space:]]*#'; then
        continue
    fi
    indent="$(indent_count "${line}")"
    process_line "${indent}" "${line}" 
done < "${FILE}"

# Replace variable in generated bastille-compose.conf file
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

# Determine which services have 'depend' set
PROJECT_SERVICES_ORDER="${PROJECT_SERVICES}"
for service in ${PROJECT_SERVICES}; do
    depends="$(grep "^${PROJECT_NAME}\.${service}\.depend=" "${COMPOSE_CONF}" | cut -d= -f2)"
    for depend in ${depends}; do
        PROJECT_SERVICES_ORDER="$(printf '%s\n' "${PROJECT_SERVICES_ORDER}" | sed "s/${depend}//g")"
        PROJECT_SERVICES_ORDER="${depend} ${PROJECT_SERVICES_ORDER}"
    done
done

for service in ${PROJECT_SERVICES_ORDER}; do
    jail_name="$(grep -E "^${PROJECT_NAME}.${service}.name=" "${COMPOSE_CONF}" | cut -d= -f2-)"
    mode="$(grep -E "^${PROJECT_NAME}.${service}.network.mode=" "${COMPOSE_CONF}" | cut -d= -f2-)"
    ip="$(grep -E "^${PROJECT_NAME}.${service}.network.ip=" "${COMPOSE_CONF}" | cut -d= -f2-)"
    interface="$(grep -E "^${PROJECT_NAME}.${service}.network.interface=" "${COMPOSE_CONF}" | cut -d= -f2-)"
    if [ "${mode}" = "host" ] || [ "${mode}" = "inherit" ] || [ -z "${ip}" ]; then
        ip="inherit"
    fi
    cmd="bastille create -O"
    for var in $(grep -E "^${PROJECT_NAME}.${service}.environment" "${COMPOSE_CONF}"); do
        var="$(printf "%s" "${var}" | sed -e 's/.*environment.//' -e 's/\"//g')"
        cmd="$(printf "%s %s %s" "${cmd}" "--env" "${var}")"
    done
    if grep -Eq "^${PROJECT_NAME}.${service}.volumes" "${COMPOSE_CONF}"; then
        for vol in $(grep -E "^${PROJECT_NAME}.${service}.volumes" "${COMPOSE_CONF}"); do
            host_vol="$(printf "%s" "${vol}" | sed -e 's/.*volumes.//' -e 's/\"//g' | awk -F"=" '{print $1}')"
            jail_vol="$(printf "%s" "${vol}" | sed -e 's/.*volumes.//' -e 's/\"//g' | awk -F"=" '{print $2}')"
            cmd="$(printf "%s %s %s %s" "${cmd}" "--volume" ${host_vol} ${jail_vol})"
        done
    fi
    cmd="$(printf "%s %s" "${cmd}" "${jail_name}")"
    cmd="$(printf "%s %s" "${cmd}" "$(grep -E "^${PROJECT_NAME}.${service}.image" "${COMPOSE_CONF}" | cut -d= -f2-)")"
    cmd="$(printf "%s %s" "${cmd}" "${ip}")"
    [ -n "${interface}" ] && cmd="$(printf "%s %s" "${cmd}" "${interface}")"

    eval "${cmd}" || exit 1

    # RDR
    if [ "${mode}" = "nat" ]; then
        if grep -Eq "^${PROJECT_NAME}.${service}.ports" "${COMPOSE_CONF}"; then
            for port in $(grep -E "^${PROJECT_NAME}.${service}.ports" "${COMPOSE_CONF}"); do
                host_port="$(echo "${port}" | sed 's/.*ports.//' | awk -F"=" '{print $1}')"
                jail_port="$(echo "${port}" | sed 's/.*ports.//' | awk -F"=" '{print $2}')"
                bastille rdr "${jail_name}" tcp "${host_port}" "${jail_port}"
            done
        fi
    fi

    # Depend
    if grep -Eq "^${PROJECT_NAME}.${service}.depend=" "${COMPOSE_CONF}"; then
        for depend_service in $(grep -E "^${PROJECT_NAME}.${service}.depend=" "${COMPOSE_CONF}" | cut -d= -f2- | sed 's/\"//g'); do
            depend_jail="$(grep -E "^${PROJECT_NAME}.${depend_service}.name=" "${COMPOSE_CONF}" | cut -d= -f2-)"
            sysrc -f "${bastille_jailsdir}/${jail_name}/settings.conf" depend+="${depend_jail}"
        done
    fi
done