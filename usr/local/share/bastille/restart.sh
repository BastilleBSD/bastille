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
    error_notify "Usage: bastille restart [option(s)] TARGET"
    cat << EOF

    Options:

    -b | --boot            Respect jail boot setting.
    -d | --delay VALUE     Time (seconds) to wait after starting each jail.
    -i | --ignore          Ignore stopped jails (do not start if stopped).
    -v | --verbose         Enable verbose mode.
    -x | --debug           Enable debug mode.

EOF
    exit 1
}

# Handle options.
# We pass these to start and stop.
start_options=""
stop_options=""
IGNORE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -b|--boot)
            start_options="${start_options} -b"
            shift
            ;;
        -d|--delay)
            start_options="${start_options} -d ${2}"
            shift 2
            ;;
        -i|--ignore)
            IGNORE=1
            shift
            ;;
        -v|--verbose)
            start_options="${start_options} -v"
            stop_options="${stop_options} -v"
            shift
            ;;
        -x|--debug)
            start_options="${start_options} -x"
            stop_options="${stop_options} -x"
            shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    b) start_options="${start_options} -b" ;;
                    i) IGNORE=1 ;;
                    v) start_options="${start_options} -v" stop_options="${stop_options} -v" ;;
                    x) start_options="${start_options} -x" stop_options="${stop_options} -x" ;;
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

if [ "$#" -ne 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check
set_target "${TARGET}"

for jail in ${JAILS}; do

    # Restart all jails except if --ignore
    if [ "${IGNORE}" -eq 0 ]; then
        bastille stop ${stop_options} ${jail}
        bastille start ${start_options} ${jail}
    elif [ "${IGNORE}" -eq 1 ]; then
        if check_target_is_stopped "${jail}"; then
            info "\n[${jail}]:"
            error_continue "Jail is stopped."
        fi
    fi

done