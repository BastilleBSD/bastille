#!/bin/sh
#
# Copyright (c) 2018-2024, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille clone [option(s)] TARGET NEW_NAME IP_ADDRESS"
    cat << EOF
    Options:

    -f | --force          Stop the jail if it is running. Cannot be used with [-l|--live].
    -l | --live           Clone a running jail. ZFS only. Jail must be running. Cannot be used with [-f|--force].
    -s | --start          Start jail(s) when complete.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
LIVE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -l|--live)
            if ! checkyesno bastille_zfs_enable; then
                error_exit "[-l|--live] can only be used with ZFS."
            else
                LIVE=1
                shift
            fi
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    l) LIVE=1 ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\"" ;; 
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "${AUTO}" -eq 1 ] && [ "${LIVE}" -eq 1 ]; then
    error_exit "[-a|--auto] cannot be used with [-l|--live]"
fi

if [ $# -ne 3 ]; then
    usage
fi

TARGET="${1}"
NEWNAME="${2}"
IP="${3}"

bastille_root_check
set_target_single "${TARGET}"

## don't allow for dots(.) in container names
if echo "${NEWNAME}" | grep -q "[.]"; then
    error_exit "Container names may not contain a dot(.)!"
fi

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
        fi
    fi

    if grep -qw "vnet;" "${JAIL_CONFIG}"; then
        update_jailconf_vnet
    else
        _ip4="$(bastille config ${TARGET} get ip4.addr | sed 's/,/ /g')"
        _ip6="$(bastille config ${TARGET} get ip6.addr | sed 's/,/ /g')"
        # IP4
        if [ "${_ip4}" != "not set" ]; then
            for _ip in ${_ip4}; do
                _ip="$(echo ${_ip} | awk -F"|" '{print $2}')"
                sed -i '' "/${IPX_ADDR} = .*/ s/${_ip}/${IP}/" "${JAIL_CONFIG}"
                sed -i '' "/${IPX_ADDR} += .*/ s/${_ip}/127.0.0.1/" "${JAIL_CONFIG}"
            done
        fi
        # IP6
        if [ "${_ip6}" != "not set" ]; then
            for _ip in ${_ip6}; do
                _ip="$(echo ${_ip} | awk -F"|" '{print $2}')"
                sed -i '' "/${IPX_ADDR} = .*/ s/${_ip}/${IP}/" "${JAIL_CONFIG}"
                sed -i '' "/${IPX_ADDR} += .*/ s/${_ip}/127.0.0.1/" "${JAIL_CONFIG}"
            done
        fi
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
        local bastille_num_range=$((_vnet_if_count + 1))
        if echo ${_if} | grep -Eoq 'epair[0-9]+'; then
            # Update bridged VNET config
            for _num in $(seq 0 "${epair_num_range}"); do
                if ! grep -oq "epair${_num}" ${bastille_jailsdir}/*/jail.conf; then
                    # Update jail.conf epair name
                    local uniq_epair_bridge="${_num}"
                    local _if_epaira="$(grep "${_if}" ${JAIL_CONFIG} | grep -Eo -m 1 "epair[1-9]+a")"
                    local _if_epairb="$(grep "${_if}" ${JAIL_CONFIG} | grep -Eo -m 1 "epair[1-9]+b")"
                    local _if_vnet="$(grep ${_if_epairb} "${bastille_jail_rc_conf}" | grep -Eo -m 1 "vnet[1-9]+")"
                    sed -i '' "s|${_if}|epair${uniq_epair_bridge}|g" "${JAIL_CONFIG}"
                    # since we don't have access to the external_interface variable, we cat the jail.conf file to retrieve the mac prefix
                    # we also do not use the main generate_static_mac function here
                    if grep -oq ${_if} ${JAIL_CONFIG} | grep -oq ether; then
                        local macaddr_prefix="$(cat ${JAIL_CONFIG} | grep ${_if} | grep -m 1 ether | grep -oE '([0-9a-f]{2}(:[0-9a-f]{2}){5})' | awk -F: '{print $1":"$2":"$3}')"
                        local macaddr_suffix="$(echo -n ${NEWNAME} | sha256 | cut -b -5 | sed 's/\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F]\)/\1:\2:\3/')"
                        local macaddr="${macaddr_prefix}:${macaddr_suffix}"
                        sed -i '' "s|epair${uniq_epair}a ether.*:.*:.*:.*:.*:.*a\";|epair${uniq_epair}a ether ${macaddr}a\";|" "${JAIL_CONFIG}"
                        sed -i '' "s|epair${uniq_epair}b ether.*:.*:.*:.*:.*:.*b\";|epair${uniq_epair}b ether ${macaddr}b\";|" "${JAIL_CONFIG}"
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
                    # since we don't have access to the external_interface variable, we cat the jail.conf file to retrieve the mac prefix
                    # we also do not use the main generate_static_mac function here
                    if grep -oq ${_if} ${JAIL_CONFIG} | grep -oq ether; then
                        local macaddr_prefix="$(cat ${JAIL_CONFIG} | grep ${_if} | grep -m 1 ether | grep -oE '([0-9a-f]{2}(:[0-9a-f]{2}){5})' | awk -F: '{print $1":"$2":"$3}')"
                        local macaddr_suffix="$(echo -n ${NEWNAME} | sha256 | cut -b -5 | sed 's/\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F]\)/\1:\2:\3/')"
                        local macaddr="${macaddr_prefix}:${macaddr_suffix}"
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

clone_jail() {

    info "Attempting to clone ${TARGET} to ${NEWNAME}..."

    if ! [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ "${LIVE}" -eq 1 ]; then
                check_target_is_running "${TARGET}" || error_exit "[-l|--live] can only be used with a running jail."
            else check_target_is_stopped "${TARGET}" || if [ "${FORCE}" -eq 1 ]; then
                    bastille stop "${TARGET}"
                else
                    error_notify "Jail is running."
                    error_exit "Use [-f|--force] to force stop the jail, or [-l|--live] (ZFS only) to clone a running jail."
                fi
            fi
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
            # Perform container file copy (archive mode)
            check_target_is_stopped "${TARGET}" || if [ "${FORCE}" -eq 1 ]; then
                bastille stop "${TARGET}"
            else
                error_notify "Jail is running."
                error_exit "Use [-f|--force] to force stop the jail."
            fi
            cp -a "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
        fi
    else
        error_exit "${NEWNAME} already exists."
    fi

    # Generate jail configuration files
    update_jailconf
    update_fstab "${TARGET}" "${NEWNAME}"

    # Display the exist status
    if [ "$?" -ne 0 ]; then
        error_exit "An error has occurred while attempting to clone '${TARGET}'."
    else
        info "Cloned '${TARGET}' to '${NEWNAME}' successfully."
    fi
    if [ "${START}" -eq 1 ]; then
        if [ "${LIVE}" -eq 0 ]; then
            bastille start "${TARGET}"
        fi
        bastille start "${NEWNAME}"
    fi
}

# Check if IP address is valid.
if [ -n "${IP}" ]; then
    validate_ip
else
    usage
fi

clone_jail