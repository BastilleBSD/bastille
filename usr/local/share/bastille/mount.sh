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
    error_exit "Usage: bastille mount TARGET HOST_PATH JAIL_PATH [filesystem_type options dump pass_number]"
}

# Handle special-case commands first.
case "${1}" in
    help|-h|--help)
        usage
        ;;
esac

if [ "$#" -lt 3 ]; then
    usage
fi

TARGET="${1}"
shift

if [ "$#" -eq 2 ]; then
    _fstab="$@ nullfs ro 0 0"
else
    _fstab="$@"
fi

bastille_root_check
set_target "${TARGET}"

# Assign variables
_hostpath=$(echo "${_fstab}" | awk '{print $1}')
_jailpath=$(echo "${_fstab}" | awk '{print $2}')
_type=$(echo "${_fstab}" | awk '{print $3}')
_perms=$(echo "${_fstab}" | awk '{print $4}')
_checks=$(echo "${_fstab}" | awk '{print $5" "$6}')

## Exit if any variables are empty
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

## Mount permission need to be "ro" or "rw"
if [ "${_perms}" != "ro" ] && [ "${_perms}" != "rw" ]; then
    error_notify "Detected invalid mount permissions in FSTAB."
    warn "Format: /host/path /jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    usage
fi

## Dump and pass need to be "0 0 - 1 1"
if [ "${_checks}" != "0 0" ] && [ "${_checks}" != "1 0" ] && [ "${_checks}" != "0 1" ] && [ "${_checks}" != "1 1" ]; then
    error_notify "Detected invalid fstab options in FSTAB."
    warn "Format: /host/path /jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    usage
fi

for _jail in ${JAILS}; do
    _fullpath="$( echo ${bastille_jailsdir}/${_jail}/root/${_jailpath} 2>/dev/null | sed 's#//#/#' )"
    _fstab_entry="${_hostpath} ${_fullpath} ${_type} ${_perms} ${_checks}"

    info "[${_jail}]:"

    ## Create mount point if it does not exist
    if [ -d "${_hostpath}" ] && [ ! -d "${_fullpath}" ]; then
        mkdir -p "${_fullpath}" || error_exit "Failed to create mount point inside jail."
    elif [ -f "${_hostpath}" ] && [ ! -f "${_fullpath}" ]; then
        mkdir -p "$( dirname ${_fullpath} )" || error_exit "Failed to create mount point inside jail."
        touch "${_fullpath}" || error_exit "Failed to create mount point inside jail."
    fi    
    
    ## If entry doesn't exist, add, else show existing entry
    if ! grep -Eq "[[:blank:]]${_fullpath}[[:blank:]]" "${bastille_jailsdir}/${_jail}/fstab" 2> /dev/null; then
        if ! echo "${_fstab_entry}" >> "${bastille_jailsdir}/${_jail}/fstab"; then
            error_exit "Failed to create fstab entry: ${_fstab_entry}"
        fi
        echo "Added: ${_fstab_entry}"
    else
        warn "Mountpoint already present in ${bastille_jailsdir}/${_jail}/fstab"
        grep -E "[[:blank:]]${_fullpath}[[:blank:]]" "${bastille_jailsdir}/${_jail}/fstab"
    fi
    mount -F "${bastille_jailsdir}/${_jail}/fstab" -a
done
