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

    error_notify "Usage: bastille zfs [option(s)] TARGET destroy|rollback [TAG]|snapshot [TAG]"
    error_notify "                                       df|usage"
    error_notify "                                       get|set key=value"
    error_notify "                                       jail pool/dataset /jail/path"
    error_notify "                                       unjail pool/dataset"

    cat << EOF
    Options:

    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -v | --verbose          Enable verbose mode.
    -x | --debug            Enable debug mode.

EOF
    exit 1
}

zfs_jail_dataset() {

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
    # shellcheck disable=SC2140
    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"
    _return=$?
}

zfs_rollback() {
    # shellcheck disable=SC2140
    zfs rollback -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"
    # shellcheck disable=SC2140
    zfs rollback -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}/root"@"${TAG}"
    _return=$?
}

zfs_destroy_snapshot() {
    # shellcheck disable=SC2140
    zfs destroy ${OPT_DESTROY} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"
    _return=$?
}

zfs_set_value() {
    zfs set "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
    _return=$?
}

zfs_get_value() {
    zfs get "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
    _return=$?
}

zfs_disk_usage() {
    zfs list -t all -o name,used,avail,refer,mountpoint,compress,ratio -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
    _return=$?
}

snapshot_checks() {

    # Generate a TAG if not given
    if [ -z "${TAG}" ]; then
        AUTO_TAG=1
    fi

    # Verify rollback snapshots
    if [ "${SNAP_ROLLBACK}" -eq 1 ]; then
        if [ -n "${TAG}" ]; then
            SNAP_TAG_CHECK="$(zfs list -H -t snapshot -o name ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail} | grep -o "${TAG}$" | tail -n 1)"
        else
            TAG="$(zfs list -H -t snapshot -o name ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail} | grep -o "bastille_${_jail}_.*$" | tail -n 1)"
            SNAP_TAG_CHECK=$(echo ${TAG} | grep -wo "bastille_${_jail}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}")
        fi
        if [ -z "${SNAP_TAG_CHECK}" ]; then
            error_continue "[ERROR]: Snapshot not found: ${TAG}"
        fi
    elif [ "${SNAP_DESTROY}" -eq 1 ]; then
        if [ -z "${TAG}" ]; then
            error_continue "[ERROR]: Destroying snapshots requires a TAG to be specified."
        fi
    # Generate a relatively short but unique name for the snapshots based on the current date/jail name.
    elif [ "${AUTO_TAG}" -eq 1 ]; then
        DATE=$(date +%F-%H%M%S)
        TAG="bastille_${_jail}_${DATE}"
        # Check for the generated snapshot name.
        SNAP_GEN_CHECK=""
        SNAP_GEN_CHECK=$(echo ${TAG} | grep -wo "bastille_${_jail}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}")
        if [ -z "${SNAP_GEN_CHECK}" ]; then
            error_notify "[ERROR]: Failed to validate snapshot name."
        fi
    fi
}

snapshot_create() {

    snapshot_checks
    zfs_snapshot

    # Check for exit status and notify only for user reference.
    if [ "${_return}" -ne 0 ]; then
        error_notify "[ERROR]: Failed to create snapshot."
    else
        echo "Snapshot created: ${TAG}"
    fi
}

snapshot_rollback() {

    # This feature is intended work with snapshots created by bastille or manually created by the user.
    # An error about "more recent snapshots or bookmarks exist" will appears if the '-r' flag is not specified.
    snapshot_checks
    zfs_rollback

    # Check for exit status and just notify.
    if [ "${_return}" -ne 0 ]; then
        error_notify "[ERROR]: Failed to restore snapshot: ${TAG}."
    else
        echo "Snapshot restored: ${TAG}"
    fi
}

snapshot_destroy() {

    # Destroy specified bastille
    snapshot_checks

    # Set some options.
    if [ "${OPT_VERBOSE}" -eq 1 ]; then
        OPT_DESTROY="-v -r"
    else
        OPT_DESTROY="-r"
    fi

    zfs_destroy_snapshot

    # Check for exit status and just notify.
    if [ "${_return}" -ne 0 ]; then
        error_notify "[ERROR]: Failed to destroy snapshot: ${TAG}"
    else
        echo "Snapshot destroyed: ${TAG}"
    fi
}

# Handle options.
AUTO=0
AUTO_TAG=0
SNAP_ROLLBACK=0
SNAP_DESTROY=0
OPT_VERBOSE=0
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
            OPT_VERBOSE="1"
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

for _jail in ${JAILS}; do

    info "\n[${_jail}]:"

    case "${ACTION}" in
        destroy|destroy_snap|destroy_snapshot)
            SNAP_DESTROY=1
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
            SNAP_ROLLBACK=1
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

done
