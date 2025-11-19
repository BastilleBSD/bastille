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
    error_notify "Usage: bastille setup [option(s)] [bridge]"
    error_notify "                                  [loopback]"
    error_notify "                                  [pf|firewall]"
    error_notify "                                  [shared]"
    error_notify "                                  [vnet]"
    error_notify "                                  [storage]"
    cat << EOF

    Options:

    -y | --yes             Assume always yes on prompts.
    -x | --debug           Enable debug mode.

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
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
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

# Configure netgraph
configure_netgraph() {
    if [ ! "$(kldstat -m netgraph)" ]; then
        # Ensure jib script is in place for VNET jails
        if [ ! "$(command -v jng)" ]; then
            if [ -f /usr/share/examples/jails/jng ] && [ ! -f /usr/local/bin/jng ]; then
                install -m 0544 /usr/share/examples/jails/jng /usr/local/bin/jng
            fi
        fi
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_vnet_type="netgraph"
        info "\nConfiguring netgraph modules..."
        kldload netgraph
        kldload ng_netflow
        kldload ng_ksocket
        kldload ng_ether
        kldload ng_bridge
        kldload ng_eiface
        kldload ng_socket
        sysrc -f /boot/loader.conf netgraph_load="YES"
        sysrc -f /boot/loader.conf ng_netflow_load="YES"
        sysrc -f /boot/loader.conf ng_ksocket_load="YES"
        sysrc -f /boot/loader.conf ng_ether_load="YES"
        sysrc -f /boot/loader.conf ng_bridge_load="YES"
        sysrc -f /boot/loader.conf ng_eiface_load="YES"
        sysrc -f /boot/loader.conf ng_socket_load="YES"
        info "\nNetgraph has been successfully configured!"
    else
        info "\nNetgraph has already been configured!"
    fi
}

# Configure bastille loopback network interface
configure_loopback_interface() {
    if [ -z "$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_loopback)" ] || ! sysrc -n cloned_interfaces | grep -oq "lo1"; then
        info "\nConfiguring bastille0 loopback interface"
        sysrc cloned_interfaces+=lo1
        sysrc ifconfig_lo1_name="bastille0"
        info "\nBringing up new interface: [bastille0]"
        service netif cloneup
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_loopback="bastille0"
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_shared=""
        info "\nLoopback interface successfully configured: [bastille0]"
    else
        info "\nLoopback interface has already been configured: [bastille0]"
    fi
}

configure_shared_interface() {

    _auto_if="${1}"
    _interface_list="$(ifconfig -l)"
    _interface_count=0

    if [ -z "${_interface_list}" ]; then
        error_exit "Unable to detect interfaces, exiting."
    fi
    if [ -z "$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_shared)" ]; then
        info "\nAttempting to configure shared interface for bastille..."
        info "\nListing available interfaces..."
        if [ -z "${_auto_if}" ]; then
            for _if in ${_interface_list}; do
                echo "[${_interface_count}] ${_if}"
                _if_num="${_if_num} [${_interface_count}]${_if}"
                _interface_count=$(expr ${_interface_count} + 1)
            done
            # shellcheck disable=SC3045
            read -p "Please select the interface you would like to use: " _interface_choice
            if ! echo "${_interface_choice}" | grep -Eq "^[0-9]+$"; then
                error_exit "Invalid input number, aborting!"
            else
                _interface_select=$(echo "${_if_num}" | grep -wo "\[${_interface_choice}\][^ ]*" | sed 's/\[.*\]//g')
            fi
        else
            _interface_select="${_auto_if}"
        fi

        # Adjust bastille.conf to reflect above choices
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_loopback=""
        sysrc cloned_interfaces-="lo1"
        ifconfig bastille0 destroy 2>/dev/null
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_shared="${_interface_select}"
        info "\nShared interface successfully configured: [${_interface_select}]"
    else
        info "\nShared interface has already been configured: [$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_shared)]"
    fi

}

configure_bridge() {

    _auto_if="${1}"
    _interface_list="$(ifconfig -l)"
    _interface_count=0

    if [ -z "${_interface_list}" ]; then
        error_exit "Unable to detect interfaces, exiting."
    fi
    if ! ifconfig -g bridge | grep -oqw "${_bridge_name}"; then
        info "\nConfiguring ${_bridge_name} bridge interface..."

        if [ -z "${_auto_if}" ]; then
            info "\nListing available interfaces..."
            for _if in ${_interface_list}; do
                if ifconfig -g bridge | grep -oqw "${_if}" || ifconfig -g lo | grep -oqw "${_if}"; then
                    continue
                else
                    echo "[${_interface_count}] ${_if}"
                    _if_num="${_if_num} [${_interface_count}]${_if}"
                    _interface_count=$(expr ${_interface_count} + 1)
                fi
            done
            # shellcheck disable=SC3045
            read -p "Please select the interface to attach the bridge to: " _interface_choice
            if ! echo "${_interface_choice}" | grep -Eq "^[0-9]+$"; then
                error_exit "Invalid input number, aborting!"
            else
                _interface_select=$(echo "${_if_num}" | grep -wo "\[${_interface_choice}\][^ ]*" | sed 's/\[.*\]//g')
            fi
        else
            _interface_select="${_auto_if}"
        fi

        # Create bridge and persist on reboot
        _bridge_name="${_interface_select}bridge"
        ifconfig bridge0 create
        ifconfig bridge0 name ${_bridge_name}
        ifconfig ${_bridge_name} addm ${_interface_select} up
        sysrc cloned_interfaces+="bridge0"
        sysrc ifconfig_bridge0_name="${_bridge_name}"
        sysrc ifconfig_${_bridge_name}="addm ${_interface_select} up"

        # Set some sysctl values
        sysctl net.inet.ip.forwarding=1
        sysctl net.link.bridge.pfil_bridge=0
        sysctl net.link.bridge.pfil_onlyip=0
        sysctl net.link.bridge.pfil_member=0
        echo net.inet.ip.forwarding=1 >> /etc/sysctl.conf
        echo net.link.bridge.pfil_bridge=0 >> /etc/sysctl.conf
        echo net.link.bridge.pfil_onlyip=0 >> /etc/sysctl.conf
        echo net.link.bridge.pfil_member=0 >> /etc/sysctl.conf


        info "\nBridge interface successfully configured: [${_bridge_name}]"
    else
        info "\nBridge has alread been configured: [${_bridge_name}]"
    fi
}

configure_vnet() {

    # Ensure proper jail helper script
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        if [ ! "$(command -v jib)" ]; then
            if [ -f /usr/share/examples/jails/jib ] && [ ! -f /usr/local/bin/jib ]; then
                install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib
            fi
        fi
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        if [ ! "$(command -v jng)" ]; then
            if [ -f /usr/share/examples/jails/jng ] && [ ! -f /usr/local/bin/jng ]; then
                install -m 0544 /usr/share/examples/jails/jng /usr/local/bin/jng
            fi
        fi
    fi

    # Create default VNET ruleset
    if [ ! -f /etc/devfs.rules ] || ! grep -oq "bastille_vnet=13" /etc/devfs.rules; then
        info "\nCreating bastille_vnet devfs.rules"
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
        info "\nVNET has already been configured!"
    fi
}

# Configure pf firewall
configure_pf() {
# shellcheck disable=SC2154
if [ ! -f "${bastille_pf_conf}" ]; then
    # shellcheck disable=SC3043
    local ext_if
    ext_if=$(netstat -rn | awk '/default/ {print $4}' | head -n1)
    info "\nDetermined default network interface: ($ext_if)"
    echo "${bastille_pf_conf} does not exist: creating..."

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
antispoof for \$ext_if inet
pass in proto tcp from any to any port ssh flags S/SA keep state
EOF
    sysrc pf_enable=YES
    warn "pf ruleset created, please review ${bastille_pf_conf} and enable it using 'service pf start'."
else
    info "\nFirewall (pf) has already been configured!"
fi
}

# Configure storage
configure_storage() {

    if mount | grep "zfs" >/dev/null 2>/dev/null; then

        _auto_zpool="${1}"

        if [ ! "$(kldstat -m zfs)" ]; then
            info "\nZFS module not loaded; skipping..."
        elif sysrc -f ${BASTILLE_CONFIG} -n bastille_zfs_enable | grep -Eoq "([Y|y][E|e][S|s])"; then
            info "\nZFS has already been configured!"
        else
            if [ -z "${_auto_zpool}" ]; then
                _zpool_list=$(zpool list | grep -v NAME | awk '{print $1}')
                _zpool_count=0
                if [ "$(zpool list | grep -v NAME | awk '{print $1}' | wc -l)" -eq 1 ]; then
                    _bastille_zpool="${_zpool_list}"
                else
                    info "\nMultiple zpools detected:"
                    for _zpool in ${_zpool_list}; do
                        echo "[${_zpool_count}] ${_zpool}"
                        _zpool_num="${_zpool_num} [${_zpool_count}]${_zpool}"
                        _zpool_count=$(expr ${_zpool_count} + 1)
                    done
                    # shellcheck disable=SC3045
                    read -p "Please select the zpool for Bastille to use: " _zpool_choice
                    if ! echo "${_zpool_choice}" | grep -Eq "^[0-9]+$"; then
                        error_exit "Invalid input number, aborting!"
                    else
                        _zpool_select=$(echo "${_zpool_num}" | grep -wo "\[${_zpool_choice}\][^ ]*" | sed 's/\[.*\]//g')
                    fi
                fi
            else
                _bastille_zpool="${_auto_zpool}"
            fi
            sysrc -f "${BASTILLE_CONFIG}" bastille_zfs_enable=YES
            sysrc -f "${BASTILLE_CONFIG}" bastille_zfs_zpool="${_bastille_zpool}"
            info "\nUsing ZFS filesystem."
        fi
    elif mount | grep "ufs" >/dev/null 2>/dev/null; then
        info "\nUsing UFS filesystem."
    fi
}

# Run all base functions (w/o vnet) if no args
if [ $# -eq 0 ]; then
    sysrc bastille_enable=YES
    configure_storage
    configure_loopback_interface
    configure_pf
    info "\nBastille has successfully been configured.\n"
    exit 0
fi

case "${OPT_CONFIG}" in
    pf|firewall)
        configure_pf
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
            read -p "Do you really want to continue setting up netgraph for Bastille? [y|n]:" _answer
            case "${_answer}" in
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
            read -p "Do you really want to continue setting up the loopback interface? [y|n]:" _answer
            case "${_answer}" in
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
            read -p "Do you really want to continue setting up the shared interface? [y|n]:" _answer
            case "${_answer}" in
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
