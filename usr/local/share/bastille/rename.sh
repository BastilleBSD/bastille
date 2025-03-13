#!/bin/sh
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
    error_notify "Usage: bastille rename [option(s)] TARGET NEW_NAME"
    cat << EOF
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\""
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 2 ]; then
    usage
fi

TARGET="${1}"
NEWNAME="${2}"

bastille_root_check
set_target_single "${TARGET}"
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else   
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

validate_name() {
    local NAME_VERIFY="${NEWNAME}"
    local NAME_SANITY="$(echo "${NAME_VERIFY}" | tr -c -d 'a-zA-Z0-9-_')"
    if [ -n "$(echo "${NAME_SANITY}" | awk "/^[-_].*$/" )" ]; then
        error_exit "Container names may not begin with (-|_) characters!"
    elif [ "${NAME_VERIFY}" != "${NAME_SANITY}" ]; then
        error_exit "Container names may not contain special characters!"
    fi
}

update_jailconf() {
    # Update jail.conf
    local _jail_conf="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local _rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"
    if [ -f "${_jail_conf}" ]; then
        if ! grep -qw "path = ${bastille_jailsdir}/${NEWNAME}/root;" "${_jail_conf}"; then
            sed -i '' "s|host.hostname.*=.*${TARGET};|host.hostname = ${NEWNAME};|" "${_jail_conf}"
            sed -i '' "s|exec.consolelog.*=.*;|exec.consolelog = ${bastille_logsdir}/${NEWNAME}_console.log;|" "${_jail_conf}"
            sed -i '' "s|path.*=.*;|path = ${bastille_jailsdir}/${NEWNAME}/root;|" "${_jail_conf}"
            sed -i '' "s|mount.fstab.*=.*;|mount.fstab = ${bastille_jailsdir}/${NEWNAME}/fstab;|" "${_jail_conf}"
            sed -i '' "s|${TARGET}.*{|${NEWNAME} {|" "${_jail_conf}"
        fi
        if grep -qo "vnet;" "${_jail_conf}"; then
            update_jailconf_vnet
        fi
    fi
}

update_jailconf_vnet() {
    local _jail_conf="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local _rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"
    # Change epair name (if needed)
    local _if_list="$(grep -Eo 'epair[0-9]+|bastille[0-9]+' ${_jail_conf} | sort -u)"
    for _if in ${_if_list}; do
        if echo ${_if} | grep -Eoq 'epair[0-9]+'; then
            # Check if epair name = jail name
            local _epair_num="$(grep -Eo -m 1 "epair[0-9]+" "${_jail_conf}" | grep -Eo "[0-9]+")" 
            if grep -E "epair[0-9]+a" "${_jail_conf}" | grep -Eo "e[0-9]+a_${TARGET}"; then
                local _target_host_epair="$(grep -Eo -m 1 "e[0-9]+a_${TARGET}" "${_jail_conf}")"
                local _target_jail_epair="$(grep -Eo -m 1 "e[0-9]+b_${TARGET}" "${_jail_conf}")"
            else
                local _target_host_epair="$(grep -Eo -m 1 "epair[0-9]+a" "${_jail_conf}")"
                local _target_jail_epair="$(grep -Eo -m 1 "epair[0-9]+b" "${_jail_conf}")"
            fi
            if [ "$(echo -n "e${_epair_num}a_${NEWNAME}" | awk '{print length}')" -lt 16 ]; then
                # Generate new epair name
                local _new_host_epair="e${_epair_num}a_${NEWNAME}"
                local _new_jail_epair="e${_epair_num}b_${NEWNAME}"
            else
                local _new_host_epair="epair${_epair_num}a"
                local _new_jail_epair="epair${_epair_num}b"
            fi
            # Replace host epair name in jail.conf                  
            sed -i '' "s|up name ${_target_host_epair}|up name ${_new_host_epair}|g" "${_jail_conf}"
            sed -i '' "s|${_target_host_epair} ether|${_new_host_epair} ether|g" "${_jail_conf}"
            sed -i '' "s|deletem ${_target_host_epair}|deletem ${_new_host_epair}|g" "${_jail_conf}"
            sed -i '' "s|${_target_host_epair} destroy|${_new_host_epair} destroy|g" "${_jail_conf}"
            sed -i '' "s|${_target_host_epair} description|${_new_host_epair} description|g" "${_jail_conf}"
            # Replace jail epair name in jail.conf
            sed -i '' "s|= ${_target_jail_epair};|= ${_new_jail_epair};|g" "${_jail_conf}"
            sed -i '' "s|up name ${_target_jail_epair}|up name ${_new_jail_epair}|g" "${_jail_conf}"
            sed -i '' "s|${_target_jail_epair} ether|${_new_jail_epair} ether|g" "${_jail_conf}"
            # Replace epair description
            sed -i '' "s|vnet host interface for Bastille jail ${TARGET}|vnet host interface for Bastille jail ${NEWNAME}|g" "${_jail_conf}"
            # Replace epair name in /etc/rc.conf
            sed -i '' "/ifconfig/ s|${_target_jail_epair}|${_new_jail_epair}|g" "${_rc_conf}"
        fi
    done
}

change_name() {
    # Attempt container name change
    info "Attempting to rename '${TARGET}' to ${NEWNAME}..."
    if checkyesno bastille_zfs_enable; then
        if [ -n "${bastille_zfs_zpool}" ] && [ -n "${bastille_zfs_prefix}" ]; then
            # Check and rename container ZFS dataset accordingly
            # Perform additional checks in case of non-ZFS existing containers
            if zfs list | grep -qw "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}"; then
                if ! zfs rename -f "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${TARGET}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NEWNAME}"; then
                    error_exit "Can't rename '${TARGET}' dataset."
                fi
            else
                # Check and rename container directory instead
                if ! zfs list | grep -qw "jails/${TARGET}$"; then
                    mv "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
                fi
            fi
        fi
    else
        # Check if container is a zfs/dataset before rename attempt
        # Perform additional checks in case of bastille.conf miss-configuration
        if zfs list | grep -qw "jails/${TARGET}$"; then
            ZFS_DATASET_ORIGIN=$(zfs list | grep -w "jails/${TARGET}$" | awk '{print $1}')
            ZFS_DATASET_TARGET=$(echo "${ZFS_DATASET_ORIGIN}" | sed "s|\/${TARGET}||")
            if [ -n "${ZFS_DATASET_ORIGIN}" ] && [ -n "${ZFS_DATASET_TARGET}" ]; then
                if ! zfs rename -f "${ZFS_DATASET_ORIGIN}" "${ZFS_DATASET_TARGET}/${NEWNAME}"; then
                    error_exit "Can't rename '${TARGET}' dataset."
                fi
            else
                error_exit "Can't determine the ZFS origin path of '${TARGET}'."
            fi
        else
            # Just rename the jail directory
            mv "${bastille_jailsdir}/${TARGET}" "${bastille_jailsdir}/${NEWNAME}"
        fi
    fi

    # Update jail conf files
    update_jailconf
    update_fstab "${TARGET}" "${NEWNAME}"

    # Check exit status and notify
    if [ "$?" -ne 0 ]; then
        error_exit "An error has occurred while attempting to rename '${TARGET}'."
    else
        info "Renamed '${TARGET}' to '${NEWNAME}' successfully."
        if [ "${AUTO}" -eq 1 ]; then
            bastille start "${NEWNAME}"
        fi
    fi
}

# Validate NEW_NAME
if [ -n "${NEWNAME}" ]; then
    validate_name
fi

# Check if a jail already exists with NEW_NAME
if [ -d "${bastille_jailsdir}/${NEWNAME}" ]; then
    error_exit "Jail: ${NEWNAME} already exists."
fi

change_name
