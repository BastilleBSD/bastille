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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille import file [option].${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 2 ] || [ $# -lt 1 ]; then
    usage
fi

TARGET="${1}"
OPTION="${2}"
shift

error_notify() {
    # Notify message on error and exit
    echo -e "$*" >&2
    exit 1
}

validate_archive() {
    # Compare checksums on the target archive
    # Skip validation for unsupported archives
    if [ "${FILE_EXT}" != ".tar.gz" ] && [ "${FILE_EXT}" != ".tar" ]; then
        if [ -f "${bastille_backupsdir}/${TARGET}" ]; then
            if [ -f "${bastille_backupsdir}/${FILE_TRIM}.sha256" ]; then
                echo -e "${COLOR_GREEN}Validating file: ${TARGET}...${COLOR_RESET}"
                SHA256_DIST=$(cat "${bastille_backupsdir}/${FILE_TRIM}.sha256")
                SHA256_FILE=$(sha256 -q "${bastille_backupsdir}/${TARGET}")
                if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
                    error_notify "${COLOR_RED}Failed validation for ${TARGET}.${COLOR_RESET}"
                else
                    echo -e "${COLOR_GREEN}File validation successful!${COLOR_RESET}"
                fi
            else
                # Check if user opt to force import
                if [ "${OPTION}" = "-f" -o "${OPTION}" = "force" ]; then
                    echo -e "${COLOR_YELLOW}Warning: Skipping archive validation!${COLOR_RESET}"
                else
                    error_notify "${COLOR_RED}Checksum file not found, See 'bastille import TARGET -f'${COLOR_RESET}"
                fi
            fi
        fi
    else
        echo -e "${COLOR_YELLOW}Warning: Skipping archive validation!${COLOR_RESET}"
    fi
}

update_zfsmount() {
    # Update the mountpoint property on the received zfs data stream
    OLD_ZFS_MOUNTPOINT=$(zfs get -H mountpoint "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root" | awk '{print $3}')
    NEW_ZFS_MOUNTPOINT="${bastille_jailsdir}/${TARGET_TRIM}/root"
    if [ "${NEW_ZFS_MOUNTPOINT}" != "${OLD_ZFS_MOUNTPOINT}" ]; then
        echo -e "${COLOR_GREEN}Updating zfs mountpoint...${COLOR_RESET}"
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
            echo -e "${COLOR_GREEN}Updating jail.conf...${COLOR_RESET}"
            sed -i '' "s|exec.consolelog.*= .*;|exec.consolelog = ${bastille_logsdir}/${TARGET_TRIM}_console.log;|" "${JAIL_CONFIG}"
            sed -i '' "s|path.*= .*;|path = ${bastille_jailsdir}/${TARGET_TRIM}/root;|" "${JAIL_CONFIG}"
            sed -i '' "s|mount.fstab.*= .*;|mount.fstab = ${bastille_jailsdir}/${TARGET_TRIM}/fstab;|" "${JAIL_CONFIG}"
        fi
    fi
}

update_fstab() {
    # Update fstab .bastille mountpoint on thin containers only
    # Set some variables
    FSTAB_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/fstab"
    FSTAB_RELEASE=$(grep -owE '([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-2])|([0-9]{1,2}-stable-build-[0-9]{1,3})|(current-build)-([0-9]{1,3})|(current-BUILD-LATEST)|([0-9]{1,2}-stable-BUILD-LATEST)|(current-BUILD-LATEST)' "${FSTAB_CONFIG}")
    FSTAB_CURRENT=$(grep -w ".*/releases/.*/jails/${TARGET_TRIM}/root/.bastille" "${FSTAB_CONFIG}")
    FSTAB_NEWCONF="${bastille_releasesdir}/${FSTAB_RELEASE} ${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille nullfs ro 0 0"
    if [ -n "${FSTAB_CURRENT}" ] && [ -n "${FSTAB_NEWCONF}" ]; then
        # If both variables are set, compare and update as needed
        if ! grep -qw "${bastille_releasesdir}/${FSTAB_RELEASE}.*${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille" "${FSTAB_CONFIG}"; then
            echo -e "${COLOR_GREEN}Updating fstab...${COLOR_RESET}"
            sed -i '' "s|${FSTAB_CURRENT}|${FSTAB_NEWCONF}|" "${FSTAB_CONFIG}"
        fi
    fi
}

generate_config() {
    # Attempt to read previous config file and set required variables accordingly
    # If we can't get a valid interface, fallback to lo1 and warn user
    echo -e "${COLOR_GREEN}Generating jail.conf...${COLOR_RESET}"

    if [ "${FILE_EXT}" = ".zip" ]; then
        # Gather some bits from foreign/iocage config files
        JSON_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/config.json"
        if [ -f "${JSON_CONFIG}" ]; then
            IPV4_CONFIG=$(grep -wo '\"ip4_addr\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/ip4_addr://')
            IPV6_CONFIG=$(grep -wo '\"ip6_addr\": \".*\"' "${JSON_CONFIG}" | tr -d '" ' | sed 's/ip6_addr://')
        fi
    elif [ "${FILE_EXT}" = ".tar.gz" ]; then
        # Gather some bits from foreign/ezjail config files
        PROP_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/prop.ezjail-${FILE_TRIM}-*"
        if [ -f "${PROP_CONFIG}" ]; then
            IPVX_CONFIG=$(grep -wo "jail_${TARGET_TRIM}_ip=.*" ${PROP_CONFIG} | tr -d '" ' | sed "s/jail_${TARGET_TRIM}_ip=//")
        fi
    fi

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
        echo -e "${COLOR_YELLOW}Warning: See 'bastille edit ${TARGET_TRIM} jail.conf' for manual network configuration${COLOR_RESET}"
    fi

    if [ "${FILE_EXT}" = ".tar.gz" ]; then
        CONFIG_RELEASE=$(echo ${PROP_CONFIG} | grep -o '[0-9]\{2\}\.[0-9]_RELEASE' | sed 's/_/-/g')
        if [ -z "${CONFIG_RELEASE}" ]; then
            # Fallback to host version
            CONFIG_RELEASE=$(freebsd-version | sed 's/\-[pP].*//')
            echo -e "${COLOR_YELLOW}Warning: ${CONFIG_RELEASE} was set by default!${COLOR_RESET}"
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
  devfs_ruleset = 4;
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

  interface = ${NETIF_CONFIG};
  ${IPX_ADDR} = ${IP_CONFIG};
  ip6 = ${IP6_MODE};
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
        echo -e "${COLOR_YELLOW}Warning: ${CONFIG_RELEASE} was set by default!${COLOR_RESET}"
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

config_netif() {
    # Get interface from bastille configuration
    if [ -n "${bastille_jail_interface}" ]; then
        NETIF_CONFIG="${bastille_jail_interface}"
    elif [ -n "${bastille_jail_external}" ]; then
        NETIF_CONFIG="${bastille_jail_external}"
    else
        NETIF_CONFIG=
    fi
}

update_symlinks() {
    # Work with the symlinks
    SYMLINKS="bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/ports usr/sbin usr/share usr/src"

    # Just warn user to bootstrap the release if missing
    if [ ! -d "${bastille_releasesdir}/${CONFIG_RELEASE}" ]; then
        echo -e "${COLOR_YELLOW}Warning: ${CONFIG_RELEASE} must be bootstrapped, See 'bastille bootstrap'.${COLOR_RESET}"
    fi

    # Update old symlinks
    echo -e "${COLOR_GREEN}Updating symlinks...${COLOR_RESET}"
    for _link in ${SYMLINKS}; do
        if [ -L "${_link}" ]; then
            ln -sf /.bastille/${_link} ${_link}
        fi
    done
}

create_zfs_datasets() {
    # Prepare the ZFS environment and restore from file
    echo -e "${COLOR_GREEN}Importing '${TARGET_TRIM}' from foreign compressed ${FILE_EXT} archive.${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Preparing zfs environment...${COLOR_RESET}"

    # Create required ZFS datasets, mountpoint inherited from system
    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root"
}

remove_zfs_datasets() {
    # Perform cleanup on failure
    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root"
    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
    error_notify "${COLOR_RED}Failed to extract files from '${TARGET}' archive.${COLOR_RESET}"
}

jail_import() {
    # Attempt to import container from file
    FILE_TRIM=$(echo "${TARGET}" | sed 's/\.xz//g;s/\.txz//g;s/\.zip//g;s/\.tar\.gz//g;s/\.tar//g')
    FILE_EXT=$(echo "${TARGET}" | sed "s/${FILE_TRIM}//g")
    validate_archive
    if [ -d "${bastille_jailsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ "${FILE_EXT}" = ".xz" ]; then
                    # Import from compressed xz on ZFS systems
                    echo -e "${COLOR_GREEN}Importing '${TARGET_TRIM}' from compressed ${FILE_EXT} archive.${COLOR_RESET}"
                    echo -e "${COLOR_GREEN}Receiving zfs data stream...${COLOR_RESET}"
                    xz ${bastille_decompress_xz_options} "${bastille_backupsdir}/${TARGET}" | \
                    zfs receive -u "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"

                    # Update ZFS mountpoint property if required
                    update_zfsmount

                elif [ "${FILE_EXT}" = ".txz" ]; then
                    # Prepare the ZFS environment and restore from existing .txz file
                    create_zfs_datasets

                    # Extract required files to the new datasets
                    echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
                    tar --exclude='root' -Jxf "${bastille_backupsdir}/${TARGET}" --strip-components 1 -C "${bastille_jailsdir}/${TARGET_TRIM}"
                    tar -Jxf "${bastille_backupsdir}/${TARGET}" --strip-components 2 -C "${bastille_jailsdir}/${TARGET_TRIM}/root" "${TARGET_TRIM}/root"
                    if [ "$?" -ne 0 ]; then
                        remove_zfs_datasets
                    fi
                elif [ "${FILE_EXT}" = ".zip" ]; then
                    # Attempt to import a foreign/iocage container
                    echo -e "${COLOR_GREEN}Importing '${TARGET_TRIM}' from foreign compressed ${FILE_EXT} archive.${COLOR_RESET}"
                    # Sane bastille zfs options
                    ZFS_OPTIONS=$(echo ${bastille_zfs_options} | sed 's/-o//g')

                    # Extract required files from the zip archive
                    cd "${bastille_backupsdir}" && unzip -j "${TARGET}"
                    if [ "$?" -ne 0 ]; then
                        error_notify "${COLOR_RED}Failed to extract files from '${TARGET}' archive.${COLOR_RESET}"
                        rm -f "${FILE_TRIM}" "${FILE_TRIM}_root"
                    fi
                    echo -e "${COLOR_GREEN}Receiving zfs data stream...${COLOR_RESET}"
                    zfs receive -u "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}" < "${FILE_TRIM}"
                    zfs set ${ZFS_OPTIONS} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}"
                    zfs receive -u "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root" < "${FILE_TRIM}_root"

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
                    echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
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
                    echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
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
                else
                    error_notify "${COLOR_RED}Unknown archive format.${COLOR_RESET}"
                fi
            fi
        else
            # Import from standard supported archives on UFS systems
            if [ "${FILE_EXT}" = ".txz" ]; then
                echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
                tar -Jxf  "${bastille_backupsdir}/${TARGET}" -C "${bastille_jailsdir}"
            elif [ "${FILE_EXT}" = ".tar.gz" ]; then
                # Attempt to import/configure foreign/ezjail container
                echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
                mkdir "${bastille_jailsdir}/${TARGET_TRIM}"
                tar -xf "${bastille_backupsdir}/${TARGET}" -C "${bastille_jailsdir}/${TARGET_TRIM}"
                mv "${bastille_jailsdir}/${TARGET_TRIM}/ezjail" "${bastille_jailsdir}/${TARGET_TRIM}/root"
                generate_config
            elif [ "${FILE_EXT}" = ".tar" ]; then
                # Attempt to import/configure foreign/qjail container
                echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
                mkdir -p "${bastille_jailsdir}/${TARGET_TRIM}/root"
                workout_components
                tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components "${CONF_TRIM}" -C "${bastille_jailsdir}/${TARGET_TRIM}" "${JAIL_CONF}"
                tar -xf "${bastille_backupsdir}/${TARGET}" --strip-components "${DIRS_PLUS}" -C "${bastille_jailsdir}/${TARGET_TRIM}/root" "${JAIL_PATH}"
                if [ -f "${bastille_jailsdir}/${TARGET_TRIM}/${TARGET_TRIM}" ]; then
                    mv "${bastille_jailsdir}/${TARGET_TRIM}/${TARGET_TRIM}" "${bastille_jailsdir}/${TARGET_TRIM}/jail.conf"
                fi
                update_config
            else
                error_notify "${COLOR_RED}Unsupported archive format.${COLOR_RESET}"
            fi
        fi

        if [ "$?" -ne 0 ]; then
            error_notify "${COLOR_RED}Failed to import from '${TARGET}' archive.${COLOR_RESET}"
        else
            # Update the jail.conf and fstab if required
            # This is required on foreign imports only
            update_jailconf
            update_fstab
            echo -e "${COLOR_GREEN}Container '${TARGET_TRIM}' imported successfully.${COLOR_RESET}"
            exit 0
        fi
    else
        error_notify "${COLOR_RED}Jails directory/dataset does not exist, See 'bastille bootstrap'.${COLOR_RESET}"
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
    error_notify "${COLOR_RED}Backups directory/dataset does not exist, See 'bastille bootstrap'.${COLOR_RESET}"
fi

# Check if archive exist then trim archive name
if [ -f "${bastille_backupsdir}/${TARGET}" ]; then
    # Filter unsupported/unknown archives 
    if echo "${TARGET}" | grep -q '_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.xz$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.txz$\|_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}.zip$\|-[0-9]\{12\}.[0-9]\{2\}.tar.gz$\|@[0-9]\{12\}.[0-9]\{2\}.tar$'; then
        if ls "${bastille_backupsdir}" | awk "/^${TARGET}$/" >/dev/null; then
            TARGET_TRIM=$(echo "${TARGET}" | sed "s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.xz//;s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.txz//;s/_[0-9]*-[0-9]*-[0-9]*.zip//;s/-[0-9]\{12\}.[0-9]\{2\}.tar.gz//;s/@[0-9]\{12\}.[0-9]\{2\}.tar//")
        fi
    else
        error_notify "${COLOR_RED}Unrecognized archive name.${COLOR_RESET}"
    fi
else
    error_notify "${COLOR_RED}Archive '${TARGET}' not found.${COLOR_RESET}"
fi

# Check if a running jail matches name or already exist
if [ -n "$(jls name | awk "/^${TARGET_TRIM}$/")" ]; then
    error_notify "${COLOR_RED}A running jail matches name.${COLOR_RESET}"
elif [ -d "${bastille_jailsdir}/${TARGET_TRIM}" ]; then
    error_notify "${COLOR_RED}Container: ${TARGET_TRIM} already exist.${COLOR_RESET}"
fi

jail_import
