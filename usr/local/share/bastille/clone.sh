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

if ! [ $# == 3 ]; then
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
            set "${TEST_IP}"
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

generate_jailconf() {
    rm "${bastille_jailsdir}/${NEWNAME}/jail.conf"
    cat << EOF > "${bastille_jailsdir}/${NEWNAME}/jail.conf"
${NEWNAME} {
  devfs_ruleset = 4;
  enforce_statfs = 2;
  exec.clean;
  exec.consolelog = ${bastille_logsdir}/${NEWNAME}_console.log;
  exec.start = '/bin/sh /etc/rc';
  exec.stop = '/bin/sh /etc/rc.shutdown';
  host.hostname = ${NEWNAME};
  mount.devfs;
  mount.fstab = ${bastille_jailsdir}/${NEWNAME}/fstab;
  path = ${bastille_jailsdir}/${NEWNAME}/root;
  securelevel = 2;

  interface = ${bastille_jail_interface};
  ${IPX_ADDR} = ${IP};
  ip6 = ${IP6_MODE};
}
EOF
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
    # Attempt container name change
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        echo -e "${COLOR_GREEN}Attempting to clone '${TARGET}' to ${NEWNAME}...${COLOR_RESET}"
        if ! [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then
            if [ "${bastille_zfs_enable}" = "YES" ]; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    # Rename ZFS dataset and mount points accordingly
                    DATE=$(date +%F-%H%M%S)
                    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@cloned_$DATE"
                    zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@cloned_$DATE" | zfs recv "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}"
                    zfs destroy -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}@cloned_$DATE"
                fi
            else
                # Just clone the jail directory
                cp -R "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
            fi
        else
            error_notify "${COLOR_RED}${NEWNAME} already exists.${COLOR_RESET}"
        fi
    else
        error_notify "${COLOR_RED}${TARGET} not found. See bootstrap.${COLOR_RESET}"
    fi

    # Generate jail configuration files
    generate_jailconf
    update_fstab
}

## check if ip address is valid
if [ -n "${IP}" ]; then
    validate_ip
else
    usage
fi

clone_jail