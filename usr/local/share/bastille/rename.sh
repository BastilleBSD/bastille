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
    echo -e "${COLOR_RED}Usage: bastille rename [TARGET] [NEW_NAME].${COLOR_RESET}"
    exit 1
}

error_notify() {
    # Notify message on error and exit
    echo -e "$*" >&2
    exit 1
}

# Handle special-case commands first
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 2 ] || [ $# -lt 2 ]; then
    usage
fi

TARGET="${1}"
NEWNAME="${2}"
shift

if echo "${NEWNAME}" | grep -q "[.]"; then
    echo -e "${COLOR_RED}Container names may not contain a dot(.)!${COLOR_RESET}"
    exit 1
fi

update_jailconf() {
    # Update jail.conf
    JAIL_CONFIG="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    if [ -f "${JAIL_CONFIG}" ]; then
        if ! grep -qw "path = ${bastille_jailsdir}/${NEWNAME}/root;" "${JAIL_CONFIG}"; then
            sed -i '' "s|host.hostname = ${TARGET};|host.hostname = ${NEWNAME};|" "${JAIL_CONFIG}"
            sed -i '' "s|exec.consolelog = .*;|exec.consolelog = ${bastille_logsdir}/${NEWNAME}_console.log;|" "${JAIL_CONFIG}"
            sed -i '' "s|path = .*;|path = ${bastille_jailsdir}/${NEWNAME}/root;|" "${JAIL_CONFIG}"
            sed -i '' "s|mount.fstab = .*;|mount.fstab = ${bastille_jailsdir}/${NEWNAME}/fstab;|" "${JAIL_CONFIG}"
            sed -i '' "s|${TARGET} {|${NEWNAME} {|" "${JAIL_CONFIG}"
        fi
    fi
}

update_fstab() {
    # Update fstab to use the new name
    FSTAB_CONFIG="${bastille_jailsdir}/${NEWNAME}/fstab"
    if [ -f "${FSTAB_CONFIG}" ]; then
        FSTAB_RELEASE=$(grep -owE '([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-2])|([0-9]{1,2}-stable-build-[0-9]{1,3})|(current-build)-([0-9]{1,3})|(current-BUILD-LATEST)|([0-9]{1,2}-stable-BUILD-LATEST)|(current-BUILD-LATEST)' "${FSTAB_CONFIG}")
        FSTAB_CURRENT=$(grep -w ".*/releases/.*/jails/${TARGET}/root/.bastille" "${FSTAB_CONFIG}")
        FSTAB_NEWCONF="${bastille_releasesdir}/${FSTAB_RELEASE} ${bastille_jailsdir}/${NEWNAME}/root/.bastille nullfs ro 0 0"
        if [ -n "${FSTAB_CURRENT}" ] && [ -n "${FSTAB_NEWCONF}" ]; then
            # If both variables are set, update as needed
            if ! grep -qw "${bastille_releasesdir}/${FSTAB_RELEASE}.*${bastille_jailsdir}/${NEWNAME}/root/.bastille" "${FSTAB_CONFIG}"; then
                sed -i '' "s|${FSTAB_CURRENT}|${FSTAB_NEWCONF}|" "${FSTAB_CONFIG}"
            fi
        fi
    fi
}

change_name() {
    # Attempt container name change
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        echo -e "${COLOR_GREEN}Attempting to rename '${TARGET}' to ${NEWNAME}...${COLOR_RESET}"
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                # Rename ZFS dataset and mount points accordingly
                zfs rename "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}"
                zfs set mountpoint="${bastille_jailsdir}/${NEWNAME}/root" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}/root"
            fi
        else
            # Just rename the jail directory
            mv "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
        fi
    else
        error_notify "${COLOR_RED}${TARGET} not found. See bootstrap.${COLOR_RESET}"
    fi

    # Update jail configuration files accordingly
    update_jailconf
    update_fstab

    # Remove the old jail directory if exist
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        rm -r "${bastille_jailsdir}/${TARGET}"
    fi
    if [ "$?" -ne 0 ]; then
        error_notify "${COLOR_RED}An error has occurred while attempting to rename '${TARGET}'.${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}Renamed '${TARGET}' to '${NEWNAME}' successfully.${COLOR_RESET}"
    fi
}

# Check if container is running
if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
    error_notify "${COLOR_RED}${TARGET} is running, See 'bastille stop'.${COLOR_RESET}"
fi

change_name
