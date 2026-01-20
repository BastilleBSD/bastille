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

usage() {
    error_notify "Usage: bastille setup [option(s)] [bridge|linux|loopback|netgraph|firewall|shared|storage|vnet]"
    cat << EOF

    Options:

    -y | --yes       Do not prompt. Assume always yes.
    -x | --debug     Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO_YES=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -y|--yes)
            AUTO_YES=1
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${opt} in
                    y) AUTO_YES=1 ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\"" ;;
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Check for too many args
if [ "$#" -gt 2 ]; then
    usage
fi

OPT_CONFIG="${1}"
OPT_ARG="${2}"

bastille_root_check

configure_linux() {

    if ! kldstat -qn linux || \
       ! kldstat -qn linux64 || \
       ! kldstat -qm fdescfs || \
       ! kldstat -qm linprocfs || \
       ! kldstat -qm linsysfs || \
       ! kldstat -qm tmpfs; then

        local required_mods="fdescfs linprocfs linsysfs tmpfs"
        local linuxarc_mods="linux linux64"

        # Enable required modules
        for mod in ${required_mods}; do
            if ! kldstat -qm ${mod}; then
                if [ ! "$(sysrc -f /boot/loader.conf -qn ${mod}_load)" = "YES" ] && [ ! "$(sysrc -f /boot/loader.conf.local -qn ${mod}_load)" = "YES" ]; then
                    info 1 "\nLoading kernel module: ${mod}"
                    kldload ${mod}
                    info 1 "\nPersisting module: ${mod}"
                    sysrc -f /boot/loader.conf ${mod}_load=YES
                else
                    info 1 "\nLoading kernel module: ${mod}"
                    kldload ${mod}
                fi
            fi
        done

        # Mandatory Linux modules/rc.
        for mod in ${linuxarc_mods}; do
            if ! kldstat -qn ${mod}; then
                info 1 "\nLoading kernel module: ${mod}"
                kldload ${mod}
            fi
        done

        # Enable linux
        if [ ! "$(sysrc -qn linux_enable)" = "YES" ] && [ ! "$(sysrc -f /etc/rc.conf.local -qn linux_enable)" = "YES" ]; then
            sysrc linux_enable=YES
        fi

        # Install debootstrap package
        if ! which -s debootstrap; then
            pkg install -y debootstrap
        fi

        info 1 "\nLinux has been successfully configured!"

    else
        info 1 "\nLinux has already been configured!"
    fi
}

# Configure netgraph
configure_netgraph() {

    if ! kldstat -qm netgraph || \
       ! kldstat -qm ng_netflow || \
       ! kldstat -qm ng_ksocket || \
       ! kldstat -qm ng_ether || \
       ! kldstat -qm ng_bridge || \
       ! kldstat -qm ng_eiface || \
       ! kldstat -qm ng_socket; then

        # Ensure jib script is in place for VNET jails
        if [ ! "$(command -v jng)" ]; then
            if [ -f "/usr/share/examples/jails/jng" ] && [ ! -f "/usr/local/bin/jng" ]; then
                install -m 0544 /usr/share/examples/jails/jng /usr/local/bin/jng
            fi
        fi

        local required_mods="netgraph ng_netflow ng_ksocket ng_ether ng_bridge ng_eiface ng_socket"
        
        info 1 "\nConfiguring netgraph modules..."

        # Load requried netgraph kernel modules
        for mod in ${required_mods}; do
            if ! kldstat -qm ${mod}; then
                info 1 "\nLoading kernel module: ${mod}"
                kldload -v ${mod}
                info 1 "\nPersisting module: ${mod}"
                sysrc -f /boot/loader.conf ${mod}_load=YES
            fi
        done

        # Set bastille_network_vnet_type to netgraph
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_vnet_type="netgraph"

        info 1 "\nNetgraph has been successfully configured!"
    else
        info 1 "\nNetgraph has already been configured!"
    fi
}

# Configure bastille loopback network interface
configure_loopback_interface() {
    if [ -z "$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_loopback)" ] || ! sysrc -n cloned_interfaces | grep -oq "lo1"; then
        info 1 "\nConfiguring bastille0 loopback interface"
        sysrc cloned_interfaces+=lo1
        sysrc ifconfig_lo1_name="bastille0"
        info 1 "\nBringing up new interface: [bastille0]"
        service netif cloneup
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_loopback="bastille0"
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_shared=""
        info 1 "\nLoopback interface successfully configured: [bastille0]"
    else
        info 1 "\nLoopback interface has already been configured: [bastille0]"
    fi
}

configure_shared_interface() {

    auto_if="${1}"
    interface_list="$(ifconfig -l)"
    interface_count=0

    if [ -z "${interface_list}" ]; then
        error_exit "Unable to detect interfaces, exiting."
    fi
    if [ -z "$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_shared)" ]; then
        info 1 "\nAttempting to configure shared interface for bastille..."
        info 1 "\nListing available interfaces..."
        if [ -z "${auto_if}" ]; then
            for if in ${interface_list}; do
                info 2 "[${interface_count}] ${if}"
                if_num="${if_num} [${interface_count}]${if}"
                interface_count=$(expr ${interface_count} + 1)
            done
            # shellcheck disable=SC3045
            read -p "Please select the interface you would like to use: " interface_choice
            if ! echo "${interface_choice}" | grep -Eq "^[0-9]+$"; then
                error_exit "Invalid input number, aborting!"
            else
                interface_select=$(echo "${if_num}" | grep -wo "\[${interface_choice}\][^ ]*" | sed 's/\[.*\]//g')
            fi
        else
            interface_select="${auto_if}"
        fi

        # Adjust bastille.conf to reflect above choices
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_loopback=""
        sysrc cloned_interfaces-="lo1"
        ifconfig bastille0 destroy 2>/dev/null
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_shared="${interface_select}"
        info 1 "\nShared interface successfully configured: [${interface_select}]"
    else
        info 1 "\nShared interface has already been configured: [$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_shared)]"
    fi

}

configure_bridge() {

    auto_if="${1}"
    interface_list="$(ifconfig -l)"
    interface_count=0

    if [ -z "${interface_list}" ]; then
        error_exit "Unable to detect interfaces, exiting."
    fi
    if ! ifconfig -g bridge | grep -oqw "${bridge_name}"; then
        info 1 "\nConfiguring ${bridge_name} bridge interface..."

        if [ -z "${auto_if}" ]; then
            info 1 "\nListing available interfaces..."
            for if in ${interface_list}; do
                if ifconfig -g bridge | grep -oqw "${if}" || ifconfig -g lo | grep -oqw "${if}"; then
                    continue
                else
                    info 2 "[${interface_count}] ${if}"
                    if_num="${if_num} [${interface_count}]${if}"
                    interface_count=$(expr ${interface_count} + 1)
                fi
            done
            # shellcheck disable=SC3045
            read -p "Please select the interface to attach the bridge to: " interface_choice
            if ! echo "${interface_choice}" | grep -Eq "^[0-9]+$"; then
                error_exit "Invalid input number, aborting!"
            else
                interface_select=$(echo "${if_num}" | grep -wo "\[${interface_choice}\][^ ]*" | sed 's/\[.*\]//g')
            fi
        else
            interface_select="${auto_if}"
        fi

        # Create bridge and persist on reboot
        bridge_name="${interface_select}bridge"
        ifconfig bridge0 create
        ifconfig bridge0 name ${bridge_name}
        ifconfig ${bridge_name} addm ${interface_select} up
        sysrc cloned_interfaces+="bridge0"
        sysrc ifconfig_bridge0_name="${bridge_name}"
        sysrc ifconfig_${bridge_name}="addm ${interface_select} up"

        # Set some sysctl values
        sysctl net.inet.ip.forwarding=1
        sysctl net.link.bridge.pfil_bridge=0
        sysctl net.link.bridge.pfil_onlyip=0
        sysctl net.link.bridge.pfil_member=0
        echo net.inet.ip.forwarding=1 >> /etc/sysctl.conf
        echo net.link.bridge.pfil_bridge=0 >> /etc/sysctl.conf
        echo net.link.bridge.pfil_onlyip=0 >> /etc/sysctl.conf
        echo net.link.bridge.pfil_member=0 >> /etc/sysctl.conf


        info 1 "\nBridge interface successfully configured: [${bridge_name}]"
    else
        info 1 "\nBridge has alread been configured: [${bridge_name}]"
    fi
}

configure_vnet() {

    # Ensure proper jail helper script
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        if [ ! "$(command -v jib)" ]; then
            if [ -f "/usr/share/examples/jails/jib" ] && [ ! -f "/usr/local/bin/jib" ]; then
                install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib
            fi
        fi
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        if [ ! "$(command -v jng)" ]; then
            if [ -f "/usr/share/examples/jails/jng" ] && [ ! -f "/usr/local/bin/jng" ]; then
                install -m 0544 /usr/share/examples/jails/jng /usr/local/bin/jng
            fi
        fi
    fi

    # Create default VNET ruleset
    if [ ! -f "/etc/devfs.rules" ] || ! grep -oq "bastille_vnet=13" /etc/devfs.rules; then
        info 1 "\nCreating bastille_vnet devfs.rules"
        cat << EOF > /etc/devfs.rules
[bastille_vnet=13]
add include \$devfsrules_hide_all
add include \$devfsrules_unhide_basic
add include \$devfsrules_unhide_login
add include \$devfsrules_jail
add include \$devfsrules_jail_vnet
add path 'bpf*' unhide
EOF
    else
        info 1 "\nVNET has already been configured!"
    fi
}

# Configure pf firewall
configure_pf() {
# shellcheck disable=SC2154
if [ ! -f "${bastille_pf_conf}" ]; then
    # shellcheck disable=SC3043
    local ext_if
    ext_if=$(netstat -rn | awk '/default/ {print $4}' | head -n1)
    info 1 "\nDetermined default network interface: ($ext_if)"
    info 2 "${bastille_pf_conf} does not exist: creating..."

    ## creating pf.conf
    cat << EOF > "${bastille_pf_conf}"
## generated by bastille setup
ext_if="$ext_if"

set block-policy return
scrub in on \$ext_if all fragment reassemble
set skip on lo

table <jails> persist
nat on \$ext_if from <jails> to any -> (\$ext_if:0)
rdr-anchor "rdr/*"

block in all
pass out quick keep state
antispoof for \$ext_if
pass in proto tcp from any to any port ssh flags S/SA keep state
EOF
    sysrc pf_enable=YES
    warn "pf ruleset created, please review ${bastille_pf_conf} and enable it using 'service pf start'."
else
    info 1 "\nFirewall (pf) has already been configured!"
fi
}

# Configure storage
configure_storage() {

    if mount | grep "zfs" >/dev/null 2>/dev/null; then

        auto_zpool="${1}"

        if [ ! "$(kldstat -m zfs)" ]; then
            info 1 "\nZFS module not loaded; skipping..."
        elif sysrc -f ${BASTILLE_CONFIG} -n bastille_zfs_enable | grep -Eoq "([Y|y][E|e][S|s])"; then
            info 1 "\nZFS has already been configured!"
        else
            if [ -z "${auto_zpool}" ]; then
                zpool_list=$(zpool list | grep -v NAME | awk '{print $1}')
                zpool_count=0
                if [ "$(zpool list | grep -v NAME | awk '{print $1}' | wc -l)" -eq 1 ]; then
                    bastille_zpool="${zpool_list}"
                else
                    info 1 "\nMultiple zpools detected:"
                    for zpool in ${zpool_list}; do
                        echo "[${zpool_count}] ${zpool}"
                        zpool_num="${zpool_num} [${zpool_count}]${zpool}"
                        zpool_count=$(expr ${zpool_count} + 1)
                    done
                    # shellcheck disable=SC3045
                    read -p "Please select the zpool for Bastille to use: " zpool_choice
                    if ! echo "${zpool_choice}" | grep -Eq "^[0-9]+$"; then
                        error_exit "Invalid input number, aborting!"
                    else
                        bastille_zpool=$(echo "${zpool_num}" | grep -wo "\[${zpool_choice}\][^ ]*" | sed 's/\[.*\]//g')
                    fi
                fi
            else
                bastille_zpool="${auto_zpool}"
            fi
            sysrc -f "${BASTILLE_CONFIG}" bastille_zfs_enable=YES
            sysrc -f "${BASTILLE_CONFIG}" bastille_zfs_zpool="${bastille_zpool}"
            info 1 "\nUsing ZFS filesystem."
        fi
    elif mount | grep "ufs" >/dev/null 2>/dev/null; then
        info 1 "\nUsing UFS filesystem."
    fi
}

# Run all base functions (w/o vnet) if no args
if [ $# -eq 0 ]; then
    sysrc bastille_enable=YES
    configure_storage
    configure_loopback_interface
    configure_pf
    info 1 "\nBastille has successfully been configured.\n"
    exit 0
fi

case "${OPT_CONFIG}" in
    pf|firewall)
        configure_pf
        ;;
    linux)
        if [ "${AUTO_YES}" -eq 1 ]; then
            configure_linux
        else
            warn "[WARNING]: Running linux jails requires loading additional kernel"
            warn "modules, as well as installing the 'debootstrap' package."
            # shellcheck disable=SC3045
            read -p "Do you want to proceed with setup? [y|n]:" answer
            case "${answer}" in
                [Yy]|[Yy][Ee][Ss])
                    configure_linux
                    ;;
                [Nn]|[Nn][Oo])
                    error_exit "Linux setup cancelled."
                    ;;
                *)
                    error_exit "Invalid selection. Please answer 'y' or 'n'"
                    ;;
            esac
        fi
        ;;
    netgraph)
        if [ "${AUTO_YES}" -eq 1 ]; then
            configure_vnet
            configure_netgraph
        else
            warn "[WARNING]: Bastille only allows using either 'if_bridge' or 'netgraph'"
            warn "as VNET network options. You CANNOT use both on the same system. If you have"
            warn "already started using bastille with 'if_bridge' do not continue."
            # shellcheck disable=SC3045
            read -p "Do you really want to continue setting up netgraph for Bastille? [y|n]:" answer
            case "${answer}" in
                [Yy]|[Yy][Ee][Ss])
                    configure_vnet
                    configure_netgraph
                    ;;
                [Nn]|[Nn][Oo])
                    error_exit "Netgraph setup cancelled."
                    ;;
                *)
                    error_exit "Invalid selection. Please answer 'y' or 'n'"
                    ;;
            esac
        fi
        ;;
    loopback)
        if [ "${AUTO_YES}" -eq 1 ]; then
            configure_loopback_interface
        else
            warn "[WARNING]: Bastille only allows using either the 'loopback' or 'shared'"
            warn "interface to be configured ant one time. If you continue, the 'shared'"
            warn "interface will be disabled, and the 'loopback' interface will be used as default."
            # shellcheck disable=SC3045
            read -p "Do you really want to continue setting up the loopback interface? [y|n]:" answer
            case "${answer}" in
                [Yy]|[Yy][Ee][Ss])
                    configure_loopback_interface
                    ;;
                [Nn]|[Nn][Oo])
                    error_exit "Loopback interface setup cancelled."
                    ;;
                *)
                    error_exit "Invalid selection. Please answer 'y' or 'n'"
                    ;;
            esac
        fi
        ;;
    shared)
        if [ "${AUTO_YES}" -eq 1 ]; then
            error_exit "[ERROR]: 'shared' does not support [-y|--yes]."
        else
            warn "[WARNING]: Bastille only allows using either the 'loopback' or 'shared'"
            warn "interface to be configured at one time. If you continue, the 'loopback'"
            warn "interface will be disabled, and the shared interface will be used as default."
            # shellcheck disable=SC3045
            read -p "Do you really want to continue setting up the shared interface? [y|n]:" answer
            case "${answer}" in
                [Yy]|[Yy][Ee][Ss])
                    configure_shared_interface "${OPT_ARG}"
                    ;;
                [Nn]|[Nn][Oo])
                    error_exit "Shared interface setup cancelled."
                    ;;
                *)
                    error_exit "Invalid selection. Please answer 'y' or 'n'"
                    ;;
            esac
        fi
        ;;
    storage)
        configure_storage "${OPT_ARG}"
        ;;
    vnet)
        configure_vnet
        ;;
    bridge)
        if [ "${AUTO_YES}" -eq 1 ]; then
            error_exit "[ERROR]: 'bridge' does not support [-y|--yes]."
        else
            configure_vnet
            configure_bridge "${OPT_ARG}"
        fi
        ;;
    *)
        error_exit "[ERROR]: Unknown option: \"${1}\""
        ;;
esac
