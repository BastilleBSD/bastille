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
    # Build an independent usage for the import command
    # If no file/extension specified, will import from standard input
    error_notify "Usage: bastille import [option(s)] FILE"

    cat << EOF
    Options:

    -f | --force    -- Force an archive import regardless if the checksum file does not match or missing.
    -v | --verbose  -- Be more verbose during the ZFS receive operation.

Tip: If no option specified, container should be imported from standard input.

EOF
    exit 1
}

# Handle special-case commands first
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 3 ] || [ $# -lt 1 ]; then
    usage
fi

bastille_root_check

TARGET="${1}"
OPT_FORCE=
USER_IMPORT=
OPT_ZRECV="-u"

# Handle and parse option args
while [ $# -gt 0 ]; do
    case "${1}" in
        -f|--force)
            OPT_FORCE="1"
            TARGET="${2}"
            shift
            ;;
        -v|--verbose)
            OPT_ZRECV="-u -v"
            TARGET="${2}"
            shift
            ;;
        -*|--*)
            error_notify "Unknown Option."
            usage
            ;;
        *)
            if [ $# -gt 1 ] || [ $# -lt 1 ]; then
                usage
            fi
            shift
            ;;
    esac
done

# Fallback to default if missing config parameters
if [ -z "${bastille_decompress_xz_options}" ]; then
    bastille_decompress_xz_options="-c -d -v"
fi
if [ -z "${bastille_decompress_gz_options}" ]; then
    bastille_decompress_gz_options="-k -d -c -v"
fi

validate_archive() {
    # Compare checksums on the target archive
    # Skip validation for unsupported archive
    if [ -f "${bastille_backupsdir}/${TARGET}" ]; then
        if [ -f "${bastille_backupsdir}/${FILE_TRIM}.sha256" ]; then
            info "Validating file: ${TARGET}..."
            SHA256_DIST=$(cat "${bastille_backupsdir}/${FILE_TRIM}.sha256")
            SHA256_FILE=$(sha256 -q "${bastille_backupsdir}/${TARGET}")
            if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
                error_exit "Failed validation for ${TARGET}."
            else
                info "File validation successful!"
            fi
        else
            # Check if user opt to force import
            if [ -n "${OPT_FORCE}" ]; then
                warn "Warning: Skipping archive validation!"
            else
                error_exit "Checksum file not found. See 'bastille import [option(s)] FILE'."
            fi
        fi
    fi
}

update_zfsmount() {
    # Update the mountpoint property on the received ZFS data stream
    OLD_ZFS_MOUNTPOINT=$(zfs get -H mountpoint "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root" | awk '{print $3}')
    NEW_ZFS_MOUNTPOINT="${bastille_jailsdir}/${TARGET_TRIM}/root"
    if [ "${NEW_ZFS_MOUNTPOINT}" != "${OLD_ZFS_MOUNTPOINT}" ]; then
        info "Updating ZFS mountpoint..."
        zfs set mountpoint="${bastille_jailsdir}/${TARGET_TRIM}/root" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root"
    fi

    # Mount new container ZFS datasets
    if ! zfs mount | grep -qw "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}$"; then
        zfs mount "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
    fi
    if ! zfs mount | grep -qw "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root$"; then
        zfs mount "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root"
    fi
}

update_jailconf() {
    # Update jail.conf paths
    JAIL_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/jail.conf"
    if [ -f "${JAIL_CONFIG}" ]; then
        if ! grep -qw "path = ${bastille_jailsdir}/${TARGET_TRIM}/root;" "${JAIL_CONFIG}"; then
            info "Updating jail.conf..."
            sed -i '' "s|exec.consolelog.*=.*;|exec.consolelog = ${bastille_logsdir}/${TARGET_TRIM}_console.log;|" "${JAIL_CONFIG}"
            sed -i '' "s|path.*=.*;|path = ${bastille_jailsdir}/${TARGET_TRIM}/root;|" "${JAIL_CONFIG}"
            sed -i '' "s|mount.fstab.*=.*;|mount.fstab = ${bastille_jailsdir}/${TARGET_TRIM}/fstab;|" "${JAIL_CONFIG}"
        fi

        # Check for the jib script
        if grep -qw "vnet" "${JAIL_CONFIG}"; then
            vnet_requirements
        fi
    fi
}

update_fstab() {
    # Update fstab .bastille mountpoint on thin containers only
    # Set some variables
    FSTAB_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/fstab"
    FSTAB_RELEASE=$(grep -owE '([1-9]{2,2})\.[0-9](-RELEASE|-RELEASE-i386|-RC[1-9])|([0-9]{1,2}-stable-build-[0-9]{1,3})|(current-build)-([0-9]{1,3})|(current-BUILD-LATEST)|([0-9]{1,2}-stable-BUILD-LATEST)|(current-BUILD-LATEST)' "${FSTAB_CONFIG}")
    FSTAB_CURRENT=$(grep -w ".*/releases/.*/jails/${TARGET_TRIM}/root/.bastille" "${FSTAB_CONFIG}")
    FSTAB_NEWCONF="${bastille_releasesdir}/${FSTAB_RELEASE} ${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille nullfs ro 0 0"
    if [ -n "${FSTAB_CURRENT}" ] && [ -n "${FSTAB_NEWCONF}" ]; then
        # If both variables are set, compare and update as needed
        if ! grep -qw "${bastille_releasesdir}/${FSTAB_RELEASE}.*${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille" "${FSTAB_CONFIG}"; then
            info "Updating fstab..."
            sed -i '' "s|${FSTAB_CURRENT}|${FSTAB_NEWCONF}|" "${FSTAB_CONFIG}"
        fi
    fi
}

generate_config() {
    # Attempt to read previous config file and set required variables accordingly
    # If we can't get a valid interface, fallback to lo1 and warn user
    info "Generating jail.conf..."
    DEVFS_RULESET=4

    if [ "${FILE_EXT}" = ".zip" ]; then
        # Gather some bits from foreign/iocage config files
        JSON_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/config.json"
        if [ -n "${JSON_CONFIG}" ]; then
            IPV4_CONFIG=$(grep -wo '\"ip4_addr\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/ip4_addr://')
            IPV6_CONFIG=$(grep -wo '\"ip6_addr\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/ip6_addr://')
            DEVFS_RULESET=$(grep -wo '\"devfs_ruleset\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/devfs_ruleset://')
            DEVFS_RULESET=${DEVFS_RULESET:-4}
            IS_THIN_JAIL=$(grep -wo '\"basejail\": .*' "${JSON_CONFIG}" | tr -d '" ,' | sed 's/basejail://')
            CONFIG_RELEASE=$(grep -wo '\"release\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/release://' | sed 's/\-[pP].*//')
            IS_VNET_JAIL=$(grep -wo '\"vnet\": .*' "${JSON_CONFIG}" | tr -d '" ,' | sed 's/vnet://')
            VNET_DEFAULT_INTERFACE=$(grep -wo '\"vnet_default_interface\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/vnet_default_interface://')
            ALLOW_EMPTY_DIRS_TO_BE_SYMLINKED=1
            if [ "${VNET_DEFAULT_INTERFACE}" = "auto" ]; then
                # Grab the default ipv4 route from netstat and pull out the interface
                VNET_DEFAULT_INTERFACE=$(netstat -nr4 | grep default | cut -w -f 4)
            fi
        fi
    elif [ "${FILE_EXT}" = ".tar.gz" ]; then
        # Gather some bits from foreign/ezjail config files
        PROP_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/prop.ezjail-${FILE_TRIM}-*"
        if [ -n "${PROP_CONFIG}" ]; then
            IPVX_CONFIG=$(grep -wo "jail_${TARGET_TRIM}_ip=.*" ${PROP_CONFIG} | tr -d '" ' | sed "s/jail_${TARGET_TRIM}_ip=//")
            CONFIG_RELEASE=$(echo ${PROP_CONFIG} | grep -o '[0-9]\{2\}\.[0-9]_RELEASE' | sed 's/_/-/g')
        fi
        # Always assume it's thin for ezjail
        IS_THIN_JAIL=1
    fi

    # See if we need to generate a vnet network section
    if [ "${IS_VNET_JAIL:-0}" = "1" ]; then
        NETBLOCK=$(generate_vnet_jail_netblock "${TARGET_TRIM}" "" "${VNET_DEFAULT_INTERFACE}")
        vnet_requirements
    else
        # If there are multiple IP/NIC let the user configure network
        if [ -n "${IPV4_CONFIG}" ]; then
            if ! echo "${IPV4_CONFIG}" | grep -q '.*,.*'; then
                NETIF_CONFIG=$(echo "${IPV4_CONFIG}" | grep '.*|' | sed 's/|.*//g')
                if [ -z "${NETIF_CONFIG}" ]; then
                    config_netif
                fi
                IPX_ADDR="ip4.addr"
                IP_CONFIG="${IPV4_CONFIG}"
                IP6_MODE="disable"
            fi
        elif [ -n "${IPV6_CONFIG}" ]; then
            if ! echo "${IPV6_CONFIG}" | grep -q '.*,.*'; then
                NETIF_CONFIG=$(echo "${IPV6_CONFIG}" | grep '.*|' | sed 's/|.*//g')
                if [ -z "${NETIF_CONFIG}" ]; then
                    config_netif
                fi
                IPX_ADDR="ip6.addr"
                IP_CONFIG="${IPV6_CONFIG}"
                IP6_MODE="new"
            fi
        elif [ -n "${IPVX_CONFIG}" ]; then
            if ! echo "${IPVX_CONFIG}" | grep -q '.*,.*'; then
                NETIF_CONFIG=$(echo "${IPVX_CONFIG}" | grep '.*|' | sed 's/|.*//g')
                if [ -z "${NETIF_CONFIG}" ]; then
                    config_netif
                fi
                IPX_ADDR="ip4.addr"
                IP_CONFIG="${IPVX_CONFIG}"
                IP6_MODE="disable"
                if echo "${IPVX_CONFIG}" | sed 's/.*|//' | grep -Eq '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$))'; then
                    IPX_ADDR="ip6.addr"
                    IP6_MODE="new"
                fi
            fi
        fi

        # Let the user configure network manually
        if [ -z "${NETIF_CONFIG}" ]; then
            NETIF_CONFIG="lo1"
            IPX_ADDR="ip4.addr"
            IP_CONFIG="-"
            IP6_MODE="disable"
            warn "Warning: See 'bastille edit ${TARGET_TRIM} jail.conf' for manual network configuration."
        fi

        NETBLOCK=$(cat <<-EOF
  interface = ${NETIF_CONFIG};
  ${IPX_ADDR} = ${IP_CONFIG};
  ip6 = ${IP6_MODE};
EOF
        )
    fi

    if [ "${IS_THIN_JAIL:-0}" = "1" ]; then
        if [ -z "${CONFIG_RELEASE}" ]; then
            # Fallback to host version
            CONFIG_RELEASE=$(freebsd-version | sed 's/\-[pP].*//')
            warn "Warning: ${CONFIG_RELEASE} was set by default!"
        fi
        mkdir "${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille"
        echo "${bastille_releasesdir}/${CONFIG_RELEASE} ${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille nullfs ro 0 0" \
        >> "${bastille_jailsdir}/${TARGET_TRIM}/fstab"

        # Work with the symlinks
        cd "${bastille_jailsdir}/${TARGET_TRIM}/root"
        update_symlinks
    else
        # Generate new empty fstab file
        touch "${bastille_jailsdir}/${TARGET_TRIM}/fstab"
    fi

    # Generate a basic jail configuration file on foreign imports
    cat << EOF > "${bastille_jailsdir}/${TARGET_TRIM}/jail.conf"
${TARGET_TRIM} {
  devfs_ruleset = ${DEVFS_RULESET};
  enforce_statfs = 2;
  exec.clean;
  exec.consolelog = ${bastille_logsdir}/${TARGET_TRIM}_console.log;
  exec.start = '/bin/sh /etc/rc';
  exec.stop = '/bin/sh /etc/rc.shutdown';
  host.hostname = ${TARGET_TRIM};
  mount.devfs;
  mount.fstab = ${bastille_jailsdir}/${TARGET_TRIM}/fstab;
  path = ${bastille_jailsdir}/${TARGET_TRIM}/root;
  securelevel = 2;

${NETBLOCK}
}
EOF
}

update_config() {
    # Update an existing jail configuration
    # The config on select archives does not provide a clear way to determine
    # the base release, so lets try to get it from the base/COPYRIGHT file,
    # otherwise warn user and fallback to host system release
    CONFIG_RELEASE=$(grep -wo 'releng/[0-9]\{2\}.[0-9]/COPYRIGHT' "${bastille_jailsdir}/${TARGET_TRIM}/root/COPYRIGHT" | sed 's|releng/||;s|/COPYRIGHT|-RELEASE|')
    if [ -z "${CONFIG_RELEASE}" ]; then
        # Fallback to host version
        CONFIG_RELEASE=$(freebsd-version | sed 's/\-[pP].*//')
        warn "Warning: ${CONFIG_RELEASE} was set by default!"
    fi
    mkdir "${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille"
    echo "${bastille_releasesdir}/${CONFIG_RELEASE} ${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille nullfs ro 0 0" \
    >> "${bastille_jailsdir}/${TARGET_TRIM}/fstab"

    # Work with the symlinks
    cd "${bastille_jailsdir}/${TARGET_TRIM}/root"
    update_symlinks
}

workout_components() {
    if [ "${FILE_EXT}" = ".tar" ]; then
        # Workaround to determine the tarball path/components before extract(assumes path/jails/target)
        JAIL_PATH=$(tar -tvf ${bastille_backupsdir}/${TARGET} | grep -wo "/.*/jails/${TARGET_TRIM}" | tail -n1)
        JAIL_DIRS=$(echo ${JAIL_PATH} | grep -o '/' | wc -l)
        DIRS_PLUS=$(expr ${JAIL_DIRS} + 1)

        # Workaround to determine the jail.conf path before extract(assumes path/qjail.config/target)
        JAIL_CONF=$(tar -tvf ${bastille_backupsdir}/${TARGET} | grep -wo "/.*/qjail.config/${TARGET_TRIM}")
        CONF_TRIM=$(echo ${JAIL_CONF} | grep -o '/' | wc -l)
    fi
}

vnet_requirements() {
    # VNET jib script requirement
    if [ ! "$(command -v jib)" ]; then
        if [ -f "/usr/share/examples/jails/jib" ] && [ ! -f "/usr/local/bin/jib" ]; then
            install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib
        else
            warn "Warning: Unable to locate/install jib script required by VNET jails."
        fi
    fi
}

config_netif() {
    # Get interface from bastille configuration
    if [ -n "${bastille_network_loopback}" ]; then
        NETIF_CONFIG="${bastille_network_loopback}"
    elif [ -n "${bastille_network_shared}" ]; then
        NETIF_CONFIG="${bastille_network_shared}"
    else
        NETIF_CONFIG=
    fi
}

update_symlinks() {
    # Work with the symlinks
    SYMLINKS="bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/ports usr/sbin usr/share usr/src"

    # Just warn user to bootstrap the release if missing
    if [ ! -d "${bastille_releasesdir}/${CONFIG_RELEASE}" ]; then
        warn "Warning: ${CONFIG_RELEASE} must be bootstrapped. See 'bastille bootstrap'."
    fi

    # Update old symlinks
    info "Updating symlinks..."
    for _link in ${SYMLINKS}; do
        if [ -L "${_link}" ]; then
            ln -sf /.bastille/${_link} ${_link}
        elif [ "${ALLOW_EMPTY_DIRS_TO_BE_SYMLINKED:-0}" = "1" -a -d "${_link}" ]; then
            # -F will enforce that the directory is empty and replaced by the symlink
            ln -sfF /.bastille/${_link} ${_link} || EXIT_CODE=$?
            if [ "${EXIT_CODE:-0}" != "0" ]; then
                # Assume that the failure was due to the directory not being empty and explain the problem in friendlier terms
                warn "Warning: directory ${_link} on imported jail was not empty and will not be updated by Bastille"
            fi
        fi
    done
}

create_zfs_datasets() {
    # Prepare the ZFS environment and restore from file
    info "Importing '${TARGET_TRIM}' from foreign compressed ${FILE_EXT} archive."
    info "Preparing ZFS environment..."

    # Create required ZFS datasets, mountpoint inherited from system
    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root"
}

remove_zfs_datasets() {
    # Perform cleanup on failure
    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root"
    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
    error_exit "Failed to extract files from '${TARGET}' archive."
}

jail_import() {
    # Attempt to import container from file
    FILE_TRIM=$(echo "${TARGET}" | sed 's/\.xz//g;s/\.gz//g;s/\.tgz//g;s/\.txz//g;s/\.zip//g;s/\.tar\.gz//g;s/\.tar//g')
    FILE_EXT=$(echo "${TARGET}" | sed "s/${FILE_TRIM}//g")
    if [ -d "${bastille_jailsdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ "${FILE_EXT}" = ".xz" ]; then
                    validate_archive
                    # Import from compressed xz on ZFS systems
                    info "Importing '${TARGET_TRIM}' from compressed ${FILE_EXT} image."
                    info "Receiving ZFS data stream..."
                    xz ${bastille_decompress_xz_options} "${bastille_backupsdir}/${TARGET}" | \
                    zfs receive ${OPT_ZRECV} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"

                    # Update ZFS mountpoint property if required
                    update_zfsmount
                elif [ "${FILE_EXT}" = ".gz" ]; then
                    validate_archive
                    # Import from compressed xz on ZFS systems
                    info "Importing '${TARGET_TRIM}' from compressed ${FILE_EXT} image."
                    info "Receiving ZFS data stream..."
                    gzip ${bastille_decompress_gz_options} "${bastille_backupsdir}/${TARGET}" | \
                    zfs receive ${OPT_ZRECV} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"

                    # Update ZFS mountpoint property if required
                    update_zfsmount

                elif [ "${FILE_EXT}" = ".txz" ]; then
                    validate_archive
                    # Prepare the ZFS environment and restore from existing .txz file
                    create_zfs_datasets

                    # Extract required files to the new datasets
                    info "Extracting files from '${TARGET}' archive..."
                    tar --exclude='root' -Jxf "${bastille_backupsdir}/${TARGET}" --strip-components 1 -C "${bastille_jailsdir}/${TARGET_TRIM}"
                    tar -Jxf "${bastille_backupsdir}/${TARGET}" --strip-components 2 -C "${bastille_jailsdir}/${TARGET_TRIM}/root" "${TARGET_TRIM}/root"
                    if [ "$?" -ne 0 ]; then
                        remove_zfs_datasets
                    fi
                elif [ "${FILE_EXT}" = ".tgz" ]; then
                    validate_archive
                    # Prepare the ZFS environment and restore from existing .tgz file
                    create_zfs_datasets

                    # Extract required files to the new datasets
                    info "Extracting files from '${TARGET}' archive..."
                    tar --exclude='root' -xf "${bastille_backupsdir}/${TARGET}" --strip-components 1 -C "${bastille_jailsdir}/${TARGET_TRIM}"
                    tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components 2 -C "${bastille_jailsdir}/${TARGET_TRIM}/root" "${TARGET_TRIM}/root"
                    if [ "$?" -ne 0 ]; then
                        remove_zfs_datasets
                    fi
                elif [ "${FILE_EXT}" = ".zip" ]; then
                    validate_archive
                    # Attempt to import a foreign/iocage container
                    info "Importing '${TARGET_TRIM}' from foreign compressed ${FILE_EXT} archive."
                    # Sane bastille ZFS options
                    ZFS_OPTIONS=$(echo ${bastille_zfs_options} | sed 's/-o//g')

                    # Extract required files from the zip archive
                    cd "${bastille_backupsdir}" && unzip -j "${TARGET}"
                    if [ "$?" -ne 0 ]; then
                        error_exit "Failed to extract files from '${TARGET}' archive."
                        rm -f "${FILE_TRIM}" "${FILE_TRIM}_root"
                    fi
                    info "Receiving ZFS data stream..."
                    zfs receive ${OPT_ZRECV} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}" < "${FILE_TRIM}"
                    zfs set ${ZFS_OPTIONS} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
                    zfs receive ${OPT_ZRECV} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root" < "${FILE_TRIM}_root"

                    # Update ZFS mountpoint property if required
                    update_zfsmount

                    # Keep old configuration files for user reference
                    if [ -f "${bastille_jailsdir}/${TARGET_TRIM}/fstab" ]; then
                        mv "${bastille_jailsdir}/${TARGET_TRIM}/fstab" "${bastille_jailsdir}/${TARGET_TRIM}/fstab.old"
                    fi

                    # Cleanup unwanted files
                    rm -f "${FILE_TRIM}" "${FILE_TRIM}_root"

                    # Generate fstab and jail.conf files
                    generate_config
                elif [ "${FILE_EXT}" = ".tar.gz" ]; then
                    # Attempt to import a foreign/ezjail container
                    # Prepare the ZFS environment and restore from existing .tar.gz file
                    create_zfs_datasets

                    # Extract required files to the new datasets
                    info "Extracting files from '${TARGET}' archive..."
                    tar --exclude='ezjail/' -xf "${bastille_backupsdir}/${TARGET}" -C "${bastille_jailsdir}/${TARGET_TRIM}"
                    tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components 1 -C "${bastille_jailsdir}/${TARGET_TRIM}/root"
                    if [ "$?" -ne 0 ]; then
                        remove_zfs_datasets
                    else
                        generate_config
                    fi
                elif [ "${FILE_EXT}" = ".tar" ]; then
                    # Attempt to import a foreign/qjail container
                    # Prepare the ZFS environment and restore from existing .tar file
                    create_zfs_datasets
                    workout_components

                    # Extract required files to the new datasets
                    info "Extracting files from '${TARGET}' archive..."
                    tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components "${CONF_TRIM}" -C "${bastille_jailsdir}/${TARGET_TRIM}" "${JAIL_CONF}"
                    tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components "${DIRS_PLUS}" -C "${bastille_jailsdir}/${TARGET_TRIM}/root" "${JAIL_PATH}"
                    if [ -f "${bastille_jailsdir}/${TARGET_TRIM}/${TARGET_TRIM}" ]; then
                        mv "${bastille_jailsdir}/${TARGET_TRIM}/${TARGET_TRIM}" "${bastille_jailsdir}/${TARGET_TRIM}/jail.conf"
                    fi

                    if [ "$?" -ne 0 ]; then
                        remove_zfs_datasets
                    else
                        update_config
                    fi
                elif [ -z "${FILE_EXT}" ]; then
                    if echo "${TARGET}" | grep -q '_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}$'; then
                        validate_archive
                        # Based on the file name, looks like we are importing a raw bastille image
                        # Import from uncompressed image file
                        info "Importing '${TARGET_TRIM}' from uncompressed image archive."
                        info "Receiving ZFS data stream..."
                        zfs receive ${OPT_ZRECV} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}" < "${bastille_backupsdir}/${TARGET}"

                        # Update ZFS mountpoint property if required
                        update_zfsmount
                    else
                        # Based on the file name, looks like we are importing from previous redirected bastille image
                        # Quietly import from previous redirected bastille image
                        if ! zfs receive ${OPT_ZRECV} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}"; then
                            exit 1
                        else
                            # Update ZFS mountpoint property if required
                            update_zfsmount
                        fi
                    fi
                else
                    error_exit "Unknown archive format."
                fi
            fi
        else
            # Import from standard supported archives on UFS systems
            if [ "${FILE_EXT}" = ".txz" ]; then
                info "Extracting files from '${TARGET}' archive..."
                tar -Jxf  "${bastille_backupsdir}/${TARGET}" -C "${bastille_jailsdir}"
            elif [ "${FILE_EXT}" = ".tgz" ]; then
                info "Extracting files from '${TARGET}' archive..."
                tar -xf  "${bastille_backupsdir}/${TARGET}" -C "${bastille_jailsdir}"
            elif [ "${FILE_EXT}" = ".tar.gz" ]; then
                # Attempt to import/configure foreign/ezjail container
                info "Extracting files from '${TARGET}' archive..."
                mkdir "${bastille_jailsdir}/${TARGET_TRIM}"
                tar -xf "${bastille_backupsdir}/${TARGET}" -C "${bastille_jailsdir}/${TARGET_TRIM}"
                mv "${bastille_jailsdir}/${TARGET_TRIM}/ezjail" "${bastille_jailsdir}/${TARGET_TRIM}/root"
                generate_config
            elif [ "${FILE_EXT}" = ".tar" ]; then
                # Attempt to import/configure foreign/qjail container
                info "Extracting files from '${TARGET}' archive..."
                mkdir -p "${bastille_jailsdir}/${TARGET_TRIM}/root"
                workout_components
                tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components "${CONF_TRIM}" -C "${bastille_jailsdir}/${TARGET_TRIM}" "${JAIL_CONF}"
                tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components "${DIRS_PLUS}" -C "${bastille_jailsdir}/${TARGET_TRIM}/root" "${JAIL_PATH}"
                if [ -f "${bastille_jailsdir}/${TARGET_TRIM}/${TARGET_TRIM}" ]; then
                    mv "${bastille_jailsdir}/${TARGET_TRIM}/${TARGET_TRIM}" "${bastille_jailsdir}/${TARGET_TRIM}/jail.conf"
                fi
                update_config
            else
                error_exit "Unsupported archive format."
            fi
        fi

        if [ "$?" -ne 0 ]; then
            error_exit "Failed to import from '${TARGET}' archive."
        else
            # Update the jail.conf and fstab if required
            # This is required on foreign imports only
            update_jailconf
            update_fstab
            if [ -z "${USER_IMPORT}" ]; then
                info "Container '${TARGET_TRIM}' imported successfully."
            fi
            exit 0
        fi
    else
        error_exit "Jails directory/dataset does not exist. See 'bastille bootstrap'."
    fi
}

# Check for user specified file location
if echo "${TARGET}" | grep -q '\/'; then
    GETDIR="${TARGET}"
    TARGET=$(echo ${TARGET} | awk -F '\/' '{print $NF}')
    bastille_backupsdir=$(echo ${GETDIR} | sed "s/${TARGET}//")
fi

# Check if backups directory/dataset exist
if [ ! -d "${bastille_backupsdir}" ]; then
    error_exit "Backups directory/dataset does not exist. See 'bastille bootstrap'."
fi

# Check if archive exist then trim archive name
if [ -f "${bastille_backupsdir}/${TARGET}" ]; then
    # Filter unsupported/unknown archives
    if echo "${TARGET}" | grep -q '_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.xz$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.gz$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.tgz$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.txz$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}.zip$\|-[0-9]\{12\}.[0-9]\{2\}.tar.gz$\|@[0-9]\{12\}.[0-9]\{2\}.tar$'; then
        if ls "${bastille_backupsdir}" | awk "/^${TARGET}$/" >/dev/null; then
            TARGET_TRIM=$(echo "${TARGET}" | sed "s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.xz//;s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.gz//;s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.tgz//;s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.txz//;s/_[0-9]*-[0-9]*-[0-9]*.zip//;s/-[0-9]\{12\}.[0-9]\{2\}.tar.gz//;s/@[0-9]\{12\}.[0-9]\{2\}.tar//;s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*//")
        fi
    else
        error_exit "Unrecognized archive name."
    fi
else
    if echo "${TARGET}" | grep -q '_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.*$'; then
        error_exit "Archive '${TARGET}' not found."
    else
        # Assume user will import from standard input
        TARGET_TRIM=${TARGET}
        USER_IMPORT="1"
    fi
fi

# Check if a running jail matches name or already exist
if [ -n "$(/usr/sbin/jls name | awk "/^${TARGET_TRIM}$/")" ]; then
    error_exit "A running jail matches name."
elif [ -n "${TARGET_TRIM}" ]; then
    if [ -d "${bastille_jailsdir}/${TARGET_TRIM}" ]; then
        error_exit "Container: ${TARGET_TRIM} already exists."
    fi
fi

if [ -n "${TARGET}" ]; then
    jail_import
fi
