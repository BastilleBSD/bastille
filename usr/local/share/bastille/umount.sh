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
    error_notify "Usage: bastille umount [option(s)] TARGET JAIL_PATH"
    cat << EOF
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.

EOF
    exit 1
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
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\""
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 2 ]; then
    usage
fi

TARGET="${1}"
MOUNT_PATH="${2}"

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do

    info "[${_jail}]:"

    check_target_is_running "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    else
        error_notify "Jail is not running."
        error_exit "Use [-a|--auto] to auto-start the jail."
    fi

    _jailpath="$( echo "${bastille_jailsdir}/${_jail}/root/${MOUNT_PATH}" 2>/dev/null | sed 's#//#/#' | sed 's#\\##g')"
    _mount="$( mount | grep -Eo "[[:blank:]]${_jailpath}[[:blank:]]" )"
    _jailpath_fstab="$(echo "${bastille_jailsdir}/${_jail}/root/${MOUNT_PATH}" | sed 's#//#/#g' | sed 's# #\\#g' | sed 's#\\#\\\\040#g')"
    _fstab_entry="$(grep -Eo "[[:blank:]]${_jailpath_fstab}[[:blank:]]" ${bastille_jailsdir}/${_jail}/fstab)"

    # Exit if mount point non-existent
    if [ -z "${_mount}" ] && [ -z "${_fstab_entry}" ]; then
        error_continue "The specified mount point does not exist."
    fi

    # Unmount
    if [ -n "${_mount}" ]; then
        umount "${_jailpath}" || error_continue "Failed to unmount volume: ${MOUNT_PATH}"
    fi

    # Remove entry from fstab
    if [ -n "${_fstab_entry}" ]; then
        if ! sed -E -i '' "\, +${_jailpath_fstab} +,d" "${bastille_jailsdir}/${_jail}/fstab"; then
            error_continue "Failed to delete fstab entry: ${MOUNT_PATH}"
        fi
    fi

    # Delete if mount point was a file
    if [ -f "${_jailpath}" ]; then
        rm -f "${_jailpath}" || error_continue "Failed to unmount volume: ${MOUNT_PATH}"
    fi
    
    echo "Unmounted: ${_jailpath}"
	
done
