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
    # Build an independent usage for the snapshot command.
    # This command only works on ZFS systems as expected.
    error_notify "Usage: bastille snapshot [option(s)] TARGET | SNAPSHOT"
    cat << EOF

    Options:

    -C | --create           Create a ZFS snapshot for the specified container.
    -R | --restore          Restores a ZFS snapshot on the specified container.
    -D | --destroy          Destroy a ZFS snapshot on the specified container.
    -L | --list             List available snapshots for the specified container.
    -s | --safe             Safely stop and start a ZFS jail before creating/restoring a snapshot.
    -r | --recursive        Create, restore or destroy snapshot recursively for the specified container.
    -v | --verbose          Be more verbose during the snapshot operation.
    -n | --dryrun           Do a dry-run(no actual deletion) to determine what data would be deleted.
    -x | --debug            Enable debug mode.

Note: Be aware that '-r|--recursive' option will permanently delete more recent snapshots or bookmarks if exist.
      For more info search the man pages with: 'man zfs-rollback' or 'man zfs-destroy'.

EOF
    exit 1
}

opt_count() {
    SNAP_OPTION=$((SNAP_OPTION + 1))
}

SNAP_OPTION="0"
SNAP_CREATE=
SNAP_RESTORE=
SNAP_DESTROY=
SNAP_LIST=
SNAP_SAFELY=
SNAP_RECURSIVE=
SNAP_VERBOSE=
SNAP_DRYRUN=
ZFS_OPTS=

# Handle some options.
while [ $# -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -C|--create)
            SNAP_CREATE="1"
            opt_count
            shift
            ;;
        -R|--restore)
            SNAP_RESTORE="1"
            opt_count
            shift
            ;;
        -D|--destroy)
            SNAP_DESTROY="1"
            opt_count
            shift
            ;;
        -L|--list)
            SNAP_LIST="1"
            opt_count
            shift
            ;;
        -s|--safe)
            SNAP_SAFELY="1"
            shift
            ;;
        -r|--recursive)
            SNAP_RECURSIVE="-r"
            shift
            ;;
        -v|--verbose)
            SNAP_VERBOSE="-v"
            shift
            ;;
        -n|--dryrun)
            SNAP_DRYRUN="-n"
            shift
            ;;
        -x)
           enable_debug
           shift
           ;;
        -*)
            error_notify "[ERROR]: Unknown Option: \"${1}\""
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check
if [ -z "${SNAP_RESTORE}" ] && [ -z "${SNAP_DESTROY}" ] && [ -z "${SNAP_LIST}" ]; then
    set_target_single "${TARGET}"
fi

# Validate for combined options.
if [ "${SNAP_OPTION}" -gt "1" ]; then
    error_exit "[ERROR]: Only one option between [-C/R/D/L] can be used at a time."
fi

#  Options to ignore for certain ZFS actions.
if [ -n "${SNAP_CREATE}" ] || [ -n "${SNAP_RESTORE}" ]; then
    SNAP_VERBOSE=
    SNAP_DRYRUN=    
fi

if ! checkyesno bastille_zfs_enable; then
    error_exit "[ERROR]: The snapshot command is valid for ZFS configured systems only."
fi

# Build available side options in one variable.
ZFS_OPT_LIST="${SNAP_VERBOSE} ${SNAP_DRYRUN}"
for _zfs_opt in ${ZFS_OPT_LIST}; do
    ZFS_OPTS="${ZFS_OPTS} ${_zfs_opt}"
done

# Strip the jail name from the given snapshot.
snapshot_srtipname() {
    JAIL_TARGET=$(echo "${TARGET}" | sed 's/Bastille_[0-9a-fA-F]\{6\}_//;s/_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}//')
}

snapshot_safecheck() {
    # Safely stop the jail bfore snapshot/restore.
    if [ -n "${SNAP_SAFELY}" ]; then
        snapshot_srtipname
        if [ -n "${JAIL_TARGET}" ]; then
            if [ -z "$(/usr/sbin/jls name | awk "/^${JAIL_TARGET}$/")" ]; then
                SNAP_SAFELY=
            else
                bastille stop ${JAIL_TARGET}
            fi
        else
            if [ -z "$(/usr/sbin/jls name | awk "/^${TARGET}$/")" ]; then
                SNAP_SAFELY=
            else
                bastille stop ${TARGET}
            fi
        fi
    fi

    # We will generate a relatively short but unique name for the snapshots based on the current date/jail name.
    if [ -n "${SNAP_CREATE}" ]; then
        DATE=$(date +%F-%H%M%S)
        NAME_MD5X6=$(echo "${DATE} ${TARGET}" | md5 | cut -b -6)
        SNAPSHOT_NAME="Bastille_${NAME_MD5X6}_${TARGET}_${DATE}"
    fi

    if [ -n "${SNAP_RESTORE}" ] || [ -n "${SNAP_DESTROY}" ]; then
        snapshot_srtipname
        TARGET_CHECK=$(echo ${TARGET} | grep -wo "Bastille_[0-9a-fA-F]\{6\}_${JAIL_TARGET}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}")
        if [ -n "${TARGET_CHECK}" ]; then
            if ! zfs list -t snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${JAIL_TARGET}/root@${TARGET_CHECK}" >/dev/null 2>&1; then
                error_exit "[ERROR]: Snapshot not found: ${TARGET_CHECK}"
            fi
        fi
    fi
}

snapshot_create() {
    # Attempt to snapshot the container in the following naming format "Bastille_XXXXXX_JAILNAME_YYYY-MM-DD-HHMMSS".
    if checkyesno bastille_zfs_enable; then
        if [ -n "${bastille_zfs_zpool}" ]; then
            if [ "$(zfs get -H -o value encryption ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET})" = "on" ]; then
                error_exit "[ERROR]: Snapshot jails in encrypted datasets is not supported."
            fi

            snapshot_safecheck
            if [ -n "${SNAP_RECURSIVE}" ]; then
                # Take recursive snapshot for the specified target/*
                info "Creating a recursive ZFS snapshot for ${TARGET}..."
                zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@${SNAPSHOT_NAME}"
            else
                # Take standard non-recursive snapshot for the specified target/root.
                info "Creating a ZFS snapshot for ${TARGET}..."
                zfs snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@${SNAPSHOT_NAME}"
            fi
        fi
    fi

    # Check for exit status and notify.
    if [ "$?" -ne 0 ]; then
        error_exit "[ERROR]: Failed to snapshot jail: ${TARGET}"
    else
        info "Snapshot for ${TARGET} successfully created as '${SNAPSHOT_NAME}'."
         # Safely start the jail after snapshot.
        if [ -n "${SNAP_SAFELY}" ]; then
            bastille start ${TARGET}
        fi
        exit 0
    fi
}

snapshot_restore() {
    # This feature is intended work with snapshots created  by 'bastille snapshot' cmd, in the even of newly created snapshots
    # by either third-party app or manually, the user will be notified about "more recent snapshots or bookmarks exist" and a list,
    # in such case the user will have the option to perform recursive operations by specifying '-r|--recursive' flag.
    snapshot_safecheck
    if [ -n "${TARGET_CHECK}" ]; then
        info "\nTrying to restore '${TARGET}' for '${JAIL_TARGET}'."
        if [ -n "${SNAP_RECURSIVE}" ]; then
            zfs rollback -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${JAIL_TARGET}/root@${TARGET}"
        else
            zfs rollback "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${JAIL_TARGET}/root@${TARGET}"
        fi

        # Check for exit status and notify.
        if [ "$?" -ne 0 ]; then
            error_exit "[ERROR]: Failed to restore '${TARGET}' snapshot for '${JAIL_TARGET}', See '--recursive' option."
        else
            info "Snapshot '${TARGET}' successfully restored for '${JAIL_TARGET}'."
            # Safely start the jail after snapshot restore.
            if [ -n "${SNAP_SAFELY}" ]; then
                bastille start ${JAIL_TARGET}
            fi
            exit 0
        fi
    else
        error_exit "[ERROR]: Unsupported/unrecognized snapshot selected, See '--list' option."
    fi
}

snapshot_destroy() {
    # Destroy the user specifier bastille snapshot.
    snapshot_safecheck
    if [ -n "${TARGET_CHECK}" ]; then
        if [ -n "${SNAP_RECURSIVE}" ]; then
            # Destroy the snapshot recursively.
            zfs destroy -r ${ZFS_OPTS} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${JAIL_TARGET}/root@${TARGET}"
        else
            # Destroy the snapshot non-recursively.
            zfs destroy ${ZFS_OPTS} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${JAIL_TARGET}/root@${TARGET}"
        fi

        # Check for exit status and notify.
        if [ "$?" -ne 0 ]; then
            error_exit "[ERROR]: Failed to destroy '${TARGET}' snapshot for '${JAIL_TARGET}'"
        else
            if [ -z "${SNAP_DRYRUN}" ]; then
                info "Snapshot '${TARGET}' destroyed successfully."
            fi
            exit 0
        fi
    else
        error_exit "[ERROR]: Unsupported/unrecognized snapshot selected, See '--list' option."
    fi
}

snapshot_list() {
    # List available snapshot created by 'bastille snapshot' cmd only.
    if [ -n "${SNAP_VERBOSE}" ]; then
        zfs list -r -t snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root" | \
        grep -w "Bastille_[0-9a-fA-F]\{6\}_${TARGET}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}"
    else
        zfs list -r -t snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root" | \
        grep -wo "Bastille_[0-9a-fA-F]\{6\}_${TARGET}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}"
    fi

    # Check for exit status and notify.
    if [ "$?" -ne 0 ]; then
        warn "\n[WARNING]: Failed to retrieve snapshot list or no bastille snapshots created yet."
    else
        exit 0
    fi
}

if [ -n "${TARGET}" ] && [ -z "${SNAP_RESTORE}" ] && [ -z "${SNAP_DESTROY}" ]; then
    # Validate jail existence.
    if [ ! -d "${bastille_jailsdir}/${TARGET}" ]; then
        error_exit "[ERROR]: Jail not found: ${TARGET}"
    fi
fi

# Check and continue with the requested function.
if [ -n "${SNAP_CREATE}" ]; then
    snapshot_create
elif [ -n "${SNAP_RESTORE}" ]; then
    snapshot_restore
elif [ -n "${SNAP_DESTROY}" ]; then
    snapshot_destroy
elif [ -n "${SNAP_LIST}" ]; then
    snapshot_list
fi
