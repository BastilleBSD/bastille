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
    error_notify "Usage: bastille zfs TARGET [set|get|snap|destroy_snap|df|usage] [key=value|date]"
    cat << EOF
	
    Options:

    -x | --debug          Enable debug mode.

EOF
    exit 1
}

zfs_snapshot() {

    for _jail in ${JAILS}; do

        info "\n[${_jail}]:"
	
        # shellcheck disable=SC2140
        zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"

    done
    
}

zfs_destroy_snapshot() {

    for _jail in ${JAILS}; do

        info "\n[${_jail}]:"
	
        # shellcheck disable=SC2140
        zfs destroy -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"

    done

}

zfs_set_value() {

    for _jail in ${JAILS}; do

        info "\n[${_jail}]:"
	
        zfs "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
	
    done

}

zfs_get_value() {

    for _jail in ${JAILS}; do

        info "\n[${_jail}]:"

        zfs get "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
	
    done
    
}

zfs_disk_usage() {

    for _jail in ${JAILS}; do

        info "\n[${_jail}]:"
	
        zfs list -t all -o name,used,avail,refer,mountpoint,compress,ratio -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
		
    done
    
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
            error_notify "Unknown Option: \"${1}\""
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 2 ]; then
    usage
fi

TARGET="${1}"
ACTION="${2}"

bastille_root_check
set_target "${TARGET}"

# Check if ZFS is enabled
if ! checkyesno bastille_zfs_enable; then
    error_exit "ZFS not enabled."
fi

# Check if zpool is defined
if [ -z "${bastille_zfs_zpool}" ]; then
    error_exit "ZFS zpool not defined."
fi

case "${ACTION}" in
    set)
        ATTRIBUTE="${3}"
        zfs_set_value
        ;;
    get)
        ATTRIBUTE="${3}"
        zfs_get_value
        ;;
    snap|snapshot)
        TAG="${3}"
        zfs_snapshot
        ;;
    destroy_snap|destroy_snapshot)
        TAG="${3}"
        zfs_destroy_snapshot
        ;;
    df|usage)
        zfs_disk_usage
        ;;
    *)
        usage
        ;;
esac