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
    error_notify "Usage: bastille jcp [option(s)] SOURCE_JAIL JAIL_PATH DESTINATION_JAIL JAIL_PATH"
    cat << EOF

    Options:

    -q | --quiet     Suppress output.
    -x | --debug     Enable debug mode.

EOF
    exit 1
}

# Handle options.
OPTION="-av"
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -q|--quiet)
            OPTION="-a"
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    q) OPTION="-a" ;;
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

if [ "$#" -ne 4 ]; then
    usage
fi

SOURCE_TARGET="${1}"
SOURCE_PATH="${2}"
DEST_TARGET="${3}"
DEST_PATH="${4}"
ERRORS=0

bastille_root_check
set_target_single "${SOURCE_TARGET}" && SOURCE_TARGET="${TARGET}"
set_target "${DEST_TARGET}" && DEST_TARGET="${JAILS}"

for jail in ${DEST_TARGET}; do

    if [ "${jail}" = "${SOURCE_TARGET}" ]; then
        continue
    else

	info "\n[${jail}]:"

        source_path="$(echo ${bastille_jailsdir}/${SOURCE_TARGET}/root/${SOURCE_PATH} | sed 's#//#/#g')"
        dest_path="$(echo ${bastille_jailsdir}/${jail}/root/${DEST_PATH} | sed 's#//#/#g')"

        if ! cp "${OPTION}" "${source_path}" "${dest_path}"; then
            ERRORS=$((ERRORS + 1))
            error_continue "[ERROR]: JCP failed: ${source_path} -> ${dest_path}"
        fi

    fi

done

if [ "${ERRORS}" -ne 0 ]; then
    error_exit "[ERROR]: Command failed on ${ERRORS} jails."
fi