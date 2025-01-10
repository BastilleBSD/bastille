#!/bin/sh
#
# Copyright (c) 2018-2024, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille umount [option(s)] TARGET JAIL_PATH"
    cat << EOF
    Options:

    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
	-h|--help|help)
	    usage
	    ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            error_exit "Unknown option: \"${1}\""
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