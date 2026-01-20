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

# Load config. This only has to be done here
# because all commands load this file
# shellcheck disable=SC1090
. ${BASTILLE_CONFIG}

COLOR_RED=
COLOR_GREEN=
COLOR_YELLOW=
COLOR_RESET=

bastille_root_check() {
    if [ "$(id -u)" -ne 0 ]; then
        ## permission denied
        error_notify "Bastille: Permission Denied"
        error_exit "root / sudo / doas required"
    fi
}

enable_color() {
    . /usr/local/share/bastille/colors.pre.sh
}

enable_debug() {
    # Enable debug mode.
    warn "***DEBUG MODE***"
    set -x
}

# If "NO_COLOR" environment variable is present, or we aren't speaking to a
# tty, disable output colors.
if [ -z "${NO_COLOR}" ] && [ -t 1 ]; then
    enable_color
fi

# Error messages/functions
error_notify() {
    echo -e "${COLOR_RED}$*${COLOR_RESET}" 1>&2
}

error_continue() {
    error_notify "$@"
    # shellcheck disable=SC2104
    continue
}

error_exit() {
    error_notify "$@"
    echo
    exit 1
}

info() {
    if [ "${1}" -eq 2 ]; then
        shift 1
        echo -e "$*" 1>&2
    else
        echo -e "${COLOR_GREEN}$*${COLOR_RESET}" 1>&2
    fi
}

warn() {
    echo -e "${COLOR_YELLOW}$*${COLOR_RESET}" 1>&2
}

check_target_exists() {

    local target="${1}"
    local jail_list="$(bastille list jails)"

    if ! echo "${jail_list}" | grep -Eq "^${target}$"; then
        return 1
    else
        return 0
    fi
}

check_target_is_running() {

    local target="${1}"

    if ! jls name | grep -Eq "^${target}$"; then
        return 1
    else
        return 0
    fi
}

check_target_is_stopped() {

    local target="${1}"

    if jls name | grep -Eq "^${target}$"; then
        return 1
    else
        return 0
    fi
}

get_bastille_epair_count() {

    for config in /usr/local/etc/bastille/*.conf; do
        local bastille_jailsdir="$(sysrc -f "${config}" -n bastille_jailsdir)"
        BASTILLE_EPAIR_LIST="$(printf '%s\n%s' "$( (grep -Ehos "bastille[0-9]+" ${bastille_jailsdir}/*/jail.conf; ifconfig -g epair | grep -Eos "e[0-9]+a_bastille[0-9]+$" | grep -Eos 'bastille[0-9]+') | sort -u)" "${BASTILLE_EPAIR_LIST}")"
    done
    BASTILLE_EPAIR_COUNT=$(printf '%s' "${BASTILLE_EPAIR_LIST}" | sort -u | wc -l | awk '{print $1}')
    export BASTILLE_EPAIR_LIST
    export BASTILLE_EPAIR_COUNT
}

get_jail_name() {

    local jid="${1}"
    local jail_name="$(jls -j ${jid} name 2>/dev/null)"

    if [ -z "${jail_name}" ]; then
        return 1
    else
        echo "${jail_name}"
    fi
}

jail_autocomplete() {

    local target="${1}"
    local jail_list="$(bastille list jails)"
    local auto_target="$(echo "${jail_list}" | grep -E "^${target}")"

    if [ -n "${auto_target}" ]; then
        if [ "$(echo "${auto_target}" | wc -l)" -eq 1 ]; then
            echo "${auto_target}"
        else
            error_continue "Multiple jails found for ${target}:\n${auto_target}"
            return 1
        fi
    else
        return 2
    fi
}

list_jail_priority() {

    local jail_list="${1}"

    if [ -d "${bastille_jailsdir}" ]; then
        for jail in ${jail_list}; do
            # Remove boot.conf in favor of settings.conf
            if [ -f ${bastille_jailsdir}/${jail}/boot.conf ]; then
                rm -f ${bastille_jailsdir}/${jail}/boot.conf >/dev/null 2>&1
            fi
            local settings_file=${bastille_jailsdir}/${jail}/settings.conf
            # Set defaults if settings file does not exist
            if [ ! -f ${settings_file} ]; then
                sysrc -f ${settings_file} boot=on >/dev/null 2>&1
                sysrc -f ${settings_file} depend="" >/dev/null 2>&1
                sysrc -f ${settings_file} priority=99 >/dev/null 2>&1
            fi
            # Add defaults if they dont exist
            if ! grep -oq "boot=" ${settings_file}; then
                sysrc -f ${settings_file} boot=on >/dev/null 2>&1
            fi
            if ! grep -oq "depend=" ${settings_file}; then
                sysrc -f ${settings_file} depend="" >/dev/null 2>&1
            fi
            if ! grep -oq "priority=" ${settings_file}; then
                sysrc -f ${settings_file} priority=99 >/dev/null 2>&1
            fi
            priority="$(sysrc -f ${settings_file} -n priority)"
            echo "${jail} ${priority}"
        done
    fi
}

set_target() {

    local target=${1}
    if [ "${2}" = "reverse" ]; then
        local order="${2}"
    else
        local order="forward"
    fi
    JAILS=""
    TARGET=""

    if [ "${target}" = ALL ] || [ "${target}" = all ]; then
        target_all_jails
    else
        for jail in ${target}; do
            if [ ! -d "${bastille_jailsdir}/${target}" ] && echo "${jail}" | grep -Eq '^[0-9]+$'; then
                if get_jail_name "${jail}" > /dev/null; then
                    jail="$(get_jail_name ${jail})"
                else
                    error_continue "Error: JID \"${jail}\" not found. Is jail running?"
                fi
            elif ! check_target_exists "${jail}"; then
                if jail_autocomplete "${jail}" > /dev/null; then
                    jail="$(jail_autocomplete ${jail})"
                elif [ $? -eq 2 ]; then
                    if grep -Ehoqw ${jail} ${bastille_jailsdir}/*/tags 2>/dev/null; then
                        jail="$(grep -Eow ${jail} ${bastille_jailsdir}/*/tags | awk -F"/tags" '{print $1}' | sed "s#${bastille_jailsdir}/##g" | tr '\n' ' ')"
                    else
                        error_continue "Jail not found \"${jail}\""
                    fi
                else
                    echo
                    exit 1
                fi
            fi
            TARGET="${TARGET} ${jail}"
            JAILS="${JAILS} ${jail}"
        done
        # Exit if no jails
        if [ -z "${TARGET}" ] && [ -z "${JAILS}" ]; then
            exit 1
        fi
        if [ "${order}" = "forward" ]; then
            TARGET="$(list_jail_priority "${TARGET}" | sort -k2 -n | awk '{print $1}')"
            JAILS="$(list_jail_priority "${TARGET}" | sort -k2 -n | awk '{print $1}')"
        elif [ "${order}" = "reverse" ]; then
            TARGET="$(list_jail_priority "${TARGET}" | sort -k2 -nr | awk '{print $1}')"
            JAILS="$(list_jail_priority "${TARGET}" | sort -k2 -nr | awk '{print $1}')"
        fi
        export TARGET
        export JAILS
    fi
}

set_target_single() {

    local target="${1}"
    JAILS=""
    TARGET=""

    if [ "${target}" = ALL ] || [ "${target}" = all ]; then
        error_exit "[all|ALL] not supported with this command."
    elif [ "$(echo ${target} | wc -w)" -gt 1 ]; then
        error_exit "Error: Command only supports a single TARGET."
    elif [ ! -d "${bastille_jailsdir}/${target}" ] && echo "${target}" | grep -Eq '^[0-9]+$'; then
        if get_jail_name "${target}" > /dev/null; then
            target="$(get_jail_name ${target})"
        else
            error_exit "Error: JID \"${target}\" not found. Is jail running?"
        fi
    elif ! check_target_exists "${target}"; then
            if jail_autocomplete "${target}" > /dev/null; then
                target="$(jail_autocomplete ${target})"
            elif [ $? -eq 2 ]; then
                error_exit "Jail not found \"${target}\""
            else
                echo
                exit 1
            fi
    fi
    TARGET="${target}"
    JAILS="${target}"
    # Exit if no jails
    if [ -z "${target}" ] && [ -z "${jails}" ]; then
        exit 1
    fi
    export TARGET
    export JAILS
}

# This function is run immediately
set_bastille_mountpoints() {

    if checkyesno bastille_zfs_enable; then

        # We have to do this if ALTROOT is enabled/present
        local altroot="$(zpool get -Ho value altroot ${bastille_zfs_zpool})"

        # Set mountpoints to *bastille*dir*
        # shellcheck disable=SC2034
        bastille_prefix_mountpoint="${bastille_prefix}"
        # shellcheck disable=SC2034
        bastille_backupsdir_mountpoint="${bastille_backupsdir}"
        # shellcheck disable=SC2034
        bastille_cachedir_mountpoint="${bastille_cachedir}"
        # shellcheck disable=SC2034
        bastille_jailsdir_mountpoint="${bastille_jailsdir}"
        # shellcheck disable=SC2034
        bastille_releasesdir_mountpoint="${bastille_releasesdir}"
        # shellcheck disable=SC2034
        bastille_templatesdir_mountpoint="${bastille_templatesdir}"
        # shellcheck disable=SC2034
        bastille_logsdir_mountpoint="${bastille_logsdir}"

        # Add _altroot to *dir* if set
        if [ "${altroot}" != "-" ]; then
            # Set *dir* to include ALTROOT
            bastille_prefix="${altroot}${bastille_prefix}"
            bastille_backupsdir="${altroot}${bastille_backupsdir}"
            bastille_cachedir="${altroot}${bastille_cachedir}"
            bastille_jailsdir="${altroot}${bastille_jailsdir}"
            bastille_releasesdir="${altroot}${bastille_releasesdir}"
            bastille_templatesdir="${altroot}${bastille_templatesdir}"
            bastille_logsdir="${altroot}${bastille_logsdir}"
        fi
    fi
}

target_all_jails() {

    local jails="$(bastille list jails)"
    JAILS=""

    for jail in ${jails}; do
        if [ -d "${bastille_jailsdir}/${jail}" ]; then
            JAILS="${JAILS} ${jail}"
        fi
    done
    # Exit if no jails
    if [ -z "${JAILS}" ]; then
        exit 1
    fi
    if [ "${order}" = "forward" ]; then
        JAILS="$(list_jail_priority "${JAILS}" | sort -k2 -n | awk '{print $1}')"
    elif [ "${order}" = "reverse" ]; then
        JAILS="$(list_jail_priority "${JAILS}" | sort -k2 -nr | awk '{print $1}')"
    fi
    export JAILS
}

update_fstab() {

    local oldname="${1}"
    local newname="${2}"
    local fstab="${bastille_jailsdir}/${newname}/fstab"

    if [ -f "${fstab}" ]; then
        sed -i '' "s|${bastille_jailsdir}/${oldname}/root/|${bastille_jailsdir}/${newname}/root/|" "${fstab}"
    else
        error_notify "Error: Failed to update fstab: ${newmane}"
    fi
}

generate_static_mac() {

    local jail_name="${1}"
    local external_interface="${2}"
    local external_interface_mac="$(ifconfig ${external_interface} | grep ether | awk '{print $2}')"
    # Use FreeBSD vendor MAC prefix (58:9c:fc) for jail MAC prefix
    local macaddr_prefix="58:9c:fc"
    # Use hash of interface+jailname for jail MAC suffix
    local macaddr_suffix="$(echo -n "${external_interface_mac}${external_interface}${jail_name}" | sed 's#:##g' | sha256 | cut -b -5 | sed 's/\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F][0-9a-fA-F]\)\([0-9a-fA-F]\)/\1:\2:\3/')"

    if [ -z "${macaddr_prefix}" ] || [ -z "${macaddr_suffix}" ]; then
        error_notify "Failed to generate MAC address."
    fi
    macaddr="${macaddr_prefix}:${macaddr_suffix}"
    export macaddr
}

generate_vnet_jail_netblock() {

    local jail_name="${1}"
    # interface_type can be "standard" "bridge" or "passthrough"
    local interface_type="${2}"
    local external_interface="${3}"
    local static_mac="${4}"

    # Set epair/interface values for host/jail
    if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
        if [ "${interface_type}" = "bridge" ]; then
            if [ "$(echo -n "e0a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                local host_epair=e0a_${jail_name}
                local jail_epair=e0b_${jail_name}
            else
                get_bastille_epair_count
                local epair_num=1
                while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${epair_num}"; do
                    epair_num=$((epair_num + 1))
                done
                local host_epair="e0a_bastille${epair_num}"
                local jail_epair="e0b_bastille${epair_num}"
            fi
        elif [ "${interface_type}" = "standard" ]; then
            if [ "$(echo -n "e0a_${jail_name}" | awk '{print length}')" -lt 16 ]; then
                local host_epair=e0a_${jail_name}
                local jail_epair=e0b_${jail_name}
                local jib_epair=${jail_name}
            else
                get_bastille_epair_count
                local epair_num=1
                while echo "${BASTILLE_EPAIR_LIST}" | grep -oq "bastille${epair_num}"; do
                    epair_num=$((epair_num + 1))
                done
                local host_epair="e0a_bastille${epair_num}"
                local jail_epair="e0b_bastille${epair_num}"
                local jib_epair="bastille${epair_num}"
            fi
        elif [ "${interface_type}" = "passthrough" ]; then
            host_epair="${external_interface}"
            jail_epair="${external_interface}"
        fi
    elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
        local ng_if=ng0_${jail_name}
        local jng_if=${jail_name}
    fi

    # VNET_JAIL_BRIDGE
    if [ "${interface_type}" = "bridge" ]; then
        if [ "${static_mac}" -eq 1 ]; then
            # Generate BRIDGE config with static MAC address
            generate_static_mac "${jail_name}" "${external_interface}"
            cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "epair0=\\\$(ifconfig epair create) && ifconfig \\\${epair0} up name ${host_epair} && ifconfig \\\${epair0%a}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${external_interface} addm ${host_epair}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
        else
            # Generate BRIDGE config without static MAC address
            cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "epair0=\\\$(ifconfig epair create) && ifconfig \\\${epair0} up name ${host_epair} && ifconfig \\\${epair0%a}b up name ${jail_epair}";
  exec.prestart += "ifconfig ${external_interface} addm ${host_epair}";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
        fi

    # VNET_JAIL_STANDARD
    elif [ "${interface_type}" = "standard" ]; then
        if [ "${bastille_network_vnet_type}" = "if_bridge" ]; then
            if [ "${static_mac}" -eq 1 ]; then
                # Generate VNET config with static MAC address
                generate_static_mac "${jail_name}" "${external_interface}"
                cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "jib addm ${jib_epair} ${external_interface}";
  exec.prestart += "ifconfig ${host_epair} ether ${macaddr}a";
  exec.prestart += "ifconfig ${jail_epair} ether ${macaddr}b";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
            else
                # Generate VNET config without static MAC address
                cat <<-EOF
  vnet;
  vnet.interface = ${jail_epair};
  exec.prestart += "jib addm ${jib_epair} ${external_interface}";
  exec.prestart += "ifconfig ${host_epair} description \"vnet0 host interface for Bastille jail ${jail_name}\"";
  exec.poststop += "ifconfig ${host_epair} destroy";
EOF
            fi
        elif [ "${bastille_network_vnet_type}" = "netgraph" ]; then
            if [ "${static_mac}" -eq 1 ]; then
                # Generate VNET config with static MAC address
                generate_static_mac "${jail_name}" "${external_interface}"
                cat <<-EOF
  vnet;
  vnet.interface = ${ng_if};
  exec.prestart += "jng bridge ${jng_if} ${external_interface}";
  exec.prestart += "ifconfig ${ng_if} ether ${macaddr}b";
  exec.poststop += "jng shutdown ${jng_if}";
EOF
            else
                # Generate VNET config without static MAC address
                cat <<-EOF
  vnet;
  vnet.interface = ${ng_if};
  exec.prestart += "jng bridge ${jng_if} ${external_interface}";
  exec.poststop += "jng shutdown ${jng_if}";
EOF
            fi
        fi

    # VNET_JAIL_PASSTHROUGH
    elif [ "${interface_type}" = "passthrough" ]; then
        cat <<-EOF
  vnet;
  vnet.interface = ${external_interface};
  exec.prestop += "ifconfig ${external_interface} -vnet ${jail_name}";
EOF
    fi
}

validate_ip() {

    local ip="${1}"
    local vnet_jail="${2}"
    local ip4="$(echo ${ip} | awk -F"/" '{print $1}')"
    local ip6="$(echo ${ip} | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)')"
    local subnet="$(echo ${ip} | awk -F"/" '{print $2}')"
    local IFS

    if [ -n "${ip6}" ]; then
        if [ "${vnet_jail}" -eq 1 ]; then
            if [ -z "${subnet}" ]; then
                subnet="64"
            elif ! echo "${subnet}" | grep -Eq '^[0-9]+$'; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            elif [ "${subnet}" -lt 1 ] || [ "${subnet}" -gt 128 ]; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            fi
            ip6="${ip6}/${subnet}"
        fi
        info "\nValid IP: ${ip6}"
        export IP6_ADDR="${ip6}"
    elif [ "${ip}" = "inherit" ] || [ "${ip}" = "ip_hostname" ]; then
            info "\nValid IP: ${ip}"
            export IP4_ADDR="${ip}"
            export IP6_ADDR="${ip}"
    elif [ "${ip}" = "0.0.0.0" ] || [ "${ip}" = "DHCP" ] || [ "${ip}" = "SYNCDHCP" ]; then
            info "\nValid IP: ${ip}"
            export IP4_ADDR="${ip}"
    elif [ -n "${ip4}" ]; then
        if [ "${vnet_jail}" -eq 1 ]; then
            if [ -z "${subnet}" ]; then
                subnet="24"
            elif ! echo "${subnet}" | grep -Eq '^[0-9]+$'; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            elif [ "${subnet}" -lt 1 ] || [ "${subnet}" -gt 32 ]; then
                error_exit "[ERROR]: Invalid subnet: /${subnet}"
            fi
            ip4="${ip4}/${subnet}"
        fi
        if echo "${ip4}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            test_ip=$(echo "${ip4}" | cut -d / -f1)
            IFS=.
            set ${test_ip}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    error_exit "[ERROR]: Invalid IP: ${ip4}"
                fi
            done

            info "\nValid IP: ${ip4}"
            export IP4_ADDR="${ip4}"
        else
            error_exit "[ERROR]: Invalid IP: ${ip4}"
        fi
    else
        error_exit "[ERROR]: IP incorrectly formatted: ${ip}"
    fi
}

validate_netconf() {

    # Add default 'bastille_network_vnet_type' on old config file
    # This is so we don't have to indtroduce a 'breaking change' statement
    if ! grep -oq "bastille_network_vnet_type=" "${BASTILLE_CONFIG}"; then
        sed -i '' "s|## Networking|&\nbastille_network_vnet_type=\"if_bridge\"                                ## default: \"if_bridge\"|" ${BASTILLE_CONFIG}
        # shellcheck disable=SC1090
        . ${BASTILLE_CONFIG}
    fi

    # Validate that 'bastille_network_vnet_type' has been set
    if [ -n "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
        error_exit "[ERROR]: 'bastille_network_loopback' and 'bastille_network_shared' cannot both be set."
    fi
    if [ "${bastille_network_vnet_type}" != "if_bridge" ] && [ "${bastille_network_vnet_type}" != "netgraph" ]; then
        error_exit "[ERROR]: 'bastille_network_vnet_type' not set properly: ${bastille_network_vnet_type}"
    fi
}

checkyesno() {
    ## copied from /etc/rc.subr -- cedwards (20231125)
    ## issue #368 (lowercase values should be parsed)
    ## now used for all bastille_zfs_enable=YES|NO tests
    ## example: if checkyesno bastille_zfs_enable; then ...
    ## returns 0 for enabled; returns 1 for disabled
    eval value=\$${1}
    case $value in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
        return 0
        ;;
    [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
        return 1
        ;;
    *)
        warn "\$${1} is not set properly - see rc.conf(5)."
        return 1
        ;;
    esac
}

update_jail_syntax_v1() {

    local jail="${1}"
    local jail_config="${bastille_jailsdir}/${jail}/jail.conf"
    local jail_rc_config="${bastille_jailsdir}/${jail}/root/etc/rc.conf"

    # Only apply if old syntax is found
    if grep -Eoq "exec.prestart.*ifconfig epair[0-9]+ create.*" "${jail_config}"; then

        warn "\n[WARNING]\n"
        warn "Updating jail.conf file..."
        warn "Please review your jail.conf file after completion."
        warn "VNET jails created without -M will be assigned a new MAC address."

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

        warn "\n[WARNING]\n"
        warn "Updating jail.conf file..."
        warn "Please review your jail.conf file after completion."
        warn "VNET jails created without -M will be assigned a new MAC address."

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

set_bastille_mountpoints
