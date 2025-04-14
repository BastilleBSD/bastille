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

# Let's set some predefined/fallback variables.
# This will try to deal with tampered config file.
bastille_config_path="/usr/local/etc/bastille"
bastille_config="${bastille_config_path}/bastille.conf"
bastille_prefix_default="/usr/local/bastille"
bastille_zfsprefix_default="bastille"
bastille_ifbridge_name="bastille1"
bastille_auto_config="0"

. /usr/local/share/bastille/common.sh
# shellcheck source=/usr/local/etc/bastille/bastille.conf
. ${bastille_config}

usage() {
    # Build an independent usage for the `setup` command.
    # No short options here for the special purpose --long-options, 
    # so we can reserve short options for future adds, also the user
    # must genuinely agreed on configuration reset/restore so let them type for it.
    error_notify "Usage: bastille setup [option]"

    cat << EOF
    Options:

    -p | --firewall                    Attempt to configure bastille PF firewall.
    -l | --loopback                    Attempt to configure network loopback interface.
    -e | --ethernet                    Attempt to configure the network shared interface.
    -v | --vnet                        Attempt to configure VNET bridge interface [bastille1].
    -z | --zfs                         Activates ZFS storage features and benefits for bastille.
    -a | --auto                        Attempt to auto-configure network, firewall and ZFS storage.
         --zfs-custom-setup            Manually configure ZFS, this is intended for advanced users.
         --conf-network-reset          Restore bastille default Network options on the config file.
         --conf-storage-reset          Restore bastille default ZFS storage options on the config file.
         --conf-restore-clean          Restore bastille default config file from bastille.conf.sample file.

EOF
    exit 1
}

input_error() {
    error_exit "Invalid user input, aborting!"
}

config_runtime() {
    # Run here variables considered to be required by bastille by default silently.
    if ! sysrc -qn bastille_enable | grep -qi "yes"; then
        sysrc bastille_enable="YES" >/dev/null 2>&1
    fi
}

# Check for too many args.
if [ "$#" -gt 1 ]; then
    usage
fi

# Handle special-case commands first.
case "${1}" in
    help|--help|-h)
        usage
        ;;
esac

user_canceled() {
    # Don't use 'error_exit' here as this only should inform the user, not panic them.
    info "Cancelled by user, exiting!"
    exit 1
}

config_backup() {
    # Create bastille configuration backup with system time appended.
    # This should be called each time 'bastille setup' attempts to
    # write to bastille configuration file.
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    cp "${bastille_config}" "${bastille_config}.${BACKUP_DATE}"
    BACKUP_NAME="${bastille_config}.${BACKUP_DATE}"
    info "Config backup created in: [${BACKUP_NAME}]"
}

config_network_reset() {
    # Restore bastille default network options.
    warn "Performing Network configuration reset, requested by the user..."
    # shellcheck disable=SC3045
    read -p "Do you really want to reset 'bastille' network configuration? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            config_backup
            local VAR_ITEMS="bastille_network_loopback=bastille0 bastille_network_pf_ext_if=ext_if
            bastille_network_pf_table=jails bastille_network_shared= bastille_network_gateway= bastille_network_gateway6="
            for _item in ${VAR_ITEMS}; do
                sysrc -f "${bastille_config}" ${_item}
            done
            info "Network configuration has been reset successfully!"
            exit 0
            ;;
        [Nn]|[Nn][Oo])
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac
}

config_storage_reset() {
    # Restore bastille default ZFS storage options.
    warn "Performing ZFS configuration reset, requested by the user..."
    # shellcheck disable=SC3045
    read -p "Do you really want to reset 'bastille' ZFS configuration? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            config_backup
            local VAR_ITEMS="bastille_zfs_enable= bastille_zfs_zpool= bastille_zfs_prefix=bastille"
            for _item in ${VAR_ITEMS}; do
                sysrc -f "${bastille_config}" ${_item}
            done

            # Let's configure variables with complex values individually to keep it simple/readable for everyone.
            sysrc -f "${bastille_config}" bastille_zfs_options="-o compress=lz4 -o atime=off"
            sysrc -f "${bastille_config}" bastille_prefix="${bastille_prefix_default}"
            info "ZFS configuration has been reset successfully!"
            exit 0 
            ;;
        [Nn]|[Nn][Oo])
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac
}

config_restore_global() {
    local _response
    # This will restore bastille default configuration file from the sample config file.
    # Be aware that if the sample configuration file is missing, we can generate a new one,
    # but that's highly unlikely to happen so will keep the code smaller here.
    warn "Performing Bastille default configuration restore, requested by the user..."
    # shellcheck disable=SC3045
    read -p "Do you really want to restore 'bastille' default configuration file and start over? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            config_backup
            if [ -f "${bastille_config}.sample" ]; then
                mv "${bastille_config}" "${bastille_config}.${BACKUP_DATE}"
                cp "${bastille_config}.sample" "${bastille_config}"
            else
                error_exit "Bastille sample configuration file is missing, exiting."
            fi
            info "Bastille configuration file restored successfully!"
            exit 0
            ;;
        [Nn]|[Nn][Oo])
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac
}

configure_auto() {
    # This is similar to the previous setup cmd behavior, included for convenience.
    warn "This will attempt to auto-configure network, firewall and ZFS storage on new install with sane defaults."
    # shellcheck disable=SC3045
    read -p "Do you really want to auto-configure 'bastille' with standard default configuration parameters? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            info "Attempting Bastille auto-configuration in progress..."
            config_backup
            bastille_auto_config="1"
            configure_network
            configure_pf
            configure_zfs
            ;;
        [Nn]|[Nn][Oo])
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac
}

get_zfs_params() {
    info "Reading on-disk and bastille ZFS config parameters..."
    # Always try to detect and recover on-disk ZFS bastille configuration first.
    # Bastille ZFS prefix is always set to "bastille" in the config file by default,
    # so will keep things simple here, or considered custom setup if this variable is changed.
    BASTILLE_ROOTFS=$(mount | awk '/ \/ / {print $1}')
    BASTILLE_UFSBOOT=
    BASTILLE_ZFSPOOL=
    BASTILLE_PREFIXDEF=
    BASTILLE_ZFSENABLE=
    BASTILLE_PREFIX_MATCH=

    # Check if the system boots from ZFS.
    if echo "${BASTILLE_ROOTFS}" | grep -q -m 1 -E "^/dev/"; then
        # Assume the host is running from UFS.
        info "This system doesn't boot from ZFS, looking for alternate configuration."
        BASTILLE_UFSBOOT="1"
    fi

    BASTILLE_PREFIXCONF=$(sysrc -qn -f "${bastille_config}" bastille_prefix)
    BASTILLE_PREFIXZFS=$(sysrc -qn -f "${bastille_config}" bastille_zfs_prefix)

    if [ -z "${BASTILLE_PREFIXZFS}" ]; then
        BASTILLE_PREFIXZFS="${bastille_zfsprefix_default}"
    fi

    if [ -z "${BASTILLE_UFSBOOT}" ]; then
        if [ "${BASTILLE_PREFIXZFS}" != "${bastille_zfsprefix_default}" ]; then
            BASTILLE_CUSTOM_CONFIG="1"
        fi
    fi

    # Try to determine "zroot" pool name as it may happens that the user
    # customized the "zroot" pool name during the initial FreeBSD installation.
    if [ -z "${BASTILLE_UFSBOOT}" ]; then
        #BASTILLE_ZFSPOOL=$(df ${bastille_config_path} 2>/dev/null | sed 1d | awk -F '/' '{print $1}')
        BASTILLE_ZFSPOOL=$(zfs list -H ${bastille_config_path} 2>/dev/null | awk -F '/' '{print $1}')
    fi

    if [ -z "${BASTILLE_UFSBOOT}"  ]; then
        BASTILLE_PREFIXDEF=$(zfs list -H "${BASTILLE_ZFSPOOL}/${BASTILLE_PREFIXZFS}" 2>/dev/null | awk '{print $5}')
    fi

    if [ -n "${BASTILLE_UFSBOOT}" ]; then
        # Make sure bastille_prefix is listed by ZFS then try to get bastille_zfs_pool from it.
        # Make some additional checks for non ZFS boot systems, also rely on some 'bastille.conf' ZFS parameters.
        BASTILLE_PREFIXLOOK=$(zfs list -H "${BASTILLE_PREFIXCONF}" 2>/dev/null | awk '{print $1}')
        BASTILLE_ZFSPOOL=$(zfs list -H "${BASTILLE_PREFIXLOOK}" 2>/dev/null | awk -F '/' '{print $1}')
        BASTILLE_PREFIXDEF=$(zfs list -H "${BASTILLE_PREFIXCONF}" 2>/dev/null | awk '{print $5}')

    else
         # Fallback to default config.
        if [ -z "${BASTILLE_PREFIXDEF}" ]; then
            BASTILLE_PREFIXDEF="${bastille_prefix_default}"
        fi
    fi

    if [ "${BASTILLE_PREFIXDEF}" = "${BASTILLE_PREFIXCONF}" ]; then
        BASTILLE_PREFIX_MATCH="1"
    fi

    # Update 'bastille_prefix' if a custom dataset is detected while reading on-disk configuration.
    if [ ! -d "${bastille_prefix}" ] || [ -n "${ZFS_DATASET_DETECT}" ] || [ -n "${BASTILLE_PREFIXDEF}" ]; then
        BASTILLE_ZFSENABLE="YES"
        bastille_prefix="${BASTILLE_PREFIXDEF}"
    else
        BASTILLE_ZFSENABLE="NO"
        if [ -z "${BASTILLE_UFSBOOT}" ]; then
            BASTILLE_PREFIXZFS=""
        fi
    fi
}

config_validation(){
    # Perform a basic bastille ZFS configuration check,
    if [ -d "${bastille_prefix}" ] && [ -n "${BASTILLE_PREFIX_MATCH}" ] && echo "${bastille_zfs_enable}" | grep -qi "yes" \
        && zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}" >/dev/null 2>&1; then
            info "Looks like Bastille ZFS storage features has been activated successfully!."
            exit 0
    else
        if [ ! -d "${bastille_prefix}" ] && [ -z "${BASTILLE_ZFSPOOL}" ]; then
            zfs_initial_activation
        else
            if ! echo "${bastille_zfs_enable}" | grep -qi "no"; then
            
            # Inform the user bastille ZFS configuration has been tampered and/or on-disk ZFS config has changed.
            error_exit "Bastille ZFS misconfiguration detected, please refer to 'bastille.conf' or see 'bastille setup --config-reset'."
            fi
        fi
    fi
}

show_zfs_params() {
    # Show a brief info of the detected and/or pending bastille ZFS configuration parameters.
    # Don't need to show bastille zfs enable as this will be enabled by default.
    info "*************************************"
    info "Bastille Storage Prefix: [${BASTILLE_PREFIXDEF}]"
    info "Bastille ZFS Pool: [${BASTILLE_ZFSPOOL}]"
    info "Bastille ZFS Prefix: [${BASTILLE_PREFIXZFS}]"
    info "*************************************"
}

write_zfs_opts() {
    # Write/update to bastille config file the required and/or misssing parameters.
    if [ -z "${bastille_prefix}" ] || [ "${BASTILLE_PREFIXDEF}" != "${bastille_prefix_default}" ]; then
        if [ -z "${BASTILLE_PREFIX_MATCH}" ]; then
            sysrc -f "${bastille_config}" bastille_prefix="${BASTILLE_PREFIXDEF}"
        fi
    else
        if [ -z "${BASTILLE_PREFIXCONF}" ] && [ -n "${BASTILLE_PREFIXDEF}" ]; then
            sysrc -f "${bastille_config}" bastille_prefix="${BASTILLE_PREFIXDEF}"
        fi
    fi

    if [ -z "${bastille_zfs_enable}" ]; then
        sysrc -f "${bastille_config}" bastille_zfs_enable="${BASTILLE_ZFSENABLE}"
    fi
    if [ -z "${bastille_zfs_zpool}" ]; then
        sysrc -f "${bastille_config}" bastille_zfs_zpool="${BASTILLE_ZFSPOOL}"
    fi
    if [ -z "${bastille_zfs_prefix}" ] || [ "${BASTILLE_PREFIXDEF}" != "${bastille_zfs_prefix}" ]; then
        sysrc -f "${bastille_config}" bastille_zfs_prefix="${BASTILLE_PREFIXZFS}"
    fi
    info "ZFS has been enabled in bastille configuration successfully!"
}

create_zfs_dataset(){
    info "Creating ZFS dataset [${BASTILLE_ZFSPOOL}/${BASTILLE_PREFIXZFS}] for bastille..."

    if [ -n "${BASTILLE_CONFIG_USER}" ]; then
        bastille_prefix="${BASTILLE_PREFIXDEF}"
    fi

    # shellcheck disable=SC1073
    if zfs list "${BASTILLE_ZFSPOOL}/${BASTILLE_PREFIXZFS}" >/dev/null 2>&1; then
        info "Dataset ${BASTILLE_ZFSPOOL}/${BASTILLE_PREFIXZFS} already exist, skipping."
    else
        if ! zfs create -p ${bastille_zfs_options} -o mountpoint="${bastille_prefix}" "${BASTILLE_ZFSPOOL}/${BASTILLE_PREFIXZFS}"; then
            error_exit "Failed to create 'bastille_prefix' dataset, exiting."
        fi
    fi
    chmod 0750 "${bastille_prefix}"
    info "Bastille ZFS storage features has been activated successfully!"
    # Enable ZFS in bastille_config only if dataset created successfully during auto-config.
    if [ "${bastille_auto_config}" -eq "1" ]; then
        sysrc -f "${bastille_config}" bastille_zfs_enable="YES"
    fi
    exit 0
}

write_zfs_disable() {
    # Explicitly disable ZFS in 'bastille_zfs_enable'
    sysrc -f "${bastille_config}" bastille_zfs_enable="NO"
    info "ZFS has been disabled in bastille configuration successfully!"
}

write_zfs_enable() {
    # Explicitly enable ZFS in 'bastille_zfs_enable'
    # Just empty the 'bastille_zfs_enable' variable so the user can re-run the ZFS activation helper.
    # Don't put "YES" here as it will trigger the ZFS validation and failing due missing and/or invalid configuration.
    sysrc -f "${bastille_config}" bastille_zfs_enable=""
    info "ZFS activation helper enabled!"
}

zfs_initial_activation() {
    local _response=

    # Just let the user interactively select the ZFS items manually from a list for the initial activation.
    # This should be performed before `bastille bootstrap` as we already know.
    info "Initial bastille ZFS activation helper invoked."
    # shellcheck disable=SC3045
    read -p "Would you like to configure the bastille ZFS options interactively? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            # Assume the user knows what hes/she doing and want to configure ZFS parameters interactively.
            configure_zfs_manually
            ;;
        [Nn]|[Nn][Oo])
            # Assume the user will manually edit the ZFS parameters in the config file.
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac
}

configure_ethernet() {
    # This will attempt to configure the physical ethernet interface for 'bastille_network_shared',
    # commonly used with shared IP jails and/or simple jail network configurations.

    local ETHIF_COUNT="0"
    local _ethernet_choice=
    local _ethernet_select=
    local _response=

    # Try to get a list of the available physical network/ethernet interfaces.
    local ETHERNET_PHY_ADAPTERS="$(pciconf -lv | grep 'ethernet' -B4 | grep 'class=0x020000' | awk -F '@' '{print $1}')"
    if [ -z "${ETHERNET_PHY_ADAPTERS}" ]; then
        error_exit "Unable to detect for any physical ethernet interfaces, exiting."
    fi

    warn "This will attempt to configure the physical ethernet interface for [bastille_network_shared]."
    # shellcheck disable=SC3045
    read -p "Would you like to configure the physical ethernet interface now? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            # shellcheck disable=SC2104
            break
            ;;
        [Nn]|[Nn][Oo])
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac

    info "Listing available physical ethernet interfaces..."
    for _ethernetif in ${ETHERNET_PHY_ADAPTERS}; do
        echo "[${ETHIF_COUNT}] ${_ethernetif}"
        ETHIF_NUM="${ETHIF_NUM} [${ETHIF_COUNT}]${_ethernetif}"
        ETHIF_COUNT=$(expr ${ETHIF_COUNT} + 1)
    done

    # shellcheck disable=SC3045
    read -p "Please select the wanted physical ethernet adapter [NUM] to be used as 'bastille_network_shared': " _ethernet_choice
    if ! echo "${_ethernet_choice}" | grep -Eq "^[0-9]{1,3}$"; then
        error_exit "Invalid input number, aborting!"
    else
        _ethernet_select=$(echo "${ETHIF_NUM}" | grep -wo "\[${_ethernet_choice}\][^ ]*" | sed 's/\[.*\]//g')
        # If the user is unsure here, just abort as no input validation will be performed after.
        if [ -z "${_ethernet_select}" ]; then
            error_exit "No physical ethernet interface selected, aborting!"
        else
            info "Selected physical ethernet interface: [${_ethernet_select}]"
            # Ask again to make sure the user is confident with the election.
            # shellcheck disable=SC3045
            read -p "Are you sure '${_ethernet_select}' is the correct physical ethernet interface [Y|n]: " _response
            case "${_response}" in
                [Yy]|[Yy][Ee][Ss])
                    if ! sysrc -f "${bastille_config}" bastille_network_shared | grep -qi "${_ethernet_select}"; then
                        config_backup
                        sysrc -f "${bastille_config}" bastille_network_shared="${_ethernet_select}"
                    fi
                    exit 0
                    ;;
                [Nn]|[Nn][Oo])
                    user_canceled
                    ;;
                *)
                    input_error
                    ;;
            esac
        fi
    fi
}

configure_network() {
    local _response

    # Configure bastille loopback network interface.
    # This is an initial attempt to make this function interactive,
    # however this may be enhanced in the future by advanced contributors in this topic.
    if [ "${bastille_auto_config}" -eq "0" ]; then
        warn "This will attempt to configure the loopback network interface [${bastille_network_loopback}]."
        # shellcheck disable=SC3045
        read -p "Would you like to configure the loopback network interface now? [Y|n]: " _response
        case "${_response}" in
            [Yy]|[Yy][Ee][Ss])
                # shellcheck disable=SC2104
                break
                ;;
            [Nn]|[Nn][Oo])
                user_canceled
                ;;
            *)
                input_error
                ;;
        esac
    fi

    info "Configuring ${bastille_network_loopback} loopback interface..."
    if ! sysrc -qn cloned_interfaces | grep -qi "lo1"; then
        sysrc cloned_interfaces+=lo1
    fi
    if ! sysrc -qn ifconfig_lo1_name | grep -qi "${bastille_network_loopback}"; then
        sysrc ifconfig_lo1_name="${bastille_network_loopback}"
    fi

    info "Bringing up new interface: ${bastille_network_loopback}..."
    service netif cloneup
}

configure_vnet() {
    local _response

    # This is an initial attempt to make this function interactive,
    # however this may be enhanced in the future by advanced contributors in this topic.
    warn "This will attempt to configure the VNET bridge interface [${bastille_ifbridge_name}]."
    # shellcheck disable=SC3045
    read -p "Would you like to configure the VNET bridge interface now? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            # shellcheck disable=SC2104
            break
            ;;
        [Nn]|[Nn][Oo])
            user_canceled
            ;;
        *)
            input_error
            ;;
    esac

    info "Configuring bridge interface [${bastille_ifbridge_name}]..."

    if ! sysrc -qn cloned_interfaces | grep -qi "${bastille_ifbridge_name}"; then
        sysrc cloned_interfaces+="${bastille_ifbridge_name}"
    fi
    if ! sysrc -qn ifconfig_bridge1_name | grep -qi "${bastille_ifbridge_name}"; then
        sysrc ifconfig_bridge1_name="${bastille_ifbridge_name}"
    fi

    info "Bringing up new interface: ${bastille_ifbridge_name}..."
    service netif cloneup

    if [ ! -f "/etc/devfs.rules" ]; then
        info "Creating bastille_vnet devfs.rules..."
        cat << EOF > /etc/devfs.rules
# Auto-generated file from 'bastille setup'
# devfs configuration information

[bastille_vnet=13]
add include \$devfsrules_hide_all
add include \$devfsrules_unhide_basic
add include \$devfsrules_unhide_login
add include \$devfsrules_jail
add include \$devfsrules_jail_vnet
add path 'bpf*' unhide
EOF
    else
        warn "File [/etc/devfs.rules] already exist, skipping."
        exit 1
    fi
    exit 0
}

configure_pf() {
    local _response

    # Configure the PF firewall.
    # This is an initial attempt to make this function interactive,
    # however this may be enhanced in the future by advanced contributors in this topic.
    if [ "${bastille_auto_config}" -eq "0" ]; then
        warn "This will attempt to configure the PF firewall parameters in [${bastille_pf_conf}]."
        # shellcheck disable=SC3045
        read -p "Would you like to configure the PF firewall parameters now? [Y|n]: " _response
        case "${_response}" in
            [Yy]|[Yy][Ee][Ss])
                # shellcheck disable=SC2104
                break
                ;;
            [Nn]|[Nn][Oo])
                user_canceled
                ;;
            *)
                input_error
                ;;
        esac
    fi

    # shellcheck disable=SC2154
    if [ ! -f "${bastille_pf_conf}" ]; then
        # shellcheck disable=SC3043
        local ext_if
        ext_if=$(netstat -rn | awk '/default/ {print $4}' | head -n1)
        info "Determined default network interface: ($ext_if)"
        info "${bastille_pf_conf} does not exist, creating file..."

        # Creating pf.conf file.
        cat << EOF > "${bastille_pf_conf}"
# Auto-generated file from 'bastille setup'
# packet filter configuration file

ext_if="$ext_if"

set block-policy return
scrub in on \$ext_if all fragment reassemble
set skip on lo

table <jails> persist
nat on \$ext_if from <jails> to any -> (\$ext_if:0)
rdr-anchor "rdr/*"

block in all
pass out quick keep state
antispoof for \$ext_if inet
pass in inet proto tcp from any to any port ssh flags S/SA keep state
EOF

    if ! sysrc -qn pf_enable | grep -qi "yes"; then
        sysrc pf_enable="YES"
    fi
    warn "The pf ruleset file has been created, please review '${bastille_pf_conf}' and enable it using 'service pf start'."
    else
        warn "${bastille_pf_conf} already exists, skipping."
        exit 1
    fi
}

configure_zfs() {
    # Attempt to detect and setup either new or an existing bastille ZFS on-disk configuration.
    # This is useful for new users to easily activate the bastille ZFS parameters on a standard installation,
    # or to recover an existing on-disk ZFS bastille configuration in case the config file has been borked/reset by the user,
    # also a config backup will be created each time the config needs to be modified in the following format: bastille.conf.YYYYMMDD-HHMMSS
    # Be aware that the users now need to explicitly enable ZFS in the config file due later config file changes, failing to do so
    # before initial `bastille bootstrap` will private the user from activating ZFS storage features without manual intervention.

    ZFS_DATASET_DETECT=
    BASTILLE_CUSTOM_CONFIG=
    local _response=

    if ! kldstat -qm zfs; then
        warn "Looks like the ZFS module is not loaded."
        warn "If this is not a dedicated ZFS system you can ignore this warning."
        exit 1
    else
        # If the below statement becomes true, will assume that the user do not want ZFS activation at all regardless of the
        # host filesystem, or the default configuration file has been changed officially and set to "NO" by default.
        if echo "${bastille_zfs_enable}" | grep -qi "no" && [ "${bastille_auto_config}" -eq "0" ]; then
            info "Looks like Bastille ZFS has been disabled in 'bastille.conf', ZFS activation helper disabled."
            # shellcheck disable=SC3045
            read -p "Would you like to enable the ZFS activation helper now? [Y|n]: " _response
            case "${_response}" in
                [Yy]|[Yy][Ee][Ss])
                    # Assume the user wants to configure the ZFS parameters.
                    if config_backup; then
                        write_zfs_enable
                        warn "Please run 'bastille setup -z' again or consult bastille.conf for further configuration."
                        exit 0
                    else
                        error_exit "Config backup creation failed, exiting."
                    fi
                    ;;
                [Nn]|[Nn][Oo])
                    # Assume the user will manually configure the ZFS parameters, or skip ZFS configuration.
                    user_canceled
                    ;;
            esac
        else
            # Attempt to detect if bastille was installed with sane defaults(ports/pkg) and hasn't been bootstrapped yet,
            # then offer the user initial ZFS activation option to gain all of the ZFS storage features and benefits.
            # This should be performed before `bastille` initial bootstrap because several ZFS datasets will be
            # created/configured during the bootstrap process by default.
            get_zfs_params
            if [ ! -d "${bastille_prefix}" ] && [ -n "${BASTILLE_ZFSPOOL}" ]; then
                    if [ "${bastille_prefix}" = "${bastille_prefix_default}" ] && [ -z "${BASTILLE_CUSTOM_CONFIG}" ]; then
                        show_zfs_params
                        info "Looks like bastille has been installed and hasn't been bootstrapped yet."
                        if [ "${bastille_auto_config}" -eq "0" ]; then
                            # shellcheck disable=SC3045
                            read -p "Would you like to activate ZFS now to get the features and benefits? [Y|n]: " _response
                            case "${_response}" in
                                [Yy]|[Yy][Ee][Ss])
                                    if [ -n "${BASTILLE_ZFSPOOL}" ]; then
                                        info "Attempting to create a backup file of the current bastille.conf file..."
                                        if config_backup; then
                                            write_zfs_opts
                                            create_zfs_dataset
                                        else
                                            error_exit "Config backup creation failed, exiting."
                                        fi
                                    else
                                        error_exit "Unable to determine the [zroot] pool name, exiting"
                                    fi
                                    ;;
                                [Nn]|[Nn][Oo])
                                    info "Looks like you cancelled the ZFS activation."
                                    # Offer the user option to disable ZFS in the configuration file.
                                    # Maybe the user wants to use UFS or ZFS with legacy directories instead.
                                    # shellcheck disable=SC3045
                                    read -p "Would you like to explicitly disable ZFS in the configuration file? [Y|n]: " _response
                                    case "${_response}" in
                                        [Yy]|[Yy][Ee][Ss])
                                            if config_backup; then
                                                # Assume the user want to skip ZFS configuration regardless.
                                                write_zfs_disable
                                                exit 0
                                            else
                                                 error_exit "Config backup creation failed, exiting."
                                            fi
                                            ;;
                                        [Nn]|[Nn][Oo])
                                            # Assume the user will manually configure the ZFS parameters by itself.
                                            user_canceled
                                            ;;
                                        *)
                                            input_error
                                            ;;
                                    esac
                                    ;;
                                *)
                                    input_error
                                    ;;
                            esac
                        else
                            # Just attempt to configure the ZFS parameters automatically during auto-config.
                            if [ -n "${BASTILLE_ZFSPOOL}" ]; then
                                info "Attempting to create a backup file of the current bastille.conf file..."
                                if config_backup; then
                                    write_zfs_opts
                                    create_zfs_dataset
                                else
                                    error_exit "Config backup creation failed, exiting."
                                fi
                            else
                                error_exit "Unable to determine the [zroot] pool name, exiting"
                            fi
                        fi
                    else
                        config_validation
                    fi
            else
                if [ -d "${bastille_prefix}" ] && [ -z "${bastille_zfs_enable}" ] && [ -z "${bastille_zfs_zpool}" ] && [ -z "${BASTILLE_CUSTOM_CONFIG}" ] && [ -z "${BASTILLE_UFSBOOT}" ]; then
                    show_zfs_params
                    # This section is handy if the user has reset the bastille configuration file after a successful ZFS activation.
                    info "Looks like bastille has been bootstrapped already, but ZFS options are not configured."
                    info "Attempting to configure default ZFS options for you..."
                    if zfs list | grep -qw "${bastille_prefix}"; then
                        ZFS_DATASET_DETECT="1"
                        # shellcheck disable=SC3045
                        read -p "Would you like to auto-configure the detected ZFS parameters now? [Y|n]: " _response
                        case "${_response}" in
                            [Yy]|[Yy][Ee][Ss])
                                if config_backup; then
                                    write_zfs_opts
                                    exit 0
                                else
                                    error_exit "Config backup creation failed, exiting."
                                fi
                                ;;
                            [Nn]|[Nn][Oo])
                                # Assume the user will manually configure the ZFS parameters by itself.
                                user_canceled
                                ;;
                            *)
                                input_error
                                ;;
                        esac
                    else
                        if [ -d "${bastille_prefix}" ]; then
                            if [ ! "$(ls -A ${bastille_prefix})" ]; then
                                if ! zfs list | grep -qw "${bastille_prefix}"; then
                                    # If the user want to use ZFS he/she need to remove/rename the existing 'bastille_prefix' directory manually.
                                    # We do not want to cause existing data lost at all due end-user errors.
                                    warn "Looks like bastille prefix is not a ZFS dataset, thus ZFS storage options are not required."
                                    warn "Please refer to 'bastille.conf' and/or verify for alreay existing 'bastille_prefix' directory."
                                    # shellcheck disable=SC3045
                                    read -p "Would you like to explicitly disable ZFS in the configuration file so we don't ask again? [Y|n]: " _response
                                    case "${_response}" in
                                        [Yy]|[Yy][Ee][Ss])
                                            if config_backup; then
                                                write_zfs_disable
                                                exit 0
                                            else
                                                error_exit "Config backup creation failed, exiting."
                                            fi
                                            ;;
                                        [Nn]|[Nn][Oo])
                                            # Assume the user will manually configure the ZFS parameters by itself.
                                            user_canceled
                                            ;;
                                        *)
                                            input_error
                                        ;;
                                    esac
                                fi
                            else
                                error_exit "Looks like 'bastille_prefix' is not a ZFS dataset and is not empty, aborting."
                            fi
                        fi
                    fi
                fi
                if [ -n "${BASTILLE_CUSTOM_CONFIG}" ]; then
                    # Attempt to detect an existing on-disk bastille ZFS configuration and let the user interactively select the items manually from a list.
                    # This should be performed if the user has borked/reset the config file or in the event the setup detected an unusual/customized bastille install.
                    warn "A custom bastille ZFS configuration has been detected and/or unable to read ZFS configuration properly."
                    warn "Please refer to 'bastille.conf' config file and/or 'bastille setup -help' for additional info."
                    zfs_initial_activation
                else
                    config_validation
                fi
            fi
        fi
    fi
}

configure_zfs_manually() {
    BASTILLE_CONFIG_USER=
    local ZFSPOOL_COUNT="0"
    local ZFSDATA_COUNT="0"
    local MPREFIX_COUNT="0"
    local _zfsprefix_trim=
    local _zfspool_choice=
    local _zfspool_select=
    local _zfsprefix_choice=
    local _zfsprefix_select=
    local _zfsmount_choice=
    local _zfsmount_select=
    local _response=

    # shellcheck disable=SC3045
    read -p "Would you like to configure the ZFS parameters entirely by hand? [Y|n]: " _response
    case "${_response}" in
        [Yy]|[Yy][Ee][Ss])
            # We will assume the user knows what hes/she doing and want to configure ZFS parameters entirely by hand.
            # shellcheck disable=SC3045
            read -p "Please enter the desired ZFS zpool for bastille: " _zfspool_select
            # shellcheck disable=SC3045
            read -p "Please enter the ZFS dataset prefix for bastille: " _zfsprefix_select
            # shellcheck disable=SC3045
            read -p "Please enter the ZFS mountpoint for bastille: " _zfsmount_select

            # Set the parameters and show the user a preview.
            BASTILLE_PREFIXDEF="${_zfsmount_select}"
            BASTILLE_ZFSPOOL="${_zfspool_select}"
            BASTILLE_PREFIXZFS="${_zfsprefix_select}"
            show_zfs_params

            # Ask again to make sure the user is confident with the entered parameters.
            warn "Are you sure the above bastille ZFS configuration is correct?"
            # shellcheck disable=SC3045
            read -p "Once bastille is activated it can't be easily undone, do you really want to activate ZFS now? [Y|n]: " _response
            case "${_response}" in
                [Yy]|[Yy][Ee][Ss])
                    BASTILLE_CONFIG_USER="1"
                    write_zfs_opts
                    create_zfs_dataset
                    ;;
                [Nn]|[Nn][Oo])
                    user_canceled
                    ;;
                *)
                    input_error
                    ;;
            esac
            ;;
        [Nn]|[Nn][Oo])
            # shellcheck disable=SC2104
            break
            ;;
        *)
            input_error
            ;;
    esac

    # Ask here several times as we want the user to be really sure of what they doing,
    # We do not want to cause existing data lost at all due end-user errors.
    info "Listing available ZFS zpools..."
    bastille_zpool=$(zpool list -H | awk '{print $1}')
    for _zpool in ${bastille_zpool}; do
        echo "[${ZFSPOOL_COUNT}] ${_zpool}"
        ZFSPOOL_NUM="${ZFSPOOL_NUM} [${ZFSPOOL_COUNT}]${_zpool}"
        ZFSPOOL_COUNT=$(expr ${ZFSPOOL_COUNT} + 1)
    done

    # shellcheck disable=SC3045
    read -p "Please select the ZFS zpool [NUM] for bastille: " _zfspool_choice
    if ! echo "${_zfspool_choice}" | grep -Eq "^[0-9]{1,3}$"; then
        error_exit "Invalid input number, aborting!"
    else
        _zfspool_select=$(echo "${ZFSPOOL_NUM}" | grep -wo "\[${_zfspool_choice}\][^ ]*" | sed 's/\[.*\]//g')
        # If the user is unsure here, just abort as no input validation will be performed after.
        if [ -z "${_zfspool_select}" ]; then
            error_exit "No ZFS zpool selected, aborting!"
        else
            info "Selected ZFS zpool: [${_zfspool_select}]"
            # Ask again to make sure the user is confident with the election.
            # shellcheck disable=SC3045
            read -p "Are you sure '${_zfspool_select}' is the correct ZFS zpool [Y|n]: " _response
            case "${_response}" in
                [Yy]|[Yy][Ee][Ss])
                    # shellcheck disable=SC2104
                    continue
                    ;;
                [Nn]|[Nn][Oo])
                    user_canceled
                    ;;
                *)
                    input_error
                    ;;
            esac
        fi
    fi

    # Ask on what zfs dataset `bastille` is installed.
    info "Listing available ZFS datasets from the selected ZFS zpool..."
    bastille_zprefix=$(zfs list -H -r "${_zfspool_select}" | awk '{print $1}')
    for _zprefix in ${bastille_zprefix}; do
        echo "[${ZFSDATA_COUNT}] ${_zprefix}"
        ZFSDATA_NUM="${ZFSDATA_NUM} [${ZFSDATA_COUNT}]${_zprefix}"
        ZFSDATA_COUNT=$(expr ${ZFSDATA_COUNT} + 1)
    done
    # shellcheck disable=SC3045
    read -p "Please select the ZFS dataset prefix [NUM] for bastille: " _zfsprefix_choice
    if ! echo "${_zfsprefix_choice}" | grep -Eq "^[0-9]{1,3}$"; then
        error_exit "Invalid input number, aborting!"
    else
        _zfsprefix_select=$(echo "${ZFSDATA_NUM}" | grep -wo "\[${_zfsprefix_choice}\][^ ]*" | sed 's/\[.*\]//g')
        if [ -z "${_zfsprefix_select}" ]; then
            # If the user is unsure here, just abort as no input validation will be performed after.
            error_exit "No ZFS dataset selected, aborting!"
        else
            _zfsprefix_select=$(echo ${ZFSDATA_NUM} | grep -wo "\[${_zfsprefix_choice}\][^ ]*" | sed 's/\[.*\]//g')
            _zfsprefix_trim=$(echo ${ZFSDATA_NUM} | grep -wo "\[${_zfsprefix_choice}\][^ ]*" | awk -F "${_zfspool_select}/" 'NR==1{print $2}')
            info "Selected ZFS prefix: [${_zfsprefix_select}]"
            # Ask again to make sure the user is confident with the election.
            # shellcheck disable=SC3045
            read -p "Are you sure '${_zfsprefix_select}' is the correct ZFS dataset [Y|n]: " _response
            case "${_response}" in
                [Yy]|[Yy][Ee][Ss])
                    # shellcheck disable=SC2104
                    continue
                    ;;
                [Nn]|[Nn][Oo])
                    user_canceled
                    ;;
                *)
                    input_error
                    ;;
            esac
        fi
    fi

    _zfsmount_select="${_zfsprefix_select}"
    # Ask what zfs mountpoint `bastille` will use.
    info "Listing ZFS mountpoints from the selected ZFS dataset: [${_zfsmount_select}]..."
    bastille_prefix=$(zfs list -H "${_zfsmount_select}" | awk '{print $5}')
    for _zfsmount_choice in ${bastille_prefix}; do
        echo "[${MPREFIX_COUNT}] ${_zfsmount_choice}"
        MPREFIX_NUM="${MPREFIX_NUM} [${MPREFIX_COUNT}]${_zfsmount_choice}"
        MPREFIX_COUNT=$(expr ${MPREFIX_COUNT} + 1)
    done
    # shellcheck disable=SC3045
    read -p "Please select the ZFS mountpoint [NUM] for bastille: " _zfsmount_choice 
    if ! echo "${_zfsmount_choice}" | grep -Eq "^[0-9]{1,3}$"; then
        error_exit "Invalid input number, aborting!"
    else
        _zfsmount_select=$(echo ${MPREFIX_NUM} | grep -wo "\[${_zfsmount_choice}\][^ ]*" | sed 's/\[.*\]//g')
        if [ -z "${_zfsmount_select}" ]; then
            # If the user is unsure here, just abort as no input validation will be performed after.
            error_exit "No ZFS mountpoint selected, aborting!"
        else
            info "Selected bastille storage mountpoint: [${_zfsmount_select}]"
            # Ask again to make sure the user is confident with the election.
            # shellcheck disable=SC3045
            read -p "Are you sure '${_zfsmount_select}' is the correct bastille storage prefix [Y|n]: " _response
            case "${_response}" in
                [Yy]|[Yy][Ee][Ss])
                    # Set the parameters and show the user a preview.
                    BASTILLE_PREFIXDEF="${_zfsmount_select}"
                    BASTILLE_ZFSPOOL="${_zfspool_select}"
                    BASTILLE_PREFIXZFS="${_zfsprefix_trim}"
                    show_zfs_params
                    warn "Are you sure the above bastille ZFS configuration is correct?"
                    # shellcheck disable=SC3045
                    read -p "Once bastille is activated it can't be easily undone once bootstrapped, do you really want to activate ZFS now? [Y|n]: " _response
                    case "${_response}" in
                        [Yy]|[Yy][Ee][Ss])
                            write_zfs_opts
                            create_zfs_dataset
                            ;;
                        [Nn]|[Nn][Oo])
                            user_canceled
                            ;;
                        *)
                            input_error
                            ;;
                    esac
                    ;;
                [Nn]|[Nn][Oo])
                    user_canceled
                    ;;
                *)
                    input_error
                    ;;
            esac
        fi
    fi
}

# Runtime required variables.
config_runtime

# Handle options one at a time per topic, we don't want users to select/process
# multiple options at once just to end with a broked and/or unwanted configuration.
# Include previous setup option names for users accustomed to it, note that they
# may be re-assigned and/or deprecated in future.
case "${1}" in
    --firewall|-p|pf|firewall)
        configure_pf
        ;;
    --ethernet|-e|lan)
        configure_ethernet
        ;;
    --loopback|-l|bastille0)
        configure_network
        ;;
    --vnet|-v|bridge|bastille1)
        configure_vnet
        ;;
    --zfs|-z|storage)
        configure_zfs
        ;;
    --auto|-a|auto)
        configure_auto
        ;;
    --zfs-custom-setup)
        configure_zfs_manually
        ;;
    --conf-network-reset)
        config_network_reset
        ;;
    --conf-storage-reset)
        config_storage_reset
        ;;
    --conf-restore-clean)
        config_restore_global
        ;;
    *)
        usage
        ;;
esac
