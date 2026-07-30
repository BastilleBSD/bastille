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

# Legacy jail.conf/rc.conf syntax migration helpers.

update_jail_syntax_v1() {
    local jail="${1}"
    local jail_config="${bastille_jailsdir}/${jail}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jail}/root/etc/rc.conf"
    # Only apply if old syntax is found
    if grep -Eoq "exec.prestart.*ifconfig epair[0-9]+ create.*" "${jail_config}"; then
        warn 1 "\n[WARNING]\n"
        warn 1 "Updating jail.conf file..."
        warn 1 "Please review your jail.conf file after completion."
        warn 1 "VNET jails created without -M will be assigned a new MAC address."
        if [ "$(echo -n "e0a_${jail}" | awk '{print length}')" -lt 16 ]; then
            local new_host_epair=e0a_${jail}
            local new_jail_epair=e0b_${jail}
        else
            get_bastille_epair_count
            local epair_num=1
            while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${epair_num}"; do
                epair_num=$((epair_num + 1))
            done
            local new_host_epair="e0a_bastille${epair_num}"
            local new_jail_epair="e0b_bastille${epair_num}"
        fi
        # Delete unneeded lines
        sed -i '' "/.*exec.prestart.*ifconfig.*up name.*;/d" "${jail_config}"
        sed -i '' "/.*exec.poststop.*ifconfig.*deletem.*;/d" "${jail_config}"
        # Change jail.conf
        sed -i '' "s|.*vnet.interface =.*|  vnet.interface = ${new_jail_epair};|g" "${jail_config}"
        sed -i '' "s|.*ifconfig epair.*create.*|  exec.prestart += \"epair0=\\\\\$(ifconfig epair create) \&\& ifconfig \\\\\${epair0} up name ${new_host_epair} \&\& ifconfig \\\\\${epair0%a}b up name ${new_jail_epair}\";|g" "${jail_config}"
        sed -i '' "s|addm.*|addm ${new_host_epair}\";|g" "${jail_config}"
        sed -i '' "/ether.*:.*:.*:.*:.*:.*a/ s|ifconfig.*ether|ifconfig ${new_host_epair} ether|g" "${jail_config}"
        sed -i '' "/ether.*:.*:.*:.*:.*:.*b/ s|ifconfig.*ether|ifconfig ${new_jail_epair} ether|g" "${jail_config}"
        sed -i '' "s|ifconfig.*description|ifconfig ${new_host_epair} description|g" "${jail_config}"
        sed -i '' "s|ifconfig.*destroy|ifconfig ${new_host_epair} destroy|g" "${jail_config}"
        # Change rc.conf
        sed -i '' "/ifconfig_.*_name.*vnet.*/ s|ifconfig_.*_name|ifconfig_${new_jail_epair}_name|g" "${jail_rc_config}"
    elif grep -Eoq "exec.poststop.*jib destroy.*" "${jail_config}"; then
        warn 1 "\n[WARNING]\n"
        warn 1 "Updating jail.conf file..."
        warn 1 "Please review your jail.conf file after completion."
        warn 1 "VNET jails created without -M will be assigned a new MAC address."
        local external_interface="$(grep -Eo "jib addm.*" "${jail_config}" | awk '{print $4}')"
        if [ "$(echo -n "e0a_${jail}" | awk '{print length}')" -lt 16 ]; then
            local new_host_epair=e0a_${jail}
            local new_jail_epair=e0b_${jail}
            local jib_epair="${jail}"
        else
            get_bastille_epair_count
            local epair_num=1
            while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${epair_num}"; do
                epair_num=$((epair_num + 1))
            done
            local new_host_epair="e0a_bastille${epair_num}"
            local new_jail_epair="e0b_bastille${epair_num}"
            local jib_epair="bastille${epair_num}"
        fi
        # Change jail.conf
        sed -i '' "s|.*vnet.interface =.*|  vnet.interface = ${new_jail_epair};|g" "${jail_config}"
        sed -i '' "s|jib addm.*|jib addm ${jib_epair} ${external_interface}|g" "${jail_config}"
        sed -i '' "/ether.*:.*:.*:.*:.*:.*a/ s|ifconfig.*ether|ifconfig ${new_host_epair} ether|g" "${jail_config}"
        sed -i '' "/ether.*:.*:.*:.*:.*:.*b/ s|ifconfig.*ether|ifconfig ${new_jail_epair} ether|g" "${jail_config}"
        sed -i '' "s|ifconfig.*description|ifconfig ${new_host_epair} description|g" "${jail_config}"
        sed -i '' "s|jib destroy.*|ifconfig ${new_host_epair} destroy\";|g" "${jail_config}"
        # Change rc.conf
        sed -i '' "/ifconfig_.*_name.*vnet.*/ s|ifconfig_.*_name|ifconfig_${new_jail_epair}_name|g" "${jail_rc_config}"
    fi
}
