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
    # Build an independent usage for the export command
    # Valid compress/options for ZFS systems are raw, .gz, .tgz, .txz and .xz(default)
    # Valid compress/options for non ZFS configured systems are .tgz and .txz(default)
    echo -e "${COLOR_RED}Usage: bastille export | option(s) | TARGET | PATH${COLOR_RESET}"

    cat << EOF
    Options:

         --gz       -- Export a ZFS jail using GZIP(.gz) compressed image.
    -r | --raw      -- Export a ZFS jail to an uncompressed RAW image.
    -s | --safe     -- Safely stop and start a ZFS jail before the exporting process.
         --tgz      -- Export a jail using simple .tgz compressed archive instead.
         --txz      -- Export a jail using simple .txz compressed archive instead.
    -v | --verbose  -- Be more verbose during the ZFS send operation.

EOF
    exit 1
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

if [ $# -gt 5 ] || [ $# -lt 1 ]; then
    usage
fi

zfs_enable_check() {
    # Temporarily disable ZFS so we can create a standard backup archive
    if [ "${bastille_zfs_enable}" = "YES" ]; then
        bastille_zfs_enable="NO"
    fi
}

TARGET="${1}"
GZIP_EXPORT=
SAFE_EXPORT=
RAW_EXPORT=
DIR_EXPORT=
TXZ_EXPORT=
TGZ_EXPORT=
OPT_ZSEND="-R"
COMP_OPTION="0"

opt_count() {
    COMP_OPTION=$(expr ${COMP_OPTION} + 1)
}

# Handle and parse option args
while [ $# -gt 0 ]; do
    case "${1}" in
        --gz)
            GZIP_EXPORT="1"
            TARGET="${2}"
            opt_count
            shift
            ;;
        --tgz)
            TGZ_EXPORT="1"
            TARGET="${2}"
            opt_count
            zfs_enable_check
            shift
            ;;
        --txz)
            TXZ_EXPORT="1"
            TARGET="${2}"
            opt_count
            zfs_enable_check
            shift
            ;;
        -s|--safe)
            SAFE_EXPORT="1"
            TARGET="${2}"
            shift
            ;;
        -r|--raw)
            RAW_EXPORT="1"
            TARGET="${2}"
            opt_count
            shift
            ;;
        -v|--verbose)
            OPT_ZSEND="-Rv"
            TARGET="${2}"
            shift
            ;;
        -*|--*)
            error_notify "Unknown Option."
            usage
            ;;
        *)
            if echo "${1}" | grep -q "\/"; then
                DIR_EXPORT="${1}"
            else
                if [ $# -gt 2 ] || [ $# -lt 1 ]; then
                   usage
                fi
            fi
            shift
            ;;
    esac
done

# Validate for combined options
if [ "${COMP_OPTION}" -gt "1" ]; then
    error_exit "Error: Only one compression format can be used during export."
fi

if [ -n "${TXZ_EXPORT}" -o -n "${TGZ_EXPORT}" ] && [ -n "${SAFE_EXPORT}" ]; then
    error_exit "Error: Simple archive modes with safe ZFS export can't be used together."
fi

if [ -z "${bastille_zfs_enable}" ]; then
    if [ -n "${GZIP_EXPORT}" -o -n "${RAW_EXPORT}" -o -n "${SAFE_EXPORT}" -o "${OPT_ZSEND}" = "-Rv" ]; then
        error_exit "Options --gz, --raw, --safe, --verbose are valid for ZFS configured systems only."
    fi
fi

if [ -n "${SAFE_EXPORT}" ]; then
    # Check if container is running, otherwise just ignore
    if [ -z "$(jls name | awk "/^${TARGET}$/")" ]; then
        SAFE_EXPORT=
    fi
fi

# Export directory check
if [ -n "${DIR_EXPORT}" ]; then
    if [ -d "${DIR_EXPORT}" ]; then
        # Set the user defined export directory
        bastille_backupsdir="${DIR_EXPORT}"
    else
        error_exit "Error: Path not found."
    fi
fi

# Fallback to default if missing config parameters
if [ -z "${bastille_compress_xz_options}" ]; then
    bastille_compress_xz_options="-0 -v"
fi
if [ -z "${bastille_compress_gz_options}" ]; then
    bastille_compress_gz_options="-1 -v"
fi

create_zfs_snap() {
    # Take a recursive temporary snapshot
    info "Creating temporary ZFS snapshot for export..."
    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
}

export_check() {
    # Inform the user about the exporting method
    if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
        if [ -n "${SAFE_EXPORT}" ]; then
            EXPORT_AS="Safely exporting"
        else
            EXPORT_AS="Hot exporting"
        fi
    else
        EXPORT_AS="Exporting"
    fi

    if [ "${FILE_EXT}" = ".xz" -o "${FILE_EXT}" = ".gz" -o "${FILE_EXT}" = "" ]; then
        EXPORT_TYPE="image"
    else
        EXPORT_TYPE="archive"
    fi

    if [ -n "${RAW_EXPORT}" ]; then
        EXPORT_INFO="to a raw ${EXPORT_TYPE}"
    else
        EXPORT_INFO="to a compressed ${FILE_EXT} ${EXPORT_TYPE}"
    fi

    info "${EXPORT_AS} '${TARGET}' ${EXPORT_INFO}..."

    # Safely stop and snapshot the jail
    if [ -n "${SAFE_EXPORT}" ]; then
        bastille stop ${TARGET}
        create_zfs_snap
        bastille start ${TARGET}
    else
        create_zfs_snap
    fi

    if [ "${bastille_zfs_enable}" = "YES" ]; then
        info "Sending ZFS data stream..."
    fi
}

jail_export() {
    # Attempt to export the container
    DATE=$(date +%F-%H%M%S)
    if [ "${bastille_zfs_enable}" = "YES" ]; then
        if [ -n "${bastille_zfs_zpool}" ]; then
            if [ -n "${RAW_EXPORT}" ]; then
                FILE_EXT=""
                export_check

                # Export the raw container recursively and cleanup temporary snapshots
                zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}" \
                > "${bastille_backupsdir}/${TARGET}_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_export_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
            elif [ -n "${GZIP_EXPORT}" ]; then
                FILE_EXT=".gz"
                export_check

                # Export the raw container recursively and cleanup temporary snapshots
                zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}" | \
                gzip ${bastille_compress_gz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_export_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
            else
                FILE_EXT=".xz"
                export_check

                # Export the container recursively and cleanup temporary snapshots(default)
                zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}" | \
                xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_export_${DATE}"
                zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_export_${DATE}"
            fi
        fi
    else
        if [ -n "${TGZ_EXPORT}" ]; then
            FILE_EXT=".tgz"

            # Create standard tgz backup archive
            info "Exporting '${TARGET}' to a compressed ${FILE_EXT} archive..."
            cd "${bastille_jailsdir}" && tar -cf - "${TARGET}" | gzip ${bastille_compress_gz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"
        else
            FILE_EXT=".txz"

            # Create standard txz backup archive(default)
            info "Exporting '${TARGET}' to a compressed ${FILE_EXT} archive..."
            cd "${bastille_jailsdir}" && tar -cf - "${TARGET}" | xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"
        fi
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

if [ -n "${TARGET}" ]; then
    if [ ! -d "${bastille_jailsdir}/${TARGET}" ]; then
        error_exit "[${TARGET}]: Not found."
    fi

    # Check if is a ZFS system
    if [ "${bastille_zfs_enable}" != "YES" ]; then
        # Check if container is running and ask for stop in non ZFS systems
        if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
            error_exit "${TARGET} is running. See 'bastille stop'."
        fi
    fi
    jail_export
fi
