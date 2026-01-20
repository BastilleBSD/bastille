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
    error_notify "Usage: bastille mount [option(s)] TARGET HOST_PATH JAIL_PATH [FS_TYPE FS_OPTIONS DUMP PASS_NUMBER]"
    cat << EOF

    Options:

    -a | --auto      Auto mode. Start/stop jail(s) if required.
    -x | --debug     Enable debug mode.

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
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    a) AUTO=1 ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\""
                esac
            done
            shift
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
    fstab="$(echo "$* nullfs ro 0 0" | sed 's#\\ #\\040#g')"
else
    fstab="$(echo "$*" | sed 's#\\ #\\040#g')"
fi

bastille_root_check
set_target "${TARGET}"

# Assign variables
hostpath_fstab=$(echo "${fstab}" | awk '{print $1}')
hostpath="$(echo "${hostpath_fstab}" 2>/dev/null | sed 's#\\040# #g')"
jailpath_fstab=$(echo "${fstab}" | awk '{print $2}')
jailpath="$(echo "${jailpath_fstab}" 2>/dev/null | sed 's#\\040# #g')"
type=$(echo "${fstab}" | awk '{print $3}')
perms=$(echo "${fstab}" | awk '{print $4}')
checks=$(echo "${fstab}" | awk '{print $5" "$6}')

# Exit if any variables are empty
if [ -z "${hostpath}" ] || [ -z "${jailpath}" ] || [ -z "${type}" ] || [ -z "${perms}" ] || [ -z "${checks}" ]; then
    error_notify "FSTAB format not recognized."
    warn 1 "Format: /host/path /jail/path nullfs ro 0 0"
    warn 1 "Read: ${fstab}"
fi

# Warn on advanced mount option  "tmpfs,linprocfs,linsysfs,fdescfs,procfs,zfs"
# Create host path if non-existent
if { [ "${hostpath}" = "tmpfs" ] && [ "$_type" = "tmpfs" ]; } || \
   { [ "${hostpath}" = "linprocfs" ] && [ "${type}" = "linprocfs" ]; } || \
   { [ "${hostpath}" = "linsysfs" ] && [ "${type}" = "linsysfs" ]; } || \
   { [ "${hostpath}" = "proc" ] && [ "${type}" = "procfs" ]; } || \
   { [ "${hostpath}" = "fdesc" ] && [ "${type}" = "fdescfs" ]; } || \
   { [ "${type}" = "zfs" ] && zfs list ${hostpath} >/dev/null 2>/dev/null; } then
    warn 1 "\n[WARNING]: Detected advanced mount type: \"${type}\""
elif [ ! -e "${hostpath}" ] && [ "${type}" = "nullfs" ]; then
    mkdir -p "${hostpath}"
elif [ ! -e "${hostpath}" ] || [ "${type}" != "nullfs" ]; then
    error_notify "[ERROR]: Invalid host path or incorrect mount type in FSTAB."
    warn 1 "Format: /host/path /jail/path nullfs ro 0 0"
    warn 1 "Read: ${fstab}"
    exit 1
fi

# Mount permissions,options must include one of "ro, rw, rq, sw, xx"
if ! echo "${perms}" | grep -Eq '(ro|rw|rq|sw|xx)(,.*)?$'; then
    error_notify "Detected invalid mount permissions in FSTAB."
    warn 1 "Format: /host/path /jail/path nullfs ro 0 0"
    warn 1 "Read: ${fstab}"
    exit 1
fi

# Dump and pass need to be "0 0 - 1 1"
if [ "${checks}" != "0 0" ] && [ "${checks}" != "1 0" ] && [ "${checks}" != "0 1" ] && [ "${checks}" != "1 1" ]; then
    error_notify "Detected invalid fstab options in FSTAB."
    warn 1 "Format: /host/path /jail/path nullfs ro 0 0"
    warn 1 "Read: ${fstab}"
    exit 1
fi

for jail in ${JAILS}; do

    check_target_is_running "${jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${jail}"
    else
        info 1 "\n[${jail}]:"
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi

    info 1 "\n[${jail}]:"

    fullpath_fstab="$( echo "${bastille_jailsdir}/${jail}/root/${jailpath_fstab}" 2>/dev/null | sed 's#//#/#' )"
    fullpath="$( echo "${bastille_jailsdir}/${jail}/root/${jailpath}" 2>/dev/null | sed 's#//#/#' )"
    fstab_entry="${hostpath_fstab} ${fullpath_fstab} ${type} ${perms} ${checks}"

    # Check if mount point has already been added
    existing_mount="$(echo ${fullpath_fstab} 2>/dev/null | sed 's#\\#\\\\#g')"
    if grep -Eq "[[:blank:]]${existing_mount}[[:blank:]]" "${bastille_jailsdir}/${jail}/fstab"; then
        warn 1 "Mountpoint already present in ${bastille_jailsdir}/${jail}/fstab"
        grep -E "[[:blank:]]${existing_mount}" "${bastille_jailsdir}/${jail}/fstab"
        continue
    fi


    # Create mount point if it does not exist
    if { [ -d "${hostpath}" ] || [ "${type}" = "zfs" ]; } && [ ! -d "${fullpath}" ]; then
        mkdir -p "${fullpath}" || error_continue "Failed to create mount point."
    elif [ -f "${hostpath}" ] ; then
        filename="$( basename ${hostpath} )"
        if  echo "${fullpath}" 2>/dev/null | grep -qow "${filename}"; then
            mkdir -p "$( dirname "${fullpath}" )" || error_continue "Failed to create mount point."
            if [ ! -f "${fullpath}" ]; then
                touch "${fullpath}" || error_continue "Failed to create mount point."
            else
                error_notify "Failed. File exists at mount point."
                warn 1 "${fullpath}"
                continue
            fi
        else
            fullpath_fstab="$( echo "${bastille_jailsdir}/${jail}/root/${jailpath_fstab}/${filename}" 2>/dev/null | sed 's#//#/#' )"
            fullpath="$( echo "${bastille_jailsdir}/${jail}/root/${jailpath}/${filename}" 2>/dev/null | sed 's#//#/#' )"
            fstab_entry="${hostpath_fstab} ${fullpath_fstab} ${type} ${perms} ${checks}"
            mkdir -p "$( dirname "${fullpath}" )" || error_continue "Failed to create mount point."
            if [ ! -f "${fullpath}" ]; then
                touch "${fullpath}" || error_continue "Failed to create mount point."
            else
                error_notify "Failed. File exists at mount point."
                warn 1 "${fullpath}"
                continue
            fi
        fi
    fi

    # Add entry to fstab and mount
    echo "${fstab_entry}" >> "${bastille_jailsdir}/${jail}/fstab" || error_continue "Failed to create fstab entry: ${fstab_entry}"
    mount -F "${bastille_jailsdir}/${jail}/fstab" -a || error_continue "Failed to mount volume: ${fullpath}"
    info 2 "Added: ${fstab_entry}"

done
