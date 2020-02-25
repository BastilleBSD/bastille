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
    echo -e "${COLOR_RED}Usage: bastille import backup_file.${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

TARGET="${1}"
shift

error_notify() {
    # Notify message on error and exit
    echo -e "$*" >&2
    exit 1
}

validate_archive() {
    # Compare checksums on the target archive
    if [ -f "${bastille_backupsdir}/${TARGET}" ]; then
        echo -e "${COLOR_GREEN}Validating file: ${TARGET}...${COLOR_RESET}"
        SHA256_DIST=$(cat ${bastille_backupsdir}/${FILE_TRIM}.sha256)
        SHA256_FILE=$(sha256 -q ${bastille_backupsdir}/${TARGET})
        if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
            error_notify "${COLOR_RED}Failed validation for ${TARGET}.${COLOR_RESET}"
        else
            echo -e "${COLOR_GREEN}File validation successful!${COLOR_RESET}"
        fi
    fi
}

update_zfsmount() {
    # Update the mountpoint property on the received zfs data stream
    OLD_ZFS_MOUNTPOINT=$(zfs get -H mountpoint ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root | awk '{print $3}')
    NEW_ZFS_MOUNTPOINT="${bastille_jailsdir}/${TARGET_TRIM}/root"
    if [ "${NEW_ZFS_MOUNTPOINT}" != "${OLD_ZFS_MOUNTPOINT}" ]; then
        echo -e "${COLOR_GREEN}Updating zfs mountpoint...${COLOR_RESET}"
        zfs set mountpoint=${bastille_jailsdir}/${TARGET_TRIM}/root ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root
    fi
}

update_jailconf() {
    # Update jail.conf paths
    JAIL_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/jail.conf"
    if [ -f "${JAIL_CONFIG}" ]; then
        if ! grep -qw "path = ${bastille_jailsdir}/${TARGET_TRIM}/root;" ${JAIL_CONFIG}; then
            echo -e "${COLOR_GREEN}Updating jail.conf...${COLOR_RESET}"
            sed -i '' "s|exec.consolelog = .*;|exec.consolelog = ${bastille_logsdir}/${TARGET_TRIM}_console.log;|" ${JAIL_CONFIG}
            sed -i '' "s|path = .*;|path = ${bastille_jailsdir}/${TARGET_TRIM}/root;|" ${JAIL_CONFIG}
            sed -i '' "s|mount.fstab = .*;|mount.fstab = ${bastille_jailsdir}/${TARGET_TRIM}/fstab;|" ${JAIL_CONFIG}
        fi
    fi
}

update_fstab() {
    # Update fstab .bastille mountpoint on thin containers only
    # Set some variables
    FSTAB_CONFIG="${bastille_jailsdir}/${TARGET_TRIM}/fstab"
    FSTAB_RELEASE=$(grep -owE '([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-2]|-stable-build-[0-9]{1,3})' ${FSTAB_CONFIG})
    FSTAB_CURRENT=$(grep -w ".*/releases/.*/jails/${TARGET_TRIM}/root/.bastille" ${FSTAB_CONFIG})
    FSTAB_NEWCONF="${bastille_releasesdir}/${FSTAB_RELEASE} ${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille nullfs ro 0 0"
    if [ -n "${FSTAB_CURRENT}" ] && [ -n "${FSTAB_NEWCONF}" ]; then
        # If both variables are set, compare and update as needed
        if ! grep -qw "${bastille_releasesdir}/${FSTAB_RELEASE}.*${bastille_jailsdir}/${TARGET_TRIM}/root/.bastille" ${FSTAB_CONFIG}; then
            echo -e "${COLOR_GREEN}Updating fstab...${COLOR_RESET}"
            sed -i '' "s|${FSTAB_CURRENT}|${FSTAB_NEWCONF}|" ${FSTAB_CONFIG}
        fi
    fi
}

jail_import() {
    # Attempt to import container from file
    FILE_TRIM=$(echo ${TARGET} | sed 's/.[txz]\{2,3\}//')
    FILE_EXT=$(echo ${TARGET} | cut -d '.' -f2)
    validate_archive
    if [ -d "${bastille_jailsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                if [ "${FILE_EXT}" = "xz" ]; then
                    # Import from compressed xz on ZFS systems
                    echo -e "${COLOR_GREEN}Importing '${TARGET_TRIM}' from compressed .${FILE_EXT} archive.${COLOR_RESET}"
                    echo -e "${COLOR_GREEN}Receiving zfs data stream...${COLOR_RESET}"
                    xz ${bastille_decompress_xz_options} ${bastille_backupsdir}/${TARGET} | \
                    zfs receive -u ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}

                    # Update ZFS mountpoint property if required
                    # This is required on foreign imports only
                    update_zfsmount

                    # Mount new container ZFS datasets
                    zfs mount ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}
                    zfs mount ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root
                elif [ "${FILE_EXT}" = "txz" ]; then
                    # Prepare the ZFS environment and restore from existing tar.xz file
                    echo -e "${COLOR_GREEN}Importing '${TARGET_TRIM}' form .${FILE_EXT} archive.${COLOR_RESET}"
                    echo -e "${COLOR_GREEN}Preparing zfs environment...${COLOR_RESET}"
                    zfs create ${bastille_zfs_options} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}
                    zfs create ${bastille_zfs_options} -o mountpoint=${bastille_jailsdir}/${TARGET_TRIM}/root \
                    ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}/root

                    # Extract required files to the new datasets
                    echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
                    tar --exclude='root' -Jxf ${bastille_backupsdir}/${TARGET} --strip-components 1 -C ${bastille_jailsdir}/${TARGET_TRIM} 
                    tar -Jxf ${bastille_backupsdir}/${TARGET} --strip-components 2 -C ${bastille_jailsdir}/${TARGET_TRIM}/root ${TARGET_TRIM}/root
                    if [ $? -ne 0 ]; then
                        zfs destroy -r ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET_TRIM}
                        error_notify "${COLOR_RED}Failed to extract files from '${TARGET}' archive.${COLOR_RESET}"
                    fi
                else
                    error_notify "${COLOR_RED}Unknown archive format.${COLOR_RESET}"
                fi
            fi
        else
            # Import from standard tar.xz archive on UFS systems
            echo -e "${COLOR_GREEN}Extracting files from '${TARGET}' archive...${COLOR_RESET}"
            tar -Jxf  ${bastille_backupsdir}/${TARGET} -C ${bastille_jailsdir}
        fi

        if [ $? -ne 0 ]; then
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

# Check if backups directory/dataset exist
if [ ! -d "${bastille_backupsdir}" ]; then
    error_notify "${COLOR_RED}Backups directory/dataset does not exist, See 'bastille bootstrap'.${COLOR_RESET}"
fi

# Check if archive exist then trim archive name
if [ "$(ls "${bastille_backupsdir}" | awk "/^${TARGET}$/")" ]; then
    TARGET_TRIM=$(echo ${TARGET} | sed "s/_[0-9]*-[0-9]*-[0-9]*-[0-9]*.[txz]\{2,3\}//")
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
