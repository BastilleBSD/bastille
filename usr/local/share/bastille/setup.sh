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
    error_exit "Usage: bastille setup [-p|pf|firewall] [-l|loopback] [-s|shared] [-z|zfs|storage] [-v|vnet] [-b|bridge]"
}

# Check for too many args
if [ $# -gt 1 ]; then
    usage
fi

# Configure bastille loopback network interface
configure_loopback_interface() {
    if [ -z "$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_loopback)" ] || ! sysrc -n cloned_interfaces | grep -oq "lo1"; then
        info "Configuring bastille0 loopback interface"
        sysrc cloned_interfaces+=lo1
        sysrc ifconfig_lo1_name="bastille0"
        info "Bringing up new interface: [bastille0]"
        service netif cloneup
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_loopback="bastille0"
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_shared=""
        info "Loopback interface successfully configured: [bastille0]"
    else
        info "Loopback interface has already been configured: [bastille0]"
    fi
}

configure_shared_interface() {
    _interface_list="$(ifconfig -l)"
    _interface_count=0
    if [ -z "${_interface_list}" ]; then
        error_exit "Unable to detect interfaces, exiting."
    fi
    if [ -z "$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_shared)" ]; then
        info "Attempting to configure shared interface for bastille..."
        info "Listing available interfaces..."
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
        # Adjust bastille.conf to reflect above choices
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_loopback=""
        sysrc cloned_interfaces-="lo1"
        ifconfig bastille0 destroy 2>/dev/null
        sysrc -f "${BASTILLE_CONFIG}" bastille_network_shared="${_interface_select}"
        info "Shared interface successfully configured: [${_interface_select}]"
    else
        info "Shared interface has already been configured: [$(sysrc -f ${BASTILLE_CONFIG} -n bastille_network_shared)]"
    fi

}

configure_bridge() {
    _bridge_name="bastillebridge"
    _interface_list="$(ifconfig -l)"
    _interface_count=0
    if [ -z "${_interface_list}" ]; then
        error_exit "Unable to detect interfaces, exiting."
    fi
    if ! ifconfig -g bridge | grep -oqw "${_bridge_name}"; then
        info "Configuring ${_bridge_name} bridge interface..."
        info "Listing available interfaces..."
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
        # Create bridge and persist on reboot
        ifconfig bridge0 create
        ifconfig bridge0 name bastillebridge
        ifconfig bastillebridge addm ${_interface_select} up
        sysrc cloned_interfaces+="bridge0"
        sysrc ifconfig_bridge0_name="bastillebridge"
        sysrc ifconfig_bastillebridge="addm ${_interface_select} up"

        info "Bridge interface successfully configured: [${_bridge_name}]"
    else
        info "Bridge has alread been configured: [${_bridge_name}]"
    fi
}

configure_vnet() {
    # Ensure jib script is in place for VNET jails
    if [ ! "$(command -v jib)" ]; then
        if [ -f /usr/share/examples/jails/jib ] && [ ! -f /usr/local/bin/jib ]; then
            install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib
        fi
    fi
    # Create default VNET ruleset
    if [ ! -f /etc/devfs.rules ] || ! grep -oq "bastille_vnet=13" /etc/devfs.rules; then
        info "Creating bastille_vnet devfs.rules"
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
        info "VNET has already been configured!"
    fi
}

# Configure pf firewall
configure_pf() {
# shellcheck disable=SC2154
if [ ! -f "${bastille_pf_conf}" ]; then
    # shellcheck disable=SC3043
    local ext_if
    ext_if=$(netstat -rn | awk '/default/ {print $4}' | head -n1)
    info "Determined default network interface: ($ext_if)"
    info "${bastille_pf_conf} does not exist: creating..."

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
pass in inet proto tcp from any to any port ssh flags S/SA keep state
EOF
    sysrc pf_enable=YES
    warn "pf ruleset created, please review ${bastille_pf_conf} and enable it using 'service pf start'."
else
    info "PF has already been configured!"
fi
}

# Configure ZFS
configure_zfs() {
    if [ ! "$(kldstat -m zfs)" ]; then
        info "ZFS module not loaded; skipping..."
    elif sysrc -f ${BASTILLE_CONFIG} -n bastille_zfs_enable | grep -Eoq "([Y|y][E|e][S|s])"; then
        info "ZFS has already been configured!"
    else
        ## attempt to determine bastille_zroot from `zpool list`
        bastille_zroot=$(zpool list | grep -v NAME | awk '{print $1}')
        if [ "$(echo "${bastille_zroot}" | wc -l)" -gt 1 ]; then
          error_notify "Error: Multiple ZFS pools available:\n${bastille_zroot}"
          error_notify "Set desired pool using \"sysrc -f ${BASTILLE_CONFIG} bastille_zfs_zpool=ZPOOL_NAME\""
          error_exit "Don't forget to also enable ZFS using \"sysrc -f ${BASTILLE_CONFIG} bastille_zfs_enable=YES\""
        fi
        sysrc -f "${BASTILLE_CONFIG}" bastille_zfs_enable=YES
        sysrc -f "${BASTILLE_CONFIG}" bastille_zfs_zpool="${bastille_zroot}"
    fi
}

# Run all base functions (w/o vnet) if no args
if [ $# -eq 0 ]; then
    sysrc bastille_enable=YES
    configure_loopback_interface
    configure_pf
    configure_zfs
fi

# Handle options.
case "$1" in
    -h|--help|help)
        usage
        ;;
    -p|pf|firewall)
        configure_pf
        ;;
    -l|loopback)
        warn "[WARNING] Bastille only allows using either the 'loopback' or 'shared'"
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
        ;;
    -s|shared)
        warn "[WARNING] Bastille only allows using either the 'loopback' or 'shared'"
        warn "interface to be configured at one time. If you continue, the 'loopback'"
        warn "interface will be disabled, and the shared interface will be used as default."
        # shellcheck disable=SC3045
        read -p "Do you really want to continue setting up the shared interface? [y|n]:" _answer
        case "${_answer}" in
            [Yy]|[Yy][Ee][Ss])
                configure_shared_interface
                ;;
            [Nn]|[Nn][Oo])
                error_exit "Shared interface setup cancelled."
                ;;
            *)
                error_exit "Invalid selection. Please answer 'y' or 'n'"
                ;;
        esac
        ;;
    -z|zfs|storage)
        configure_zfs
        ;;
    -v|vnet)
        configure_vnet
        ;;
    -b|bridge)
        configure_vnet
        configure_bridge
        ;;
esac
