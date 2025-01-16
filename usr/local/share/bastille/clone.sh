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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_exit "Usage: bastille clone TARGET NEW_NAME IPADDRESS"
}

# Handle special-case commands first
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -ne 2 ]; then
    usage
fi

bastille_root_check

NEWNAME="${1}"
IP="${2}"

validate_ip() {
    IPX_ADDR="ip4.addr"
    IP6_MODE="disable"
    ip6=$(echo "${IP}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$))')
    if [ -n "${ip6}" ]; then
        info "Valid: (${ip6})."
        IPX_ADDR="ip6.addr"
        # shellcheck disable=SC2034
        IP6_MODE="new"
    else
        local IFS
        if echo "${IP}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${IP}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "Invalid: (${TEST_IP})"
                fi
            done
            if ifconfig | grep -qwF "${TEST_IP}"; then
                warn "Warning: IP address already in use (${TEST_IP})."
            else
                info "Valid: (${IP})."
            fi
        else
            error_exit "Invalid: (${IP})."
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
    # Determine number of interfaces and define a uniq_epair
    local _if_list="$(grep -Eo 'epair[0-9]+|bastille[0-9]+' ${JAIL_CONFIG} | sort -u)"
    for _if in ${_if_list}; do
        local _epair_if_count="$(grep -Eo 'epair[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
        local _bastille_if_count="$(grep -Eo 'bastille[0-9]+' ${bastille_jailsdir}/*/jail.conf | sort -u | wc -l | awk '{print $1}')"
        local epair_num_range=$((_epair_if_count + 1))
        local bastille_num_range=$((_bastille_if_count + 1))
        if echo ${_if} | grep -Eoq 'epair[0-9]+'; then
            # Update bridged VNET config
            for _num in $(seq 0 "${epair_num_range}"); do
                if ! grep -oq "epair${_num}" ${bastille_jailsdir}/*/jail.conf; then
                    # Update jail.conf epair name
                    local uniq_epair_bridge="${_num}"
                    local _if_epaira="${_if}a"
                    local _if_epairb="${_if}b"
                    local _if_vnet="$(grep ${_if_epairb} "${bastille_jail_rc_conf}" | grep -Eo -m 1 "vnet[0-9]+")"
                    sed -i '' "s|${_if}|epair${uniq_epair_bridge}|g" "${JAIL_CONFIG}"
                    # If jail had a static MAC, generate one for clone
                    if grep ether ${JAIL_CONFIG} | grep -qoc epair${uniq_epair_bridge}; then
                        local external_interface="$(grep "epair${uniq_epair_bridge}" ${JAIL_CONFIG} | grep -o '[^ ]* addm' | awk '{print $1}')"
                        generate_static_mac "${NEWNAME}" "${external_interface}"
                        sed -i '' "s|epair${uniq_epair_bridge}a ether.*:.*:.*:.*:.*:.*a\";|epair${uniq_epair_bridge}a ether ${macaddr}a\";|" "${JAIL_CONFIG}"
                        sed -i '' "s|epair${uniq_epair_bridge}b ether.*:.*:.*:.*:.*:.*b\";|epair${uniq_epair_bridge}b ether ${macaddr}b\";|" "${JAIL_CONFIG}"
                    fi
                    sed -i '' "s|vnet host interface for Bastille jail ${TARGET}|vnet host interface for Bastille jail ${NEWNAME}|g" "${JAIL_CONFIG}"
                    # Update /etc/rc.conf
                    sed -i '' "s|${_if_epairb}_name|epair${uniq_epair_bridge}b_name|" "${bastille_jail_rc_conf}"
                    if grep "vnet0" "${bastille_jail_rc_conf}" | grep -q "epair${uniq_epair_bridge}b_name"; then
                        if [ "${IP}" = "0.0.0.0" ]; then
                            sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="SYNCDHCP"
                        else
                            sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="inet ${IP}"
                        fi
                    else
                        sysrc -f "${bastille_jail_rc_conf}" ifconfig_${_if_vnet}="SYNCDHCP"
                    fi
                    break
                fi
            done
        elif echo ${_if} | grep -Eoq 'bastille[0-9]+'; then
            # Update VNET config
            for _num in $(seq 0 "${bastille_num_range}"); do
                if ! grep -oq "bastille${_num}" ${bastille_jailsdir}/*/jail.conf; then
                    # Update jail.conf epair name
                    local uniq_epair="bastille${_num}"
                    local _if_vnet="$(grep ${_if} "${bastille_jail_rc_conf}" | grep -Eo -m 1 "vnet[0-9]+")"
                    sed -i '' "s|${_if}|${uniq_epair}|g" "${JAIL_CONFIG}"
                    # If jail had a static MAC, generate one for clone
                    if grep ether ${JAIL_CONFIG} | grep -qoc ${uniq_epair}; then
                        local external_interface="$(grep ${uniq_epair} ${JAIL_CONFIG} | grep -o 'addm.*' | awk '{print $3}' | sed 's/["|;]//g')"
                        generate_static_mac "${NEWNAME}" "${external_interface}"
                        sed -i '' "s|${uniq_epair} ether.*:.*:.*:.*:.*:.*a\";|${uniq_epair} ether ${macaddr}a\";|" "${JAIL_CONFIG}"
                        sed -i '' "s|${uniq_epair} ether.*:.*:.*:.*:.*:.*b\";|${uniq_epair} ether ${macaddr}b\";|" "${JAIL_CONFIG}"
                    fi
                    sed -i '' "s|vnet host interface for Bastille jail ${TARGET}|vnet host interface for Bastille jail ${NEWNAME}|g" "${JAIL_CONFIG}"
                    # Update /etc/rc.conf
                    sed -i '' "s|ifconfig_e0b_${_if}_name|ifconfig_e0b_${uniq_epair}_name|" "${bastille_jail_rc_conf}"
                    if grep "vnet0" "${bastille_jail_rc_conf}" | grep -q ${uniq_epair}; then
                        if [ "${IP}" = "0.0.0.0" ]; then
                            sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="SYNCDHCP"
                        else
                            sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0=" inet ${IP} "
                        fi
                    else
                        sysrc -f "${bastille_jail_rc_conf}" ifconfig_${_if_vnet}="SYNCDHCP"
                    fi
                    break
                fi
            done
        fi
    done
}

update_fstab() {
    # Update fstab to use the new name
    FSTAB_CONFIG="${bastille_jailsdir}/${NEWNAME}/fstab"
    if [ -f "${FSTAB_CONFIG}" ]; then
        # Update additional fstab paths with new jail path
        sed -i '' "s|${bastille_jailsdir}/${TARGET}/root/|${bastille_jailsdir}/${NEWNAME}/root/|" "${FSTAB_CONFIG}"
    fi
}

clone_jail() {
    # Attempt container clone
    info "Attempting to clone '${TARGET}' to ${NEWNAME}..."
    if ! [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then
        if checkyesno bastille_zfs_enable; then
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
            if [ -n "$(/usr/sbin/jls name | awk "/^${TARGET}$/")" ]; then
                error_exit "${TARGET} is running. See 'bastille stop ${TARGET}'."
            fi

            # Perform container file copy(archive mode)
            cp -a "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
        fi
    else
        error_exit "${NEWNAME} already exists."
    fi

    # Generate jail configuration files
    update_jailconf
    update_fstab

    # Display the exist status
    if [ "$?" -ne 0 ]; then
        error_exit "An error has occurred while attempting to clone '${TARGET}'."
    else
        info "Cloned '${TARGET}' to '${NEWNAME}' successfully."
    fi
}

## don't allow for dots(.) in container names
if echo "${NEWNAME}" | grep -q "[.]"; then
    error_exit "Container names may not contain a dot(.)!"
fi

## check if ip address is valid
if [ -n "${IP}" ]; then
    validate_ip
else
    usage
fi

clone_jail
