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
    # Build an independent usage for the export command
    # Valid compress/options for ZFS systems are raw, .gz, .tgz, .txz and .xz
    # Valid compress/options for non ZFS configured systems are .tgz and .txz
    # If no compression option specified, user must redirect standard output
    error_notify "Usage: bastille export [option(s)] TARGET PATH"
    cat << EOF

    Options:

    -a | --auto        Auto mode. Start/stop jail(s) if required.
    -l | --live        Export a running jail (ZFS only).
         --gz          Export to '.gz' compressed image (ZFS only).
         --xz          Export to a '.xz' compressed image (ZFS only).
         --zst         Export to a .zst compressed image (ZFS only).
         --raw         Export to an uncompressed RAW image (ZFS only).
         --tgz         Export to a '.tgz' compressed archive.
         --txz         Export to a '.txz' compressed archive.
         --tzst        Export to a '.tzst' compressed archive.
    -v | --verbose     Enable verbose mode (ZFS only).
    -x | --debug       Enable debug mode.

Note: If no export option specified, the jail should be redirected to standard output.

EOF
    exit 1
}

zfs_enable_check() {
    # Temporarily disable ZFS so we can create a standard backup archive
    if checkyesno bastille_zfs_enable; then
        # shellcheck disable=SC2034
        bastille_zfs_enable="NO"
    fi
}

opt_count() {
    COMP_OPTION=$((COMP_OPTION + 1))
}

# Reset export options
AUTO=0
LIVE=0
GZIP_EXPORT=0
XZ_EXPORT=0
ZST_EXPORT=0
RAW_EXPORT=0
OPT_ZSEND="-R"
TXZ_EXPORT=0
TGZ_EXPORT=0
TZST_EXPORT=0
USER_EXPORT=0
DIR_EXPORT=""
COMP_OPTION=0
if [ -n "${bastille_export_options}" ]; then
    # Overrides the case options by the user defined option(s) automatically.
    # Add bastille_export_options="--optionA --optionB" to bastille.conf, or simply `export bastille_export_options="--optionA --optionB"` environment variable.
    # To restore the standard case options, empty bastille_export_options="" in bastille.conf, or `unset bastille_export_options` environment variable.
    # Reference "/bastille/issues/443"

    DEFAULT_EXPORT_OPTS="${bastille_export_options}"

    info "Default export option(s): '${DEFAULT_EXPORT_OPTS}'"

    # Don't shift here when default export options are explicitly denoted in the config file, hence TARGET will always be $1.
    for opt in ${DEFAULT_EXPORT_OPTS}; do
        case "${opt}" in
            -a|--auto)
                AUTO="1"
                ;;
            -l|--live)
                LIVE="1"
                ;;
            --gz)
                GZIP_EXPORT="1"
                opt_count
                ;;
            --xz)
                XZ_EXPORT="1"
                opt_count
                ;;
            --zst)
                ZST_EXPORT="1"
                opt_count
                ;;
            -r|--raw)
                RAW_EXPORT="1"
                opt_count
                ;;
            --tgz)
                TGZ_EXPORT="1"
                opt_count
                zfs_enable_check
                ;;
            --txz)
                TXZ_EXPORT="1"
                opt_count
                zfs_enable_check
                ;;
            --tzst)
                TZST_EXPORT="1"
                opt_count
                zfs_enable_check
                ;;
            -v|--verbose)
                OPT_ZSEND="-Rv"
                ;;
            -x)
                enable_debug
                ;;
            -*) 
                error_notify "[ERROR]: Unknown Option: \"${1}\""
                usage
                ;;
        esac
    done

else

    # Handle options
    while [ $# -gt 0 ]; do
        case "${1}" in
            -h|--help|help)
                usage
                ;;
            -a|--auto)
                AUTO=1
                shift
                ;;
            -l|--live)
                LIVE="1"
                shift
                ;;
            --gz)
                GZIP_EXPORT="1"
                opt_count
                shift
                ;;
            --xz)
                XZ_EXPORT="1"
                opt_count
                shift
                ;;
            --zst)
                ZST_EXPORT="1"
                opt_count
                shift
                ;;
            -r|--raw)
                RAW_EXPORT="1"
                opt_count
                shift
                ;;
            --tgz)
                TGZ_EXPORT="1"
                opt_count
                zfs_enable_check
                shift
                ;;
            --txz)
                TXZ_EXPORT="1"
                opt_count
                zfs_enable_check
                shift
                ;;
            --tzst)
                TZST_EXPORT="1"
                opt_count
                zfs_enable_check
                shift
                ;;
            -v|--verbose)
                OPT_ZSEND="-Rv"
                shift
                ;;
            -x)
                enable_debug
                shift
                ;;
            -*)
                for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                    case ${_opt} in
                        a) AUTO=1 ;;
                        l) LIVE=1 ;;
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
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

TARGET="${1}"
# Check for directory export
if echo "${2}" | grep -q "\/"; then
    DIR_EXPORT="${2}"
fi

bastille_root_check
set_target_single "${TARGET}"

# Only allow a single compression option
if [ "${COMP_OPTION}" -gt "1" ]; then
    error_exit "[ERROR]: Only one compression format can be used during export."
fi

# Validate LIVE and AUTO
if ! checkyesno bastille_zfs_enable; then
    if [ "${LIVE}" -eq 1 ]; then
        error_exit "[ERROR]: [-l|--live] can only be used with ZFS."
    fi
elif [ "${AUTO}" -eq 1 ] && [ "${LIVE}" -eq 1 ]; then
    error_exit "[ERROR]: [-a|--auto] cannot be used with [-l|--live]."
fi

# Don't allow LIVE with TXZ_EXPORT or TGZ_EXPORT
if { [ "${TXZ_EXPORT}" -eq 1 ] || [ "${TGZ_EXPORT}" -eq 1 ] || "${TZST_EXPORT}" -eq 1 ]; } && [ "${LIVE}" -eq 1 ]; then
    error_exit "[ERROR]: Archive mode cannot be used with [-l|--live]."
fi

# Don't allow ZFS specific options if not enabled
if ! checkyesno bastille_zfs_enable; then
    if [ "${XZ_EXPORT}" -eq 1 ] ||
       [ "${GZIP_EXPORT}" -eq 1 ] ||
       [ "${RAW_EXPORT}" -eq 1 ] ||
       [ "${LIVE}" -eq 1 ] ||
       [ "${ZST_EXPORT}" -eq 1 ] ||
       [ "${OPT_ZSEND}" = "-Rv" ]; then
        error_exit "[ERROR]: Options --xz, --gz, --raw, -l|--live, --zst and --verbose are only valid for ZFS configured systems."
    fi
fi

# Fallback to default if missing config parameters
if [ -z "${bastille_compress_xz_options}" ]; then
    bastille_compress_xz_options="-0 -v"
fi
if [ -z "${bastille_compress_gz_options}" ]; then
    bastille_compress_gz_options="-1 -v"
fi
if [ -z "${bastille_compress_zst_options}" ]; then
    bastille_compress_zst_options="-3 -v"
fi

# Export directory check
if [ -n "${DIR_EXPORT}" ]; then
    if [ -d "${DIR_EXPORT}" ]; then
        # Set the user defined export directory
        bastille_backupsdir="${DIR_EXPORT}"
    else
        error_exit "[ERROR]: Path not found."
    fi
elif [ ! -d "${bastille_backupsdir}" ]; then
    error_exit "[ERROR]: Backups directory/dataset does not exist. See 'bastille bootstrap'."
fi

# Validate jail state
if checkyesno bastille_zfs_enable; then
    if [ "${LIVE}" -eq 1 ]; then
        if ! check_target_is_running "${TARGET}"; then
            error_exit "[ERROR]: [-l|--live] can only be used with a running jail."
        fi
    elif check_target_is_running "${TARGET}"; then
        if [ "${AUTO}" -eq 1 ]; then
            bastille stop "${TARGET}"
        else
            info "\n[${TARGET}]:"
            error_notify "[ERROR]: Jail is running."
            error_exit "Use [-a|--auto] to auto-stop the jail, or [-l|--live] (ZFS only) to migrate a running jail."
        fi
        fi
else
    check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${TARGET}"
    else
        info "\n[${TARGET}]:"
        error_notify "Jail is running."
        error_exit "Use [-a|--auto] to auto-stop the jail."
    fi
fi

create_zfs_snap() {
    # Take a recursive temporary snapshot
    if [ "${USER_EXPORT}" -eq 0 ]; then
        info "\nCreating temporary ZFS snapshot for export..."
    fi
    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}"
}

clean_zfs_snap() {
    # Cleanup the recursive temporary snapshot
    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_${TARGET}_${DATE}"
    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}"
}

export_check() {

    # Inform the user about the exporting method
    if [ "${USER_EXPORT}" -eq 0 ]; then
        if check_target_is_running "${TARGET}" 2>/dev/null; then
            if [ "${LIVE}" -eq 1 ]; then
                EXPORT_AS="Hot exporting"
            else
                EXPORT_AS="Safely exporting"
            fi
        else
            EXPORT_AS="Exporting"
        fi

        if [ "${FILE_EXT}" = ".xz" ] || [ "${FILE_EXT}" = ".gz" ] || [ "${FILE_EXT}" = ".zst" ] || [ "${FILE_EXT}" = "" ]; then
            EXPORT_TYPE="image"
        else
            EXPORT_TYPE="archive"
        fi

        if [ -n "${RAW_EXPORT}" ]; then
            EXPORT_INFO="to a raw ${EXPORT_TYPE}"
        else
            EXPORT_INFO="to a compressed ${FILE_EXT} ${EXPORT_TYPE}"
        fi

        info "\n${EXPORT_AS} '${TARGET}' ${EXPORT_INFO}..."
    fi

    if checkyesno bastille_zfs_enable; then

        # Create snapshot
        create_zfs_snap

        if [ "${USER_EXPORT}" -eq 0 ]; then
            info "\nSending ZFS data stream..."
        fi

    fi
}

jail_export() {

    # Attempt to export the container
    DATE=$(date +%F-%H%M%S)

    if checkyesno bastille_zfs_enable; then

        if [ -n "${bastille_zfs_zpool}" ]; then

            if [ "$(zfs get -H -o value encryption ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET})" = "on" ]; then
                error_exit "[ERROR]: Exporting jails in encryoted datasets is not supported."
            fi

            if [ "${RAW_EXPORT}" -eq 1 ]; then

                FILE_EXT=""

                export_check

                # Export the raw container recursively and cleanup temporary snapshots
                if ! zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}" > "${bastille_backupsdir}/${TARGET}_${DATE}"; then
                    clean_zfs_snap
                    error_exit "[ERROR]: Failed to export jail: ${TARGET}"
                else
                    clean_zfs_snap
                fi

            elif [ "${GZIP_EXPORT}" -eq 1 ]; then

                FILE_EXT=".gz"

                export_check

                # Export the raw container recursively and cleanup temporary snapshots
                if ! zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}" | gzip ${bastille_compress_gz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"; then
                    clean_zfs_snap
                    error_exit "[ERROR]: Failed to export jail: ${TARGET}"
                else
                    clean_zfs_snap
                fi

            elif [ "${XZ_EXPORT}" -eq 1 ]; then

                FILE_EXT=".xz"

                export_check

                # Export the container recursively and cleanup temporary snapshots
                if ! zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}" | xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"; then
                    clean_zfs_snap
                    error_exit "[ERROR]: Failed to export jail: ${TARGET}"
                else
                    clean_zfs_snap
                fi

            elif [ "${ZST_EXPORT}" -eq 1 ]; then

                FILE_EXT=".zst"

                export_check

                # Export the container recursively and cleanup temporary snapshots
                if ! zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}" | zstd ${bastille_compress_zst_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"; then
                    clean_zfs_snap
                    error_exit "[ERROR]: Failed to export jail: ${TARGET}"
                else
                    clean_zfs_snap
                fi

            else

                FILE_EXT=""
                USER_EXPORT="1"

                export_check

                # Quietly export the container recursively, user must redirect standard output
                if ! zfs send ${OPT_ZSEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_${TARGET}_${DATE}"; then
                    clean_zfs_snap
                    error_exit "[ERROR]: An export option is required, see 'bastille export, otherwise the user must redirect to standard output."
                else
                    clean_zfs_snap
                fi
            fi
        fi
    else
        if [ "${TGZ_EXPORT}" -eq 1 ]; then

            FILE_EXT=".tgz"

            # Create standard tgz backup archive
            info "\nExporting '${TARGET}' to a compressed ${FILE_EXT} archive..."

            cd "${bastille_jailsdir}" || error_exit "[ERROR]: Failed to change to directory: ${bastille_jailsdir}"
            if ! tar -cf - "${TARGET}" | gzip ${bastille_compress_gz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"; then
                error_exit "[ERROR]: Failed to export jail: ${TARGET}"
            fi

        elif [ "${TXZ_EXPORT}" -eq 1 ]; then

            FILE_EXT=".txz"

            # Create standard txz backup archive
            info "\nExporting '${TARGET}' to a compressed ${FILE_EXT} archive..."

            cd "${bastille_jailsdir}" || error_exit "[ERROR]: Failed to change to directory: ${bastille_jailssdir}"
            if ! tar -cf - "${TARGET}" | xz ${bastille_compress_xz_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"; then
                error_exit "[ERROR]: Failed to export jail: ${TARGET}"
            fi

        elif [ "${TZST_EXPORT}" -eq 1 ]; then

            FILE_EXT=".tzst"

            # Create standard txz backup archive
            info "\nExporting '${TARGET}' to a compressed ${FILE_EXT} archive..."

            cd "${bastille_jailsdir}" || error_exit "[ERROR]: Failed to change to directory: ${bastille_jailssdir}"
            if ! tar -cf - "${TARGET}" | zstd ${bastille_compress_tzst_options} > "${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}"; then
                error_exit "[ERROR]: Failed to export jail: ${TARGET}"
            fi

        else
            error_exit "[ERROR]: export option required"
        fi
    fi

    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
        error_exit "[ERROR]: Failed to export jail: ${TARGET}"
    else
        if [ "${USER_EXPORT}" -eq 0 ]; then
            # Generate container checksum file
            cd "${bastille_backupsdir}" || error_exit "[ERROR]: Failed to change to directory: ${bastille_backupsdir}"
            if ! sha256 -q "${TARGET}_${DATE}${FILE_EXT}" > "${TARGET}_${DATE}.sha256"; then
	        error_exit "[ERROR]: Failed to generate sha256 file."
	    fi
            info "\nExported '${bastille_backupsdir}/${TARGET}_${DATE}${FILE_EXT}' successfully."
        fi
        exit 0
    fi
}

jail_export
