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

# Validate jail state
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else
    info "\n[${TARGET}]:"
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

validate_name() {

    local NAME_VERIFY="${NEWNAME}"
    local NAME_SANITY="$(echo "${NAME_VERIFY}" | tr -c -d 'a-zA-Z0-9-_')"

    if [ -n "$(echo "${NAME_SANITY}" | awk "/^[-_].*$/" )" ]; then
        error_exit "[ERROR]: Jail names may not begin with (-|_) characters!"
    elif [ "${NAME_VERIFY}" != "${NAME_SANITY}" ]; then
        error_exit "[ERROR]: Jail names may not contain special characters!"
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
            sed -i '' "s|^${TARGET}.*{$|${NEWNAME} {|" "${_jail_conf}"
        fi
        if grep -qo "vnet;" "${_jail_conf}"; then
            update_jailconf_vnet
        fi
    fi
}

update_jailconf_vnet() {

    local _jail_conf="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local _rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"

    # Change bastille interface name (only needed for bridged epairs)
    # We still gather interface names for JIB and JNG managed interfaces (for future use)
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        local _if_list="$(grep -Eo 'e[0-9]+a_[^;" ]+' ${_jail_conf} | sort -u)"
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local _if_list="$(grep -Eo 'ng[0-9]+_[^;" ]+' ${_jail_conf} | sort -u)"
    fi

    for _if in ${_if_list}; do

        local _old_if_prefix="$(echo ${_if} | awk -F'_' '{print $1}')"
        local _old_if_suffix="$(echo ${_if} | awk -F'_' '{print $2}')"

        # For if_bridge network type
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then

            local _epair_num="$(echo "${_old_if_prefix}" | grep -Eo "[0-9]+")"
            local _old_host_epair="${_if}"
            local _old_jail_epair="${_old_if_prefix%a}b_${_old_if_suffix}"

            if [ "$(echo -n "e${_epair_num}a_${NEWNAME}" | awk '{print length}')" -lt 16 ]; then
                # Generate new epair name
                local _new_host_epair="e${_epair_num}a_${NEWNAME}"
                local _new_jail_epair="e${_epair_num}b_${NEWNAME}"
            else
	        name_prefix="$(echo ${NEWNAME} | cut -c1-7)"
	        name_suffix="$(echo ${NEWNAME} | rev | cut -c1-2 | rev)"
    	        local _new_host_epair="e${_epair_num}a_${name_prefix}xx${name_suffix}"
                local _new_jail_epair="e${_epair_num}b_${name_prefix}xx${name_suffix}"
            fi

            local _new_if_prefix="$(echo ${_new_host_epair} | awk -F'_' '{print $1}')"
            local _new_if_suffix="$(echo ${_new_host_epair} | awk -F'_' '{print $2}')"

            if grep "${_old_if_suffix}" "${_jail_conf}" | grep -oq "jib addm"; then
                # For -V jails
                # Replace host epair name in jail.conf                  
                sed -i '' "s|jib addm ${_old_if_suffix}|jib addm ${_new_if_suffix}|g" "${_jail_conf}"
                sed -i '' "s|${_old_host_epair} ether|${_new_host_epair} ether|g" "${_jail_conf}"
                sed -i '' "s|destroy ${_old_if_suffix}|destroy ${_new_if_suffix}|g" "${_jail_conf}"
                sed -i '' "s|${_old_host_epair} description|${_new_host_epair} description|g" "${_jail_conf}"

                # Replace jail epair name in jail.conf
                sed -i '' "s|= ${_old_jail_epair};|= ${_new_jail_epair};|g" "${_jail_conf}"
                sed -i '' "s|${_old_jail_epair} ether|${_new_jail_epair} ether|g" "${_jail_conf}"

                # Replace epair description
                sed -i '' "s|host interface for Bastille jail ${TARGET}|host interface for Bastille jail ${NEWNAME}|g" "${_jail_conf}"

                # Replace epair name in /etc/rc.conf
                sed -i '' "/ifconfig/ s|${_old_jail_epair}|${_new_jail_epair}|g" "${_rc_conf}"
            else
                # For -B jails
                # Replace host epair name in jail.conf                  
                sed -i '' "s|up name ${_old_host_epair}|up name ${_new_host_epair}|g" "${_jail_conf}"
                sed -i '' "s|addm ${_old_host_epair}|addm ${_new_host_epair}|g" "${_jail_conf}"
                sed -i '' "s|${_old_host_epair} ether|${_new_host_epair} ether|g" "${_jail_conf}"
                sed -i '' "s|deletem ${_old_host_epair}|deletem ${_new_host_epair}|g" "${_jail_conf}"
                sed -i '' "s|${_old_host_epair} destroy|${_new_host_epair} destroy|g" "${_jail_conf}"
                sed -i '' "s|${_old_host_epair} description|${_new_host_epair} description|g" "${_jail_conf}"

                # Replace jail epair name in jail.conf
                sed -i '' "s|= ${_old_jail_epair};|= ${_new_jail_epair};|g" "${_jail_conf}"
                sed -i '' "s|up name ${_old_jail_epair}|up name ${_new_jail_epair}|g" "${_jail_conf}"
                sed -i '' "s|${_old_jail_epair} ether|${_new_jail_epair} ether|g" "${_jail_conf}"

                # Replace epair description
                sed -i '' "s|host interface for Bastille jail ${TARGET}|host interface for Bastille jail ${NEWNAME}|g" "${_jail_conf}"

                # Replace epair name in /etc/rc.conf
                sed -i '' "/ifconfig/ s|${_old_jail_epair}|${_new_jail_epair}|g" "${_rc_conf}"
            fi
        # For netgraph network type
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        
            local _ngif_num="$(echo "${_old_if_prefix}" | grep -Eo "[0-9]+")"
            local _old_ngif="${_if}"

            if [ "$(echo -n "ng${_ngif_num}_${NEWNAME}" | awk '{print length}')" -lt 16 ]; then
                # Generate new netgraph interface name
                local _new_ngif="ng${_ngif_num}_${NEWNAME}"
            else
	        name_prefix="$(echo ${NEWNAME} | cut -c1-7)"
	        name_suffix="$(echo ${NEWNAME} | rev | cut -c1-2 | rev)"
    	        local _new_ngif="ng${_ngif_num}_${name_prefix}xx${name_suffix}"
            fi

            local _new_if_prefix="$(echo ${_if} | awk -F'_' '{print $1}')"
            local _new_if_suffix="$(echo ${_if} | awk -F'_' '{print $2}')"

            # Replace netgraph interface name                
            sed -i '' "s|jng bridge ${_old_if_suffix}|jng bridge ${_new_if_suffix}|g" "${_jail_conf}"
            sed -i '' "s|${_old_ngif} ether|${_new_ngif} ether|g" "${_jail_conf}"
            sed -i '' "s|jng shutdown ${_old_if_suffix}|jng shutdown ${_new_if_suffix}|g" "${_jail_conf}"

            # Replace jail epair name in jail.conf
            sed -i '' "s|= ${_old_ngif};|= ${_new_ngif};|g" "${_jail_conf}"

            # Replace epair name in /etc/rc.conf
            sed -i '' "/ifconfig/ s|${_old_ngif}|${_new_ngif}|g" "${_rc_conf}"
        fi
    done
}

change_name() {

    # Attempt container name change
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
                    error_exit "[ERROR]: Can't rename '${TARGET}' dataset."
                fi
            else
                error_exit "[ERROR]: Can't determine the ZFS origin path of '${TARGET}'."
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
        error_exit "[ERROR]: An error has occurred while attempting to rename '${TARGET}'."
    else
        echo "Renamed '${TARGET}' to '${NEWNAME}' successfully."
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
    error_exit "[ERROR]: Jail: ${NEWNAME} already exists."
fi

info "\nAttempting to rename '${TARGET}' to ${NEWNAME}..."

change_name

info "\nRenamed '${TARGET}' to '${NEWNAME}' successfully.\n"
