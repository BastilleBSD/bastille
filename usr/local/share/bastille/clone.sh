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
    echo -e "${COLOR_RED}Usage: bastille clone [TARGET] [NEW_NAME] [IPADRESS].${COLOR_RESET}"
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

if [ $# -ne 3 ]; then
    usage
fi

TARGET="${1}"
NEWNAME="${2}"
IP="${3}"
shift

validate_ip() {
    IPX_ADDR="ip4.addr"
    IP6_MODE="disable"
    ip6=$(echo "${IP}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$))')
    if [ -n "${ip6}" ]; then
        echo -e "${COLOR_GREEN}Valid: (${ip6}).${COLOR_RESET}"
        IPX_ADDR="ip6.addr"
        IP6_MODE="new"
    else
        local IFS
        if echo "${IP}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${IP}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    echo "Invalid: (${TEST_IP})"
                    exit 1
                fi
            done
            if ifconfig | grep -qw "${TEST_IP}"; then
                echo -e "${COLOR_YELLOW}Warning: ip address already in use (${TEST_IP}).${COLOR_RESET}"
            else
                echo -e "${COLOR_GREEN}Valid: (${IP}).${COLOR_RESET}"
            fi
        else
            echo -e "${COLOR_RED}Invalid: (${IP}).${COLOR_RESET}"
            exit 1
        fi
    fi
}

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
            sed -i '' "s|${IPX_ADDR} = .*;|${IPX_ADDR} = ${IP};|" "${JAIL_CONFIG}"
        fi
    fi

    if grep -qw "vnet;" "${JAIL_CONFIG}"; then
        update_jailconf_vnet
    fi
}

update_jailconf_vnet() {
    bastille_jail_rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"

    # Determine number of containers and define an uniq_epair
    local list_jails_num=$(bastille list jails | wc -l | awk '{print $1}')
    local num_range=$(expr "${list_jails_num}" + 1)
    jail_list=$(bastille list jail)
    for _num in $(seq 0 "${num_range}"); do
        if [ -n "${jail_list}" ]; then
            if ! grep -q "e0b_bastille${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                uniq_epair="bastille${_num}"
                sed -i '' "s|vnet.interface = e0b_bastille.*;|vnet.interface = e0b_${uniq_epair};|" "${JAIL_CONFIG}"
                break
            fi
        fi
    done

    # Rename interface to new uniq_epair
    sed -i '' "s|ifconfig_e0b_bastille.*_name|ifconfig_e0b_${uniq_epair}_name|" "${bastille_jail_rc_conf}"

    # If 0.0.0.0 set DHCP, else set static IP address
    if [ "${IP}" == "0.0.0.0" ]; then
        sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="DHCP"
    else
        sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="inet ${IP}"
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

clone_jail() {
    # Attempt container clone
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        echo -e "${COLOR_GREEN}Attempting to clone '${TARGET}' to ${NEWNAME}...${COLOR_RESET}"
        if ! [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then
            if [ "${bastille_zfs_enable}" = "YES" ]; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    # Replicate the existing container
                    DATE=$(date +%F-%H%M%S)
                    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_clone_${DATE}"
                    zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_clone_${DATE}" | zfs recv "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}"

                    # Cleanup source temporary snapshots
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}/root@bastille_clone_${DATE}"
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@bastille_clone_${DATE}"

                    # Cleanup target temporary snapshots
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}/root@bastille_clone_${DATE}"
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}@bastille_clone_${DATE}"
                fi
            else
                # Just clone the jail directory
                # Check if container is running
                if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
                    error_notify "${COLOR_RED}${TARGET} is running, See 'bastille stop ${TARGET}'.${COLOR_RESET}"
                fi

                # Perform container file copy(archive mode)
                cp -a "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
            fi
        else
            error_notify "${COLOR_RED}${NEWNAME} already exists.${COLOR_RESET}"
        fi
    else
        error_notify "${COLOR_RED}${TARGET} not found. See bootstrap.${COLOR_RESET}"
    fi

    # Generate jail configuration files
    update_jailconf
    update_fstab

    # Display the exist status
    if [ "$?" -ne 0 ]; then
        error_notify "${COLOR_RED}An error has occurred while attempting to clone '${TARGET}'.${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}Cloned '${TARGET}' to '${NEWNAME}' successfully.${COLOR_RESET}"
    fi
}

## don't allow for dots(.) in container names
if echo "${NEWNAME}" | grep -q "[.]"; then
    echo -e "${COLOR_RED}Container names may not contain a dot(.)!${COLOR_RESET}"
    exit 1
fi

## check if ip address is valid
if [ -n "${IP}" ]; then
    validate_ip
else
    usage
fi

clone_jail
