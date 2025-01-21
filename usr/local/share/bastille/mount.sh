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
    error_notify "Usage: bastille mount [option(s)] TARGET HOST_PATH JAIL_PATH [filesystem_type options dump pass_number]"
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
            error_exit "Unknown Option."
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 3 ] || [ "$#" -gt 7 ]; then
    usage
fi

TARGET="${1}"
shift

if [ "$#" -eq 2 ]; then
    _fstab="$(echo "$* nullfs ro 0 0" | sed 's#\\ #\\040#g')"
else
    _fstab="$(echo "$*" | sed 's#\\ #\\040#g')"
fi

bastille_root_check
set_target "${TARGET}"

# Assign variables
_hostpath_fstab=$(echo "${_fstab}" | awk '{print $1}')
_hostpath="$(echo "${_hostpath_fstab}" 2>/dev/null | sed 's#\\040# #g')"
_jailpath_fstab=$(echo "${_fstab}" | awk '{print $2}')
_jailpath="$(echo "${_jailpath_fstab}" 2>/dev/null | sed 's#\\040# #g')"
_type=$(echo "${_fstab}" | awk '{print $3}')
_perms=$(echo "${_fstab}" | awk '{print $4}')
_checks=$(echo "${_fstab}" | awk '{print $5" "$6}')

# Exit if any variables are empty
if [ -z "${_hostpath}" ] || [ -z "${_jailpath}" ] || [ -z "${_type}" ] || [ -z "${_perms}" ] || [ -z "${_checks}" ]; then
    error_notify "FSTAB format not recognized."
    warn "Format: /host/path /jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    usage
fi

# Exit if host path doesn't exist, type is not "nullfs", or mount is an advanced mount type "tmpfs,linprocfs,linsysfs,fdescfs,procfs"
if { [ "${_hostpath}" = "tmpfs" ] && [ "$_type" = "tmpfs" ]; } || \
   { [ "${_hostpath}" = "linprocfs" ] && [ "${_type}" = "linprocfs" ]; } || \
   { [ "${_hostpath}" = "linsysfs" ] && [ "${_type}" = "linsysfs" ]; } || \
   { [ "${_hostpath}" = "proc" ] && [ "${_type}" = "procfs" ]; } || \
   { [ "${_hostpath}" = "fdesc" ] && [ "${_type}" = "fdescfs" ]; } then
    warn "Detected advanced mount type ${_hostpath}"
elif [ ! -e "${_hostpath}" ] || [ "${_type}" != "nullfs" ]; then
    error_notify "Invalid host path or incorrect mount type in FSTAB."
    warn "Format: /host/path /jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    usage
fi

# Mount permissions,options must include one of "ro, rw, rq, sw, xx"
if ! echo "${_perms}" | grep -Eq '(ro|rw|rq|sw|xx)(,.*)?$'; then
    error_notify "Detected invalid mount permissions in FSTAB."
    warn "Format: /host/path /jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    usage
fi

# Dump and pass need to be "0 0 - 1 1"
if [ "${_checks}" != "0 0" ] && [ "${_checks}" != "1 0" ] && [ "${_checks}" != "0 1" ] && [ "${_checks}" != "1 1" ]; then
    error_notify "Detected invalid fstab options in FSTAB."
    warn "Format: /host/path /jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    usage
fi

for _jail in ${JAILS}; do

    info "[${_jail}]:"

    _fullpath_fstab="$( echo "${bastille_jailsdir}/${_jail}/root/${_jailpath_fstab}" 2>/dev/null | sed 's#//#/#' )"
    _fullpath="$( echo "${bastille_jailsdir}/${_jail}/root/${_jailpath}" 2>/dev/null | sed 's#//#/#' )"
    _fstab_entry="${_hostpath_fstab} ${_fullpath_fstab} ${_type} ${_perms} ${_checks}"

    # Check if mount point has already been added
    _existing_mount="$(echo ${_fullpath_fstab} 2>/dev/null | sed 's#\\#\\\\#g')"
    if grep -Eq "[[:blank:]]${_existing_mount}[[:blank:]]" "${bastille_jailsdir}/${_jail}/fstab"; then
        warn "Mountpoint already present in ${bastille_jailsdir}/${_jail}/fstab"
        grep -E "[[:blank:]]${_existing_mount}" "${bastille_jailsdir}/${_jail}/fstab"
        continue
    fi


    # Create mount point if it does not exist
    if [ -d "${_hostpath}" ] && [ ! -d "${_fullpath}" ]; then
        mkdir -p "${_fullpath}" || error_continue "Failed to create mount point."
    elif [ -f "${_hostpath}" ] ; then
        _filename="$( basename ${_hostpath} )"
        if  echo "${_fullpath}" 2>/dev/null | grep -qow "${_filename}"; then
            mkdir -p "$( dirname "${_fullpath}" )" || error_continue "Failed to create mount point."
            if [ ! -f "${_fullpath}" ]; then
                touch "${_fullpath}" || error_continue "Failed to create mount point."
            else
                error_notify "Failed. File exists at mount point."
                warn "${_fullpath}"
                continue
            fi
        else
            _fullpath_fstab="$( echo "${bastille_jailsdir}/${_jail}/root/${_jailpath_fstab}/${_filename}" 2>/dev/null | sed 's#//#/#' )"
            _fullpath="$( echo "${bastille_jailsdir}/${_jail}/root/${_jailpath}/${_filename}" 2>/dev/null | sed 's#//#/#' )"
            _fstab_entry="${_hostpath_fstab} ${_fullpath_fstab} ${_type} ${_perms} ${_checks}"
            mkdir -p "$( dirname "${_fullpath}" )" || error_continue "Failed to create mount point."
            if [ ! -f "${_fullpath}" ]; then
                touch "${_fullpath}" || error_continue "Failed to create mount point."
            else
                error_notify "Failed. File exists at mount point."
                warn "${_fullpath}"
                continue
            fi
        fi
    fi   
    
    # Add entry to fstab and mount
    echo "${_fstab_entry}" >> "${bastille_jailsdir}/${_jail}/fstab" || error_continue "Failed to create fstab entry: ${_fstab_entry}"
    mount -F "${bastille_jailsdir}/${_jail}/fstab" -a || error_continue "Failed to mount volume: ${_fullpath}"
    echo "Added: ${_fstab_entry}"
done
