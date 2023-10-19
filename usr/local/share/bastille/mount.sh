#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille mount TARGET host_path container_path [filesystem_type options dump pass_number]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -lt 2 ]; then
    usage
elif [ $# -eq 2 ]; then
    _fstab="$@ nullfs ro 0 0"
else
    _fstab="$@"
fi

bastille_root_check

## assign needed variables
_hostpath=$(echo "${_fstab}" | awk '{print $1}')
_jailpath=$(echo "${_fstab}" | awk '{print $2}')
_type=$(echo "${_fstab}" | awk '{print $3}')
_perms=$(echo "${_fstab}" | awk '{print $4}')
_checks=$(echo "${_fstab}" | awk '{print $5" "$6}')

## if any variables are empty, bail out
if [ -z "${_hostpath}" ] || [ -z "${_jailpath}" ] || [ -z "${_type}" ] || [ -z "${_perms}" ] || [ -z "${_checks}" ]; then
    error_notify "FSTAB format not recognized."
    warn "Format: /host/path jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    exit 1
fi

## if host path doesn't exist, type is not "nullfs" or are using advanced mount type "tmpfs,linprocfs,linsysfs, fdescfs, procfs"	
if [ "${_hostpath}" == "tmpfs" -a "$_type" == "tmpfs" ] || [ "${_hostpath}" == "linprocfs" -a "${_type}" == "linprocfs" ] || [ "${_hostpath}" == "linsysfs" -a "${_type}" == "linsysfs" ] || [ "${_hostpath}" == "proc" -a "${_type}" == "procfs" ] || [ "${_hostpath}" == "fdesc" -a "${_type}" == "fdescfs" ]  ;  then
    warn "Detected advanced mount type ${_hostpath}"
elif [ ! -d "${_hostpath}" ] || [ "${_type}" != "nullfs" ]; then
    error_notify "Detected invalid host path or incorrect mount type in FSTAB."
    warn "Format: /host/path jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    exit 1
fi

## if mount permissions are not "ro" or "rw"
if [ "${_perms}" != "ro" ] && [ "${_perms}" != "rw" ]; then
    error_notify "Detected invalid mount permissions in FSTAB."
    warn "Format: /host/path jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    exit 1
fi

## if check & pass are not "0 0 - 1 1"; bail out
if [ "${_checks}" != "0 0" ] && [ "${_checks}" != "1 0" ] && [ "${_checks}" != "0 1" ] && [ "${_checks}" != "1 1" ]; then
    error_notify "Detected invalid fstab options in FSTAB."
    warn "Format: /host/path jail/path nullfs ro 0 0"
    warn "Read: ${_fstab}"
    exit 1
fi

for _jail in ${JAILS}; do
    info "[${_jail}]:"

    ## aggregate variables into FSTAB entry
    _fullpath="${bastille_jailsdir}/${_jail}/root/${_jailpath}"
    _fstab_entry="${_hostpath} ${_fullpath} ${_type} ${_perms} ${_checks}"

    ## Create mount point if it does not exist. -- cwells
    if [ ! -d "${_fullpath}" ]; then
        if ! mkdir -p "${_fullpath}"; then
            error_exit "Failed to create mount point inside jail."
        fi
    fi

    ## if entry doesn't exist, add; else show existing entry
    if ! egrep -q "[[:blank:]]${_fullpath}[[:blank:]]" "${bastille_jailsdir}/${_jail}/fstab" 2> /dev/null; then
        if ! echo "${_fstab_entry}" >> "${bastille_jailsdir}/${_jail}/fstab"; then
            error_exit "Failed to create fstab entry: ${_fstab_entry}"
        fi
        echo "Added: ${_fstab_entry}"
    else
        warn "Mountpoint already present in ${bastille_jailsdir}/${_jail}/fstab"
        egrep "[[:blank:]]${_fullpath}[[:blank:]]" "${bastille_jailsdir}/${_jail}/fstab"
    fi
    mount -F "${bastille_jailsdir}/${_jail}/fstab" -a
    echo
done
