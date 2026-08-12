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

# Target resolution helpers.

get_jail_name() {
    local jid="${1}"
    local jail_name="$(jls -j ${jid} name 2>/dev/null)"
    if [ -z "${jail_name}" ]; then
        return 1
    else
        echo "${jail_name}"
    fi
}

jail_autocomplete() {
    local target="${1}"
    local jail_list="$(bastille list jails)"
    local auto_target="$(echo "${jail_list}" | grep -E "^${target}")"
    if [ -n "${auto_target}" ]; then
        if [ "$(echo "${auto_target}" | wc -l)" -eq 1 ]; then
            echo "${auto_target}"
        else
            error_continue "[ERROR]: Multiple jails found for ${target}:\n${auto_target}"
            return 1
        fi
    else
        return 2
    fi
}

list_jail_priority() {
    local jail_list="${1}"
    if [ -d "${bastille_jailsdir}" ]; then
        for jail in ${jail_list}; do
            # Remove boot.conf in favor of settings.conf
            if [ -f ${bastille_jailsdir}/${jail}/boot.conf ]; then
                rm -f ${bastille_jailsdir}/${jail}/boot.conf >/dev/null 2>&1
            fi
            local settings_file=${bastille_jailsdir}/${jail}/settings.conf
            # Set defaults if settings file does not exist
            if [ ! -f ${settings_file} ]; then
                sysrc -f ${settings_file} boot=on >/dev/null 2>&1
                sysrc -f ${settings_file} depend="" >/dev/null 2>&1
                sysrc -f ${settings_file} priority=99 >/dev/null 2>&1
            fi
            # Add defaults if they dont exist
            if ! grep -oq "boot=" ${settings_file}; then
                sysrc -f ${settings_file} boot=on >/dev/null 2>&1
            fi
            if ! grep -oq "depend=" ${settings_file}; then
                sysrc -f ${settings_file} depend="" >/dev/null 2>&1
            fi
            if ! grep -oq "priority=" ${settings_file}; then
                sysrc -f ${settings_file} priority=99 >/dev/null 2>&1
            fi
            priority="$(sysrc -f ${settings_file} -n priority)"
            echo "${jail} ${priority}"
        done
    fi
}

set_target() {
    local target=${1}
    if [ "${2}" = "reverse" ]; then
        local order="${2}"
    else
        local order="forward"
    fi
    JAILS=""
    TARGET=""
    if echo "${target}" | grep -Eq '^[aA][lL][lL]$'; then
        target_all_jails
    else
        for jail in ${target}; do
            if [ ! -d "${bastille_jailsdir}/${target}" ] && echo "${jail}" | grep -Eq '^[0-9]+$'; then
                if get_jail_name "${jail}" > /dev/null; then
                    jail="$(get_jail_name ${jail})"
                else
                    error_continue "[ERROR]: JID not found: ${jail}"
                fi
            elif ! check_target_exists "${jail}"; then
                if jail_autocomplete "${jail}" > /dev/null; then
                    jail="$(jail_autocomplete ${jail})"
                elif [ $? -eq 2 ]; then
                    if grep -Ehoqw ${jail} ${bastille_jailsdir}/*/tags 2>/dev/null; then
                        jail="$(grep -Elw ${jail} ${bastille_jailsdir}/*/tags | awk -F"/tags" '{print $1}' | sed "s#${bastille_jailsdir}/##g" | tr '\n' ' ')"
                    else
                        error_continue "[ERROR]: Jail not found: ${jail}"
                    fi
                else
                    echo
                    exit 1
                fi
            fi
            TARGET="${TARGET} ${jail}"
            JAILS="${JAILS} ${jail}"
        done
        # Exit if no jails
        if [ -z "${TARGET}" ] && [ -z "${JAILS}" ]; then
            exit 1
        fi
        if [ "${order}" = "forward" ]; then
            TARGET="$(list_jail_priority "${TARGET}" | sort -u | sort -k2 -n | awk '{print $1}')"
            JAILS="$(list_jail_priority "${TARGET}" | sort -u | sort -k2 -n | awk '{print $1}')"
        elif [ "${order}" = "reverse" ]; then
            TARGET="$(list_jail_priority "${TARGET}" | sort -u | sort -k2 -nr | awk '{print $1}')"
            JAILS="$(list_jail_priority "${TARGET}" | sort -u | sort -k2 -nr | awk '{print $1}')"
        fi
        export TARGET
        export JAILS
    fi
}

set_target_single() {
    local target="${1}"
    JAILS=""
    TARGET=""
    if echo "${target}" | grep -Eq '^[aA][lL][lL]$'; then
        error_exit "[ERROR]: [all|ALL] is not supported with this command."
    elif [ "$(echo ${target} | wc -w)" -gt 1 ]; then
        error_exit "[ERROR]: Command only supports a single TARGET."
    elif [ ! -d "${bastille_jailsdir}/${target}" ] && echo "${target}" | grep -Eq '^[0-9]+$'; then
        if get_jail_name "${target}" > /dev/null; then
            target="$(get_jail_name ${target})"
        else
            error_exit "[ERROR]: JID not found: ${target}"
        fi
    elif ! check_target_exists "${target}"; then
            if jail_autocomplete "${target}" > /dev/null; then
                target="$(jail_autocomplete ${target})"
            elif [ $? -eq 2 ]; then
                error_exit "[ERROR]: Jail not found: ${target}"
            else
                echo
                exit 1
            fi
    fi
    TARGET="${target}"
    JAILS="${target}"
    # Exit if no jails
    if [ -z "${target}" ] && [ -z "${jails}" ]; then
        exit 1
    fi
    export TARGET
    export JAILS
}

target_all_jails() {
    local jails="$(bastille list jails)"
    JAILS=""
    for jail in ${jails}; do
        if [ -d "${bastille_jailsdir}/${jail}" ]; then
            JAILS="${JAILS} ${jail}"
        fi
    done
    # Exit if no jails
    if [ -z "${JAILS}" ]; then
        exit 1
    fi
    if [ "${order}" = "forward" ]; then
        JAILS="$(list_jail_priority "${JAILS}" | sort -k2 -n | awk '{print $1}')"
    elif [ "${order}" = "reverse" ]; then
        JAILS="$(list_jail_priority "${JAILS}" | sort -k2 -nr | awk '{print $1}')"
    fi
    export JAILS
}
