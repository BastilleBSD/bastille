#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille export TARGET [option] | PATH"
}

# Handle special-case commands first
case "$1" in
help|-h|--help)
    usage
    ;;
esac

# Check for unsupported actions
if [ "${TARGET}" = "ALL" ]; then
    error_exit "Batch export is unsupported."
fi

if [ $# -gt 2 ] || [ $# -lt 0 ]; then
    usage
fi

OPTION="${1}"
EXPATH="${2}"

# Handle some options
if [ -n "${OPTION}" ]; then
    if [ "${OPTION}" = "-t" -o "${OPTION}" = "--txz" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            # Temporarily disable ZFS so we can create a standard backup archive
            bastille_zfs_enable="NO"
        fi
    elif echo "${OPTION}" | grep -q "\/"; then
        if [ -d "${OPTION}" ]; then
            EXPATH="${OPTION}"
        else
            error_exit "Error: Path not found."
        fi
    else
        error_notify "Invalid option!"
        usage
    fi
fi

# Export directory check
if [ -n "${EXPATH}" ]; then
    if [ -d "${EXPATH}" ]; then
        # Set the user defined export directory
        bastille_backupsdir="${EXPATH}"
    else
        error_exit "Error: Path not found."
    fi
fi

jail_export()
{
    # Attempt to export the container
    DATE=$(date +%F-%H%M%S)
    if [ "${bastille_zfs_enable}" = "YES" ]; then
        if [ -n "${bastille_zfs_zpool}" ]; then
            FILE_EXT="xz"
            info "Exporting '${TARGET}' to a compressed .${FILE_EXT} archive."
            info "Sending ZFS data stream..."
            # Take a recursive temporary snapshot
            zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"

            # Export the container recursively and cleanup temporary snapshots
            zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}" | \
            xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}.${FILE_EXT}"
            zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_export_${DATE}"
            zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
        fi
    else
        # Create standard backup archive
        FILE_EXT="txz"
        info "Exporting '${TARGET}' to a compressed .${FILE_EXT} archive..."
        cd "${bastille_jailsdir}" && tar -cf - "${TARGET}" | xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}.${FILE_EXT}"
    fi

    if [ "$?" -ne 0 ]; then
        error_exit "Failed to export '${TARGET}' container."
    else
        # Generate container checksum file
        cd "${bastille_backupsdir}"
        sha256 -q "${TARGET}_${DATE}.${FILE_EXT}" > "${TARGET}_${DATE}.sha256"
        info "Exported '${bastille_backupsdir}/${TARGET}_${DATE}.${FILE_EXT}' successfully."
        exit 0
    fi
}

# Check if backups directory/dataset exist
if [ ! -d "${bastille_backupsdir}" ]; then
    error_exit "Backups directory/dataset does not exist. See 'bastille bootstrap'."
fi

# Check if is a ZFS system
if [ "${bastille_zfs_enable}" != "YES" ]; then
    # Check if container is running and ask for stop in UFS systems
    if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
        error_exit "${TARGET} is running. See 'bastille stop'."
    fi
fi

jail_export
