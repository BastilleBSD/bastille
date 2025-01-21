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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_notify "Usage: bastille cp [option(s)] TARGET SOURCE DESTINATION"
    cat << EOF
    Options:

    -j | --jail             Jail mode. Copy files from jail to jail(s).
                            Syntax: [-j jail:srcpath jail:dstpath]
    -r | --reverse          Reverse copy files from jail to host.
    -q | --quiet            Suppress output.
    -x | --debug            Enable debug mode.

EOF
    exit 1
}

# Handle options.
JAIL_MODE=0
OPTION="-av"
REVERSE_MODE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
	-h|--help|help)
	    usage
	    ;;
        -j|--jail)
            JAIL_MODE=1
            shift
            ;;
        -r|--reverse)
            REVERSE_MODE=1
            shift
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
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    j) JAIL_MODE=1 ;;
                    r) REVERSE_MODE=1 ;;
                    q) OPTION="-a" ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\"" ;; 
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

if [ "${JAIL_MODE}" -eq 1 ] && [ "${REVERSE_MODE}" -eq 1 ]; then
    error_exit "[-j|--jail] cannot be used with [-r|reverse]"
fi

if [ "${JAIL_MODE}" -eq 1 ]; then
    SOURCE_TARGET="$(echo ${1} | awk -F":" '{print $1}')"
    SOURCE_PATH="$(echo ${1} | awk -F":" '{print $2}')"
    DEST_TARGET="$(echo ${2} | awk -F":" '{print $1}')"
    DEST_PATH="$(echo ${2} | awk -F":" '{print $2}')"
    set_target_single "${SOURCE_TARGET}" && SOURCE_TARGET="${TARGET}"
    set_target "${DEST_TARGET}" && DEST_TARGET="${JAILS}"
    for _jail in ${DEST_TARGET}; do
        if [ "${_jail}" = "${SOURCE_TARGET}" ]; then
            continue
        fi
        info "[${_jail}]:"
        source_path="$(echo ${bastille_jailsdir}/${SOURCE_TARGET}/root/${SOURCE_PATH} | sed 's#//#/#g')"
        dest_path="$(echo ${bastille_jailsdir}/${_jail}/root/${DEST_PATH} | sed 's#//#/#g')"
        if ! cp "${OPTION}" "${source_path}" "${dest_path}"; then
            error_continue "CP failed: ${source_path} -> ${dest_path}"
        fi
    done
    exit
fi

TARGET="${1}"
SOURCE="${2}"
DEST="${3}"

bastille_root_check

if [ "${REVERSE_MODE}" -eq 1 ]; then
    set_target_single "${TARGET}"
    for _jail in ${JAILS}; do
        info "[${_jail}]:"
        host_path="${DEST}"
        jail_path="$(echo ${bastille_jailsdir}/${_jail}/root/${SOURCE} | sed 's#//#/#g')"
        if ! cp "${OPTION}" "${jail_path}" "${host_path}"; then
            error_exit "RCP failed: ${jail_path} -> ${host_path}"
        fi
    done
else
    set_target "${TARGET}"
    for _jail in ${JAILS}; do
        info "[${_jail}]:"
        host_path="${SOURCE}"
        jail_path="$(echo ${bastille_jailsdir}/${_jail}/root/${DEST} | sed 's#//#/#g')"
        if ! cp "${OPTION}" "${host_path}" "${jail_path}"; then
            error_continue "CP failed: ${host_path} -> ${jail_path}"
        fi
    done
fi
