#!/bin/sh
#
# Copyright (c) 2018-2021, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille export TARGET [options] | PATH
    \n
    \nOptions:
    \n
      -t|--txz    -- Export to a standard .txz archive even if bastille is configured for zfs\n
      -s|--safe   -- Safely stop the jail to snapshot it then start it again to proceed exporting\n
      -r|--raw    -- Export the jail to an uncompressed raw image\n"
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

if [ $# -gt 4 ] || [ $# -lt 0 ]; then
    usage
fi

SAFE_EXPORT=
RAW_EXPORT=
DIR_EXPORT=

# Handle and parse option args
while [ $# -gt 0 ]; do
    case "${1}" in
        -t|--txz)
            if [ "${bastille_zfs_enable}" = "YES" ]; then
                bastille_zfs_enable="NO"
            fi
            shift
            ;;
        -s|--safe)
            SAFE_EXPORT="1"
            shift
            ;;
        -r|--raw)
            RAW_EXPORT="1"
            shift
            ;;
        *)
            if echo "${1}" | grep -q "\/"; then
                DIR_EXPORT="${1}"
            else
               usage
            fi
            shift
            ;;
    esac
done

# Export directory check
if [ -n "${DIR_EXPORT}" ]; then
    if [ -d "${DIR_EXPORT}" ]; then
        # Set the user defined export directory
        bastille_backupsdir="${DIR_EXPORT}"
    else
        error_exit "Error: Path not found."
    fi
fi

create_zfs_snap(){
    # Take a recursive temporary snapshot
    info "Creating temporary ZFS snapshot for export..."
    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
}

export_check(){
    # Inform the user about the exporting method
    if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
        EXPORT_AS="Hot exporting"
    else
        EXPORT_AS="Exporting"
    fi
    if [ -n "${RAW_EXPORT}" ]; then
        EXPORT_INFO="to a raw"
    else
        EXPORT_INFO="to a compressed ${FILE_EXT}"
    fi

    # Safely stop and snapshot the jail
    if [ -n "${SAFE_EXPORT}" ]; then
        info "Safely exporting '${TARGET}' ${EXPORT_INFO} archive."
        bastille stop ${TARGET}
        create_zfs_snap
        bastille start ${TARGET}
    else
        info "${EXPORT_AS} '${TARGET}' ${EXPORT_INFO} archive."
        create_zfs_snap
    fi
    info "Sending ZFS data stream..."
}

jail_export()
{
    # Attempt to export the container
    DATE=$(date +%F-%H%M%S)
    if [ "${bastille_zfs_enable}" = "YES" ]; then
        if [ -n "${bastille_zfs_zpool}" ]; then
            if [ -n "${RAW_EXPORT}" ]; then
                FILE_EXT=""
                export_check

                # Export the raw container recursively and cleanup temporary snapshots
                zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}" \
                > "${bastille_backupsdir}/${TARGET}_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_export_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
            else
                FILE_EXT=".xz"
                export_check

                # Export the container recursively and cleanup temporary snapshots
                zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}" | \
                xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_export_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
            fi
        fi
    else
        # Create standard backup archive
        FILE_EXT=".txz"
        info "Exporting '${TARGET}' to a compressed ${FILE_EXT} archive..."
        cd "${bastille_jailsdir}" && tar -cf - "${TARGET}" | xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"
    fi

    if [ "$?" -ne 0 ]; then
        error_exit "Failed to export '${TARGET}' container."
    else
        # Generate container checksum file
        cd "${bastille_backupsdir}"
        sha256 -q "${TARGET}_${DATE}${FILE_EXT}" > "${TARGET}_${DATE}.sha256"
        info "Exported '${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}' successfully."
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
