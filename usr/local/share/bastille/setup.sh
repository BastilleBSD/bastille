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
    error_exit "Usage: bastille setup [pf|network|zfs|vnet]"
}

# Check for too many args
if [ $# -gt 1 ]; then
    usage
fi

# Configure bastille loopback network interface
configure_network() {
    if ! sysrc -n cloned_interfaces | grep -oq "lo1"; then
        info "Configuring ${bastille_network_loopback} loopback interface"
        sysrc cloned_interfaces+=lo1
        sysrc ifconfig_lo1_name="${bastille_network_loopback}"

        info "Bringing up new interface: ${bastille_network_loopback}"
        service netif cloneup
    else
        info "Network has already been configured!"
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

        info "Bridge created: [${_bridge_name}]"
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
    if [ ! -f /etc/devfs.rules ] || grep -oq "bastille_vnet=13" /etc/devfs.rules; then
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
    configure_network
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
    -n|-l|network|loopback)
        configure_network
        ;;
    -z|zfs|storage)
        configure_zfs
        ;;
    -v|vnet)
        configure_vnet
        ;;
    -b|bridge)
        configure_bridge
        ;;
esac
