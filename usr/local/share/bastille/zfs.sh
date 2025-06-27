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
    
    error_notify "Usage: bastille zfs [option(s)] TARGET [destroy|(df|usage)|get|set|(snap|snapshot)] [key=value|date]"
    error_notify "                                       [jail pool/dataset /jail/path]"
    error_notify "                                       [unjail pool/dataset]"

    cat << EOF
    Options:

    snapshot                Create a ZFS snapshot for the specified container.
    rollback                Rollback a ZFS snapshot on the specified container.
    destroy                 Destroy a ZFS snapshot on the specified container.
    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -v | --verbose          Be more verbose during the snapshot destroy operation.
    -x | --debug            Enable debug mode.

EOF
    exit 1
}

AUTO="0"
SNAP_NAME_GEN=
SNAP_CREATE=
SNAP_ROLLBACK=
SNAP_DESTROY=
SNAP_VERBOSE=
SNAP_BATCH=

zfs_jail_dataset() {

    info "\n[${_jail}]:"
    
    # Exit if MOUNT or DATASET is empty
    if [ -z "${MOUNT}" ] || [ -z "${DATASET}" ]; then
        usage
    # Exit if datset does not exist
    elif ! zfs list "${DATASET}" >/dev/null 2>/dev/null; then
        error_exit "[ERROR]: Dataset does not exist: ${DATASET}"
    fi

    # Ensure dataset is not already present in *zfs.conf*
    if grep -hoqsw "${DATASET}" ${bastille_jailsdir}/*/zfs.conf; then
        error_exit "[ERROR]: Dataset already assigned."
    fi
    # Validate jail state
    check_target_is_stopped "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${_jail}"
    else 
        error_notify "Jail is running."
        error_exit "Use [-a|--auto] to auto-stop the jail."
    fi

    # Add necessary config variables to jail
    bastille config ${_jail} set enforce_statfs 1 >/dev/null
    bastille config ${_jail} set allow.mount >/dev/null
    bastille config ${_jail} set allow.mount.devfs >/dev/null
    bastille config ${_jail} set allow.mount.zfs >/dev/null

    # Add dataset to zfs.conf
    echo "${DATASET} ${MOUNT}" >> "${bastille_jailsdir}/${_jail}/zfs.conf"

    if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    fi
}

zfs_unjail_dataset() {

    info "\n[${_jail}]:"

    # Exit if DATASET is empty
    if [ -z "${DATASET}" ]; then
        usage
    # Warn if datset does not exist
    elif ! zfs list "${DATASET}" >/dev/null 2>/dev/null; then
        warn "[WARNING]: Dataset does not exist: ${DATASET}"
    fi

    # Validate jail state
    check_target_is_stopped "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${_jail}"
    else 
        error_notify "Jail is running."
        error_exit "Use [-a|--auto] to auto-stop the jail."
    fi

    # Remove dataset from zfs.conf
    if ! grep -hoqsw "${DATASET}" ${bastille_jailsdir}/${_jail}/zfs.conf; then
        error_exit "[ERROR]: Dataset not present in zfs.conf."
    else
        sed -i '' "\#.*${DATASET}.*#d" "${bastille_jailsdir}/${_jail}/zfs.conf"
    fi

    if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    fi
}

zfs_snapshot() {
    info "\n[${_jail}]:"
    # shellcheck disable=SC2140
    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"
    _return=$?
}

zfs_rollback() {
    info "\n[${_jail}]:"
    # shellcheck disable=SC2140
    zfs rollback -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}"@"${TAG}"
    _return=$?
}

zfs_destroy_snapshot() {
    info "\n[${_jail}]:"
    # shellcheck disable=SC2140
    zfs destroy ${_opts} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"
    _return=$?
}

zfs_set_value() {
    info "\n[${_jail}]:"
    zfs set "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
}

zfs_get_value() {
    info "\n[${_jail}]:"
    zfs get "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
}

zfs_disk_usage() {
    info "\n[${_jail}]:"
    zfs list -t all -o name,used,avail,refer,mountpoint,compress,ratio -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
}

# Handle some options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -v|--verbose)
            SNAP_VERBOSE="1"
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

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    usage
fi

TARGET="${1}"
ACTION="${2}"

if [ "${TARGET}" = "ALL" -o "${TARGET}" = "all" ]; then
    SNAP_BATCH="1"
fi

bastille_root_check
set_target "${TARGET}"

# Check if ZFS is enabled
if ! checkyesno bastille_zfs_enable; then
    error_exit "[ERROR]: ZFS not enabled."
fi

# Check if zpool is defined
if [ -z "${bastille_zfs_zpool}" ]; then
    error_exit "[ERROR]: ZFS zpool not defined."
fi

snapshot_checks() {
    # Check if jail is running and stop if requested.
    if [ -z "${SNAP_DESTROY}" ]; then
        check_target_is_stopped "${_jail}" || \
        if [ "${AUTO}" -eq 1 ]; then
            bastille stop "${_jail}"
        fi
    fi

    # Check existence for the given snapshot.
    if [ -n "${SNAP_ROLLBACK}" ] || [ -n "${SNAP_DESTROY}" ]; then
        if [ -n "${TAG}" ]; then
            # Early warning about missing required snapshot/parent dataset for reference, this may happen when
            # more recent snapshots were deleted by either, intentional or automatically when rollback older snapshots.
            if ! zfs list -t snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}@${TAG}" >/dev/null 2>&1; then
                info "\n[${_jail}]:"
                warn "[WARNING]: Either snapshot '${TAG}' not exist or parent dataset appears to be missing."
            fi
        fi
    elif [ -n "${SNAP_CREATE}" ]; then
        if zfs list -t snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}@${TAG}" >/dev/null 2>&1; then
            info "\n[${_jail}]:"
            warn "[WARNING]: Looks like the snapshot '${TAG}' already exist, See 'bastille list snapshot'."
        fi
    fi

    # Generate a relatively short but unique name for the snapshots based on the current date/jail name.
    if [ -n "${SNAP_NAME_GEN}" ]; then
       for _JAIL in ${_jail}; do
            DATE=$(date +%F-%H%M%S)
            NAME_MD5X6=$(echo "${DATE} ${TARGET}" | md5 | cut -b -6)
            SNAPSHOT_NAME="Bastille_${NAME_MD5X6}_${_JAIL}_${DATE}"
            TAG="${SNAPSHOT_NAME}"
        done
    fi
}

snapshot_create() {
    # Attempt to snapshot the container.
    # Thiw will create a ZFS snapshot for the specified container with an auto-generated name with the
    # following format "Bastille_XXXXXX_JAILNAME_YYYY-MM-DD-HHMMSS" unless a name tag is manually entered.
    SNAP_CREATE="1"
    if [ -z "${TAG}" ]; then
        SNAP_NAME_GEN="1"
    fi

    snapshot_checks
    zfs_snapshot

    # Check for exit status and notify only for user reference.
    if [ "${_return}" -ne 0 ]; then
        error_notify "[ERROR]: Failed to snapshot jail: '${_jail}'"
    else
        info "Snapshot for ${_jail} successfully created as '${TAG}'."
    fi

    # Start the jail after snapshot if requested.
    if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    fi

    # Delay a sec for batch snapshot creation safety.
    if [ -n "${SNAP_BATCH}" ]; then
        sleep 1
    fi
}

snapshot_rollback() {
    # This feature is intended work with snapshots created  by either, bastille or manually created byu the user.
    # An error about "more recent snapshots or bookmarks exist" will appears if the '-r' flag is not specified.
    SNAP_ROLLBACK="1"
    snapshot_checks
    zfs_rollback

    # Check for exit status and just notify.
    if [ "${_return}" -ne 0 ]; then
        error_notify "[ERROR]: Failed to restore '${TAG}' snapshot for '${_jail}'."
    else
        info "Snapshot '${TAG}' successfully rolled back for '${_jail}'."
    fi

    # Start the jail after rollback if requested.
    if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    fi
}

snapshot_destroy() {
    # Destroy the user specifier bastille snapshot.
    SNAP_DESTROY="1"
    snapshot_checks

    # Set some options.
    if [ -n "${SNAP_VERBOSE}" ]; then
        _opts="-v -r"
    else
        _opts="-r"
    fi
    zfs_destroy_snapshot

    # Check for exit status and just notify.
    if [ "${_return}" -ne 0 ]; then
        error_notify "[ERROR]: Failed to destroy '${TAG}' snapshot for '${_jail}'"
    else
        info "Snapshot '${TAG}' destroyed successfully."
        exit 0
    fi
}

for _jail in ${JAILS}; do

    (

    case "${ACTION}" in
        destroy|destroy_snap|destroy_snapshot)
            TAG="${3}"
            snapshot_destroy
            ;;
        df|usage)
            zfs_disk_usage
            ;;
        get)
            ATTRIBUTE="${3}"
            zfs_get_value
            ;;
        jail)
            DATASET="${3}"
            MOUNT="${4}"
            zfs_jail_dataset
            ;;
        rollback)
            TAG="${3}"
            snapshot_rollback
            ;;
        unjail)
            DATASET="${3}"
            zfs_unjail_dataset
            ;;
        set)
            ATTRIBUTE="${3}"
            zfs_set_value
            ;;
        snap|snapshot)
            TAG="${3}"
            snapshot_create
            ;;
        *)
            usage
            ;;
    esac

    ) &

    bastille_running_jobs "${bastille_process_limit}"

done
wait
