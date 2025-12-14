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

    -a | --auto      Auto mode. Start/stop jail(s) if required.
    -x | --debug     Enable debug mode.

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
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
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

    if echo "${NAME_VERIFY}" | grep -q "[.]"; then
        error_exit "[ERROR]: Jail names may not contain a dot(.)!"
    elif [ -n "$(echo "${NAME_SANITY}" | awk "/^[-_].*$/" )" ]; then
        error_exit "[ERROR]: Jail names may not begin with (-|_) characters!"
    elif [ "${NAME_VERIFY}" != "${NAME_SANITY}" ]; then
        error_exit "[ERROR]: Jail names may not contain special characters!"
    fi
}

update_jailconf() {

    # Update jail.conf
    local jail_config="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local jail_rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"

    if [ -f "${jail_config}" ]; then
        if ! grep -qw "path = ${bastille_jailsdir}/${NEWNAME}/root;" "${jail_config}"; then
            sed -i '' "s|host.hostname.*=.*${TARGET};|host.hostname = ${NEWNAME};|" "${jail_config}"
            sed -i '' "s|exec.consolelog.*=.*;|exec.consolelog = ${bastille_logsdir}/${NEWNAME}_console.log;|" "${jail_config}"
            sed -i '' "s|path.*=.*;|path = ${bastille_jailsdir}/${NEWNAME}/root;|" "${jail_config}"
            sed -i '' "s|mount.fstab.*=.*;|mount.fstab = ${bastille_jailsdir}/${NEWNAME}/fstab;|" "${jail_config}"
            sed -i '' "s|^${TARGET}.*{$|${NEWNAME} {|" "${jail_config}"
        fi
        if grep -qo "vnet;" "${jail_config}"; then
            update_jailconf_vnet
        fi
    fi
}

update_jailconf_vnet() {

    local jail_config="${bastille_jailsdir}/${NEWNAME}/jail.conf"
    local jail_rc_conf="${bastille_jailsdir}/${NEWNAME}/root/etc/rc.conf"

    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        local if_list="$(grep -Eo 'e[0-9]+a_[^;" ]+' ${jail_config} | sort -u)"
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local if_list="$(grep -Eo 'ng[0-9]+_[^;" ]+' ${jail_config} | sort -u)"
    fi

    for if in ${if_list}; do

        local old_if_prefix="$(echo ${if} | awk -F'_' '{print $1}')"
        local old_if_suffix="$(echo ${if} | awk -F'_' '{print $2}')"

        # For if_bridge network type
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then

            local epair_num="$(echo "${old_if_prefix}" | grep -Eo "[0-9]+")"
            local old_host_epair="${if}"
            local old_jail_epair="${old_if_prefix%a}b_${old_if_suffix}"

            if [ "$(echo -n "e${epair_num}a_${NEWNAME}" | awk '{print length}')" -lt 16 ]; then
                # Generate new epair name
                local new_host_epair="e${epair_num}a_${NEWNAME}"
                local new_jail_epair="e${epair_num}b_${NEWNAME}"
            else
                if echo "${old_if_suffix}" | grep -Eosq "bastille[0-9]+"; then
                    local new_host_epair="e${epair_num}a_${old_if_suffix}"
                    local new_jail_epair="e${epair_num}b_${old_if_suffix}"
                else
                    get_bastille_epair_count
                    local bastille_epair_num=1
                    while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${bastille_epair_num}"; do
                        bastille_epair_num=$((bastille_epair_num + 1))
                    done
                    local new_host_epair="e${epair_num}a_bastille${bastille_epair_num}"
                    local new_jail_epair="e${epair_num}b_bastille${bastille_epair_num}"
                fi
            fi

            local new_if_prefix="$(echo ${new_host_epair} | awk -F'_' '{print $1}')"
            local new_if_suffix="$(echo ${new_host_epair} | awk -F'_' '{print $2}')"

            if grep "${old_if_suffix}" "${jail_config}" | grep -oq "jib addm"; then
                # For -V jails
                # Replace host epair name in jail.conf
                sed -i '' "s|jib addm ${old_if_suffix}\>|jib addm ${new_if_suffix}|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} ether|${new_host_epair} ether|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} destroy|${new_host_epair} destroy|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} description|${new_host_epair} description|g" "${jail_config}"

                # Replace jail epair name in jail.conf
                sed -i '' "s|= ${old_jail_epair};|= ${new_jail_epair};|g" "${jail_config}"
                sed -i '' "s|\<${old_jail_epair} ether|${new_jail_epair} ether|g" "${jail_config}"

                # Replace epair description
                sed -i '' "s|host interface for Bastille jail ${TARGET}\>|host interface for Bastille jail ${NEWNAME}|g" "${jail_config}"

                # Replace epair name in /etc/rc.conf
                sed -i '' "s|ifconfig_${old_jail_epair}_name|ifconfig_${new_jail_epair}_name|g" "${jail_rc_conf}"
            else
                # For -B jails
                # Replace host epair name in jail.conf
                sed -i '' "s|up name ${old_host_epair}\>|up name ${new_host_epair}|g" "${jail_config}"
                sed -i '' "s|addm ${old_host_epair}\>|addm ${new_host_epair}|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} ether|${new_host_epair} ether|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} destroy|${new_host_epair} destroy|g" "${jail_config}"
                sed -i '' "s|\<${old_host_epair} description|${new_host_epair} description|g" "${jail_config}"

                # Replace jail epair name in jail.conf
                sed -i '' "s|= ${old_jail_epair};|= ${new_jail_epair};|g" "${jail_config}"
                sed -i '' "s|up name ${old_jail_epair}\>|up name ${new_jail_epair}|g" "${jail_config}"
                sed -i '' "s|\<${old_jail_epair} ether|${new_jail_epair} ether|g" "${jail_config}"

                # Replace epair description
                sed -i '' "s|host interface for Bastille jail ${TARGET}\>|host interface for Bastille jail ${NEWNAME}|g" "${jail_config}"

                # Replace epair name in /etc/rc.conf
                sed -i '' "s|ifconfig_${old_jail_epair}_name|ifconfig_${new_jail_epair}_name|g" "${jail_rc_conf}"
            fi
        # For netgraph network type
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then

            local ngif_num="$(echo "${old_if_prefix}" | grep -Eo "[0-9]+")"
            local old_ngif="${if}"
            # Generate new netgraph interface name
            local new_ngif="ng${ngif_num}_${NEWNAME}"
            # shellcheck disable=SC2034
            local new_if_prefix="$(echo ${new_ngif} | awk -F'_' '{print $1}')"
            local new_if_suffix="$(echo ${new_ngif} | awk -F'_' '{print $2}')"

            # Replace netgraph interface name
            sed -i '' "s|jng bridge ${old_if_suffix}\>|jng bridge ${new_if_suffix}|g" "${jail_config}"
            sed -i '' "s|\<${old_ngif} ether|${new_ngif} ether|g" "${jail_config}"
            sed -i '' "s|jng shutdown ${old_if_suffix}\>|jng shutdown ${new_if_suffix}|g" "${jail_config}"

            # Replace jail epair name in jail.conf
            sed -i '' "s|= ${old_ngif};|= ${new_ngif};|g" "${jail_config}"

            # Replace epair name in /etc/rc.conf
            sed -i '' "s|ifconfig_${old_ngif}_name|ifconfig_${new_ngif}_name|g" "${jail_rc_conf}"
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
