#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2026, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
# Ressource limits added by Sven R github.com/hackacad
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
    error_notify "Usage: bastille logs [option(s)] TARGET oci|console"
    cat << EOF

    Options:

    -f | --full     Show full logs.
    -l | --live     Show live logs.

EOF
    exit 1
}

# Handle options
OPT_FULL=0
OPT_LIVE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -f|--full)
            OPT_FULL=1
            shift
            ;;
        -l|--live)
            OPT_LIVE=1
            shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    f) OPT_FULL=1 ;;
                    l) OPT_LIVE=1 ;;
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

# Verify parameter count
if [ "$#" -ne 2 ]; then
    usage
fi

TARGET="${1}"
LOG_TYPE="${2}"

bastille_root_check
set_target_single "${TARGET}"

# Validate options
if [ "${OPT_FULL}" -eq 1 ] && [ "${OPT_LIVE}" -eq 1 ]; then
    error_exit "[ERROR]: [-f|--full] and [-l|--live] cannot be used together."
elif ! echo "${LOG_TYPE}" | grep -Eoq '^(oci|console)$'; then
    error_exit "[ERROR]: Invalid log type: ${LOG_TYPE}"
fi

show_full_log() {

    local jail="${1}"
    local log_file="${bastille_logsdir}/${jail}/${LOG_TYPE}.log"

    if [ ! -f "${log_file}" ]; then
        error_exit "[ERROR]: File not found: ${log_file}"
    else
        cat "${log_file}"
    fi
}

show_tail_log() {

    local jail="${1}"
    local log_file="${bastille_logsdir}/${jail}/${LOG_TYPE}.log"

    if [ ! -f "${log_file}" ]; then
        error_exit "[ERROR]: File not found: ${log_file}"
    else
        tail "${log_file}"
    fi
}

show_live_log() {

    local jail="${1}"
    local log_file="${bastille_logsdir}/${jail}/${LOG_TYPE}.log"

    if [ ! -f "${log_file}" ]; then
        error_exit "[ERROR]: File not found: ${log_file}"
    else
        tail -f "${log_file}"
    fi
}

# Main functions
if [ "${OPT_FULL}" -eq 1 ]; then
    show_full_log "${TARGET}"
elif [ "${OPT_LIVE}" -eq 1 ]; then
    show_live_log "${TARGET}"
else
    show_tail_log "${TARGET}"
fi