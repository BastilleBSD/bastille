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
    # Build an independent usage for the create command
    # If no option specified, will create a thin container by default
    error_notify "Usage: bastille create [option(s)] NAME RELEASE IP [INTERFACE]"
    cat << EOF

    Options:
    
    -B | --bridge                            Enable VNET, and attach to a specified, already existing external bridge.
    -C | --clone                             Create a clone jail.
    -D | --dual                              Create jail with both IPv4 and IPv6 networking ('inherit' and 'ip_hostname' only).
    -E | --empty                             Create an empty container, intended for custom jail builds (thin/thick/linux or unsupported).
    -g | --gateway IP                        Specify a default router/gateway for the jail.
    -L | --linux                             Create a Linux jail (experimental).
    -M | --static-mac                        Generate a static MAC address for jail (VNET only).
         --no-validate                       Do not validate the release when creating the jail.
         --no-boot                           Create jail with boot=off.
    -n | --nameserver                        Specify a nameserver for the jail.
    -p | --priority VALUE                    Set priority value for jail.
    -T | --thick                             Creates a thick container, they consume more space as they are self contained and independent.
    -V | --vnet                              Enable VNET, and attach to an existing, physical interface.
    -v | --vlan VLANID                       Creates the jail with specified VLAN ID (VNET only).
    -x | --debug                             Enable debug mode.
    -Z | --zfs-opts zfs,options              Comma separated list of ZFS options to create the jail with. This overrides the defaults.

EOF
    exit 1
}

validate_name() {

    local NAME_VERIFY=${NAME}
    local NAME_SANITY="$(echo "${NAME_VERIFY}" | tr -c -d 'a-zA-Z0-9-_')"

    if [ -n "$(echo "${NAME_SANITY}" | awk "/^[-_].*$/" )" ]; then
        error_exit "[ERROR]: Jail names may not begin with (-|_) characters!"
    elif [ "${NAME_VERIFY}" != "${NAME_SANITY}" ]; then
        error_exit "[ERROR]: Jail names may not contain special characters!"
    elif echo "${NAME_VERIFY}" | grep -qE '^[0-9]+$'; then
        error_exit "[ERROR]: Jail names may not contain only digits."
    fi
}

validate_ip() {

    _ip="${1}"
    _ip6=$(echo "${_ip}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$)|SLAAC)')

    if [ -n "${_ip6}" ]; then

        info "\nValid: (${_ip6})."

        ipx_addr="ip6.addr"

    else
        if [ "${_ip}" = "inherit" ] || [ "${_ip}" = "ip_hostname" ] || [ "${_ip}" = "DHCP" ] || [ "${_ip}" = "SYNCDHCP" ]; then

            info "\nValid: (${_ip})."

        else
            local IFS
            if echo "${_ip}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
                TEST_IP=$(echo "${_ip}" | cut -d / -f1)
                IFS=.
                set ${TEST_IP}
                for quad in 1 2 3 4; do
                    if eval [ \$$quad -gt 255 ]; then
                        error_continue "Invalid: (${TEST_IP})"
                    fi
                done
                ipx_addr="ip4.addr"
                info "\nValid: (${_ip})."
            else
                error_continue "Invalid: (${_ip})."
            fi
        fi
    fi

    # Warn if IP is in use
    if ifconfig | grep -qwF "${TEST_IP}"; then
        warn "[WARNING]: IP address in use (${TEST_IP})."
    fi

    # Set interface value
    if [ ! -f "${bastille_jail_conf}" ]; then
        if [ -z "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
            local bastille_jail_conf_interface=${bastille_network_shared}
        fi
        if [ -n "${bastille_network_loopback}" ] && [ -z "${bastille_network_shared}" ]; then
            local bastille_jail_conf_interface=${bastille_network_loopback}
        fi
        if [ -n "${INTERFACE}" ]; then
            local bastille_jail_conf_interface=${INTERFACE}
        fi
    fi

    # Determine IP/Interface mode
    if [ "${_ip}" = "inherit" ]; then
        if [ -n "${DUAL_STACK}" ]; then
            IP4_DEFINITION="ip4 = ${_ip};"
            IP6_DEFINITION="ip6 = ${_ip};"
            IP6_MODE="new"
        else
            IP4_DEFINITION="ip4 = ${_ip};"
            IP6_DEFINITION=""
            IP6_MODE="disable"
        fi
    elif [ "${_ip}" = "ip_hostname" ]; then
        if [ -n "${DUAL_STACK}" ]; then
            IP_HOSTNAME="${_ip}"
            IP4_DEFINITION="${IP_HOSTNAME};"
            IP6_DEFINITION="${IP_HOSTNAME};"
            IP6_MODE="new"
        else
            IP_HOSTNAME="${_ip}"
            IP4_DEFINITION="${IP_HOSTNAME};"
            IP6_DEFINITION=""
            IP6_MODE="disable"
        fi
    elif echo "${_ip}" | grep -qvE '(SLAAC|DHCP|0[.]0[.]0[.]0)'; then
        if [ "${ipx_addr}" = "ip4.addr" ]; then
            IP4_ADDR="${_ip}"
            IP4_DEFINITION="${ipx_addr} = ${bastille_jail_conf_interface}|${_ip};"
        elif [ "${ipx_addr}" = "ip6.addr" ]; then
            IP6_ADDR="${_ip}"
            IP6_DEFINITION="${ipx_addr} = ${bastille_jail_conf_interface}|${_ip};"
            IP6_MODE="new"
        fi
    fi
}

validate_ips() {

    IP6_MODE="disable"
    IP4_DEFINITION=""
    IP6_DEFINITION=""
    IP4_ADDR=""
    IP6_ADDR=""
    IP_HOSTNAME=""

    for ip in ${IP}; do
        validate_ip "${ip}"
    done
}

validate_netif() {

    local LIST_INTERFACES="$(ifconfig -l)"

    if echo "${LIST_INTERFACES} VNET" | grep -qwo "${INTERFACE}"; then
        info "\nValid: (${INTERFACE})."
    else
        error_exit "[ERROR]: Invalid: (${INTERFACE})."
    fi
}

validate_release() {

    ## ensure the user set the Linux(experimental) option explicitly
    if [ -n "${UBUNTU}" ]; then
        if [ -z "${LINUX_JAIL}" ]; then
            usage
        fi
    fi

    ## check release name match, else show usage
    if [ -n "${NAME_VERIFY}" ]; then
        RELEASE="${NAME_VERIFY}"
    else
        usage
    fi
}

generate_minimal_conf() {

    cat << EOF > "${bastille_jail_conf}"
${NAME} {
  host.hostname = ${NAME};
  mount.fstab = ${bastille_jail_fstab};
  path = ${bastille_jail_path};
}
EOF
    touch "${bastille_jail_fstab}"
}

generate_jail_conf() {

    if [ "$(sysctl -n security.jail.jailed)" -eq 1 ]; then
        devfs_ruleset_value=0
    else
        devfs_ruleset_value=4
    fi
    cat << EOF > "${bastille_jail_conf}"
${NAME} {
  enforce_statfs = 2;
  devfs_ruleset = ${devfs_ruleset_value};
  exec.clean;
  exec.consolelog = ${bastille_jail_log};
  exec.start = '/bin/sh /etc/rc';
  exec.stop = '/bin/sh /etc/rc.shutdown';
  host.hostname = ${NAME};
  mount.devfs;
  mount.fstab = ${bastille_jail_fstab};
  path = ${bastille_jail_path};
  securelevel = 2;
  osrelease = ${RELEASE};

  ${IP4_DEFINITION}
  ${IP6_DEFINITION}
  ip6 = ${IP6_MODE};
}
EOF
}

generate_linux_jail_conf() {

    cat << EOF > "${bastille_jail_conf}"
${NAME} {
  host.hostname = ${NAME};
  mount.fstab = ${bastille_jail_fstab};
  path = ${bastille_jail_path};
  devfs_ruleset = 4;
  enforce_statfs = 1;

  exec.start = '/bin/true';
  exec.stop = '/bin/true';
  persist;

  allow.mount;
  allow.mount.devfs;

  ${IP4_DEFINITION}
  ${IP6_DEFINITION}
  ip6 = ${IP6_MODE};
}
EOF
}

generate_vnet_jail_conf() {

    if [ "$(sysctl -n security.jail.jailed)" -eq 1 ]; then
        devfs_ruleset_value=0
    else
        devfs_ruleset_value=13
    fi

    NETBLOCK=$(generate_vnet_jail_netblock "${NAME}" "${VNET_JAIL_BRIDGE}" "${bastille_jail_conf_interface}" "${STATIC_MAC}")

    cat << EOF > "${bastille_jail_conf}"
${NAME} {
  enforce_statfs = 2;
  devfs_ruleset = ${devfs_ruleset_value};
  exec.clean;
  exec.consolelog = ${bastille_jail_log};
  exec.start = '/bin/sh /etc/rc';
  exec.stop = '/bin/sh /etc/rc.shutdown';
  host.hostname = ${NAME};
  mount.devfs;
  mount.fstab = ${bastille_jail_fstab};
  path = ${bastille_jail_path};
  securelevel = 2;
  osrelease = ${RELEASE};

${NETBLOCK}
}
EOF
}

post_create_jail() {

    # Common config checks and settings.

    # Using relative paths here.
    # MAKE SURE WE'RE IN THE RIGHT PLACE.
    cd "${bastille_jail_path}" || error_exit "Could not cd to ${bastille_jail_path}"

    if [ ! -f "${bastille_jail_conf}" ]; then
        if [ -z "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
            local bastille_jail_conf_interface=${bastille_network_shared}
        fi
        if [ -n "${bastille_network_loopback}" ] && [ -z "${bastille_network_shared}" ]; then
            local bastille_jail_conf_interface=${bastille_network_loopback}
        fi
        if [ -n "${INTERFACE}" ]; then
            local bastille_jail_conf_interface=${INTERFACE}
        fi
    fi

    if [ ! -f "${bastille_jail_fstab}" ]; then
        if [ -z "${THICK_JAIL}" ] && [ -z "${CLONE_JAIL}" ]; then
            echo -e "${bastille_releasesdir}/${RELEASE} ${bastille_jail_base} nullfs ro 0 0" > "${bastille_jail_fstab}"
        else
            touch "${bastille_jail_fstab}"
        fi
    fi

    # Generate the jail configuration file.
    if [ -n "${VNET_JAIL}" ]; then
        generate_vnet_jail_conf
    else
        generate_jail_conf
    fi

}

create_jail() {

    bastille_jail_base="${bastille_jailsdir}/${NAME}/root/.bastille"  ## dir
    bastille_jail_template="${bastille_jailsdir}/${NAME}/root/.template"  ## dir
    bastille_jail_path="${bastille_jailsdir}/${NAME}/root"  ## dir
    bastille_jail_fstab="${bastille_jailsdir}/${NAME}/fstab"  ## file
    bastille_jail_conf="${bastille_jailsdir}/${NAME}/jail.conf"  ## file
    bastille_jail_log="${bastille_logsdir}/${NAME}_console.log"  ## file
    # shellcheck disable=SC2034
    bastille_jail_rc_conf="${bastille_jailsdir}/${NAME}/root/etc/rc.conf" ## file
    # shellcheck disable=SC2034
    bastille_jail_resolv_conf="${bastille_jailsdir}/${NAME}/root/etc/resolv.conf" ## file

    if [ ! -d "${bastille_jailsdir}/${NAME}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                ## create required zfs datasets, mountpoint inherited from system
                if [ -z "${CLONE_JAIL}" ]; then
                    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}"
                fi
                if [ -z "${THICK_JAIL}" ] && [ -z "${CLONE_JAIL}" ]; then
                    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"
                fi
            fi
        else
            mkdir -p "${bastille_jailsdir}/${NAME}/root"
        fi
    # Check if the jail directory has been mounted under UFS (not supported)
    elif [ ! -d "${bastille_jailsdir}/${NAME}/root" ] && ! checkyesno bastille_zfs_enable; then
        if mount | grep "${bastille_jailsdir}/${NAME}" | grep -oq "ufs"; then
            error_exit "[ERROR]: Using UFS mounts for the jail directory is not supported."
        fi
    fi


    ## PoC for Linux jails @hackacad
    if [ -n "${LINUX_JAIL}" ]; then
        info "\nCreating a linuxjail. This may take a while...\n"
        if [ ! -d "${bastille_jail_base}" ]; then
            mkdir -p "${bastille_jail_base}"
        fi
        mkdir -p "${bastille_jail_path}/dev"
        mkdir -p "${bastille_jail_path}/proc"
        mkdir -p "${bastille_jail_path}/sys"
        mkdir -p "${bastille_jail_path}/home"
        mkdir -p "${bastille_jail_path}/tmp"
        touch "${bastille_jail_path}/dev/shm"
        touch "${bastille_jail_path}/dev/fd"
        cp -RPf ${bastille_releasesdir}/${RELEASE}/* ${bastille_jail_path}/
        echo "${NAME}" > ${bastille_jail_path}/etc/hostname

        if [ ! -d "${bastille_jail_template}" ]; then
            mkdir -p "${bastille_jail_template}"
        fi

        if [ ! -f "${bastille_jail_fstab}" ]; then
            touch "${bastille_jail_fstab}"
        fi
        echo -e "devfs           ${bastille_jail_path}/dev      devfs           rw                      0       0" >> "${bastille_jail_fstab}"
        echo -e "tmpfs           ${bastille_jail_path}/dev/shm  tmpfs           rw,size=1g,mode=1777    0       0" >> "${bastille_jail_fstab}"
        echo -e "fdescfs         ${bastille_jail_path}/dev/fd   fdescfs         rw,linrdlnk             0       0" >> "${bastille_jail_fstab}"
        echo -e "linprocfs       ${bastille_jail_path}/proc     linprocfs       rw                      0       0" >> "${bastille_jail_fstab}"
        echo -e "linsysfs        ${bastille_jail_path}/sys      linsysfs        rw                      0       0" >> "${bastille_jail_fstab}"
        echo -e "/tmp            ${bastille_jail_path}/tmp      nullfs          rw                      0       0" >> "${bastille_jail_fstab}"
        ## removed temporarely / only for X11 jails? @hackacad
        #echo -e "/home           ${bastille_jail_path}/home     nullfs          rw                      0       0" >> "${bastille_jail_fstab}"

        if [ ! -f "${bastille_jail_conf}" ]; then
            if [ -z "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
                local bastille_jail_conf_interface=${bastille_network_shared}
            fi
            if [ -n "${bastille_network_loopback}" ] && [ -z "${bastille_network_shared}" ]; then
                local bastille_jail_conf_interface=${bastille_network_loopback}
            fi
            if [ -n "${INTERFACE}" ]; then
                local bastille_jail_conf_interface=${INTERFACE}
            fi
        fi
    fi

    if [ -z "${EMPTY_JAIL}" ] && [ -z "${LINUX_JAIL}" ]; then
        if [ -z "${THICK_JAIL}" ] && [ -z "${CLONE_JAIL}" ]; then
            if [ ! -d "${bastille_jail_base}" ]; then
                mkdir -p "${bastille_jail_base}"
            fi
            if [ ! -d "${bastille_jail_template}" ]; then
                mkdir -p "${bastille_jail_template}"
            fi
        fi

        if [ ! -d "${bastille_jail_path}/usr/local" ]; then
            mkdir -p "${bastille_jail_path}/usr/local"
        fi

        # Check and apply required settings.
        post_create_jail

        if [ -z "${THICK_JAIL}" ] && [ -z "${CLONE_JAIL}" ]; then
            LINK_LIST="bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/sbin usr/share usr/src"
            info "\nCreating a thinjail..."
            for _link in ${LINK_LIST}; do
                ln -sf /.bastille/${_link} ${_link}
            done

            # Properly link shared ports on thin jails in read-write.
            if [ -d "${bastille_releasesdir}/${RELEASE}/usr/ports" ]; then
                if [ ! -d "${bastille_jail_path}/usr/ports" ]; then
                    mkdir ${bastille_jail_path}/usr/ports
                fi
                echo -e "${bastille_releasesdir}/${RELEASE}/usr/ports ${bastille_jail_path}/usr/ports nullfs rw 0 0" >> "${bastille_jail_fstab}"
            fi
        fi

        if [ -z "${THICK_JAIL}" ] && [ -z "${CLONE_JAIL}" ]; then
            ## rw
            ## copy only required files for thin jails
            FILE_LIST=".cshrc .profile COPYRIGHT dev etc media mnt net proc root tmp var usr/obj usr/tests"
            for files in ${FILE_LIST}; do
                if [ -f "${bastille_releasesdir}/${RELEASE}/${files}" ] || [ -d "${bastille_releasesdir}/${RELEASE}/${files}" ]; then
                    if ! cp -a "${bastille_releasesdir}/${RELEASE}/${files}" "${bastille_jail_path}/${files}"; then
                        ## notify and clean stale files/directories
                        bastille destroy -af "${NAME}"
                        error_exit "[ERROR]: Failed to copy release files. Please retry create!"
                    fi
                fi
            done
        else
            if checkyesno bastille_zfs_enable; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    if [ -n "${CLONE_JAIL}" ]; then
                        info "\nCreating a clonejail...\n"
                        ## clone the release base to the new basejail
                        SNAP_NAME="bastille-clone-$(date +%Y-%m-%d-%H%M%S)"
                        # shellcheck disable=SC2140
                        zfs snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}"
                        # shellcheck disable=SC2140
                        zfs clone -p "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}" \
                        "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"

                        # Check and apply required settings.
                        post_create_jail
                    elif [ -n "${THICK_JAIL}" ]; then

                        info "\nCreating a thickjail. This may take a while..."

                        ## perform release base replication
                        ## sane bastille zfs options
                        ZFS_OPTIONS=$(echo ${bastille_zfs_options} | sed 's/-o//g')
                        ## send without -R if encryption is enabled
                        if [ "$(zfs get -H -o value encryption "${bastille_zfs_zpool}/${bastille_zfs_prefix}")" = "off" ]; then
                            OPT_SEND="-R"
                        else
                            OPT_SEND=""
                        fi

                        ## take a temp snapshot of the base release
                        SNAP_NAME="bastille-$(date +%Y-%m-%d-%H%M%S)"
                        # shellcheck disable=SC2140
                        zfs snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}"

                        ## replicate the release base to the new thickjail and set the default mountpoint
                        # shellcheck disable=SC2140
                        zfs send ${OPT_SEND} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}" | \
                        zfs receive "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"
                        zfs set ${ZFS_OPTIONS} mountpoint=none "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"
                        zfs inherit mountpoint "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"

                        ## cleanup temp snapshots initially
                        # shellcheck disable=SC2140
                        zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}"
                        # shellcheck disable=SC2140
                        zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"@"${SNAP_NAME}"
                    fi

                    if [ "$?" -ne 0 ]; then
                        ## notify and clean stale files/directories
                        bastille destroy -af "${NAME}"
                        error_exit "[ERROR]: Failed release base replication. Please retry create!"
                    fi
                fi
            else
                ## copy all files for thick jails
                cp -a "${bastille_releasesdir}/${RELEASE}/" "${bastille_jail_path}"
                if [ "$?" -ne 0 ]; then
                    ## notify and clean stale files/directories
                    bastille destroy -afy "${NAME}"
                    error_exit "[ERROR]: Failed to copy release files. Please retry create!"
                fi
            fi
        fi

        if [ -z "${LINUX_JAIL}" ]; then
            ## create home directory if missing
            if [ ! -d "${bastille_jail_path}/usr/home" ]; then
                mkdir -p "${bastille_jail_path}/usr/home"
            fi
            ## link home properly
            if [ ! -L "home" ]; then
                ln -s usr/home home
            fi

            ## TZ: configurable (default: empty to use host's time zone)
            if [ -z "${bastille_tzdata}" ]; then
                # Note that if host has no time zone, FreeBSD assumes UTC anyway
                if [ -e /etc/localtime ]; then
                    # uses cp as a way to prevent issues with symlinks if the host happens to use that for tz configuration
                    cp /etc/localtime etc/localtime
                fi
            else
                ln -s "/usr/share/zoneinfo/${bastille_tzdata}" etc/localtime
            fi

            # Post-creation jail misc configuration
            # Create a dummy fstab file
            touch "etc/fstab"
            # Disables adjkerntz, avoids spurious error messages
            sed -i '' 's|[0-9],[0-9]\{2\}.*[0-9]-[0-9].*root.*kerntz -a|#& # Disabled by bastille|' "etc/crontab"
        fi

        ## VNET specific
        if [ -n "${VNET_JAIL}" ]; then
            ## VNET requires jib or jng script
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
        fi
    elif [ -n "${LINUX_JAIL}" ]; then
        ## Generate configuration for Linux jail
        generate_linux_jail_conf
    elif [ -n "${EMPTY_JAIL}" ]; then
        ## Generate minimal configuration for empty jail
        generate_minimal_conf
    fi

    # Set strict permissions on the jail by default
    chmod 0700 "${bastille_jailsdir}/${NAME}"

    # Apply boot, depends and priority settings before starting jail
    sysrc -f "${bastille_jailsdir}/${NAME}/settings.conf" boot=${BOOT} >/dev/null
    sysrc -f "${bastille_jailsdir}/${NAME}/settings.conf" depend="" >/dev/null
    sysrc -f "${bastille_jailsdir}/${NAME}/settings.conf" priority="${PRIORITY}" >/dev/null

    # Jail must be started before applying the default template. -- cwells
    if [ -z "${EMPTY_JAIL}" ]; then
        bastille start "${NAME}"
    elif [ -n "${EMPTY_JAIL}" ]; then
        # Don't start empty jails unless a template defined.
        if [ -n "${bastille_template_empty}" ]; then
            bastille start "${NAME}"
        fi
    fi

    # Exit if jail was not started, except for empty jails
    if [ -z "${EMPTY_JAIL}" ]; then
        if ! check_target_is_running "${NAME}"; then
            bastille destroy -afy "${NAME}"
            error_exit "[ERROR]: Failed to create jail: ${NAME}"
        fi
    fi

    if [ -n "${VNET_JAIL}" ]; then
        if [ -n "${bastille_template_vnet}" ]; then
            ## rename interface to generic vnet0
            uniq_epair=$(grep vnet.interface "${bastille_jailsdir}/${NAME}/jail.conf" | awk '{print $3}' | sed 's/;//; s/-/_/g')

            _gateway=''
            _gateway6=''
            _ifconfig_inet=''
            _ifconfig_inet6=''

            if echo "${IP}" | grep -qE '(0[.]0[.]0[.]0|DHCP)'; then
                # Enable DHCP if requested
                _ifconfig_inet=SYNCDHCP
            else
                # Else apply the default gateway
                if [ -n "${OPT_GATEWAY}" ]; then
                    _gateway="${OPT_GATEWAY}"
                elif [ -n "${bastille_network_gateway}" ]; then
                    _gateway="${bastille_network_gateway}"
                else
                    _gateway="$(netstat -4rn | awk '/default/ {print $2}')"
                fi
            fi
            # Add IPv4 address (this is empty if DHCP is used)
            if [ -n "${IP4_ADDR}" ]; then
                    _ifconfig_inet="${_ifconfig_inet} inet ${IP4_ADDR}"
            fi
            # Enable IPv6 if used
            if [ "${IP6_MODE}" != "disable" ]; then
                _ifconfig_inet6='inet6 -ifdisabled'
                if echo "${IP}" | grep -qE 'SLAAC'; then
                    # Enable SLAAC if requested
                    _ifconfig_inet6="${_ifconfig_inet6} accept_rtadv"
                else
                    # Else apply the default gateway
                    if [ -n "${bastille_network_gateway6}" ]; then
                        _gateway6="${bastille_network_gateway6}"
                    else
                        _gateway6="$(netstat -6rn | awk '/default/ {print $2}')"
                    fi
                fi
            fi
            # Add IPv6 address (this is empty if SLAAC is used)
            if [ -n "${IP6_ADDR}" ]; then
                    _ifconfig_inet6="${_ifconfig_inet6} ${IP6_ADDR}"
            fi
            # Join together IPv4 and IPv6 parts of ifconfig
            _ifconfig="${_ifconfig_inet} ${_ifconfig_inet6}"
            bastille template "${NAME}" ${bastille_template_vnet} --arg EPAIR="${uniq_epair}" --arg GATEWAY="${_gateway}" --arg GATEWAY6="${_gateway6}" --arg IFCONFIG="${_ifconfig}"

            # Add VLAN ID if it was given
	    if [ -n "${VLAN_ID}" ]; then
                bastille template "${NAME}" ${bastille_template_vlan} --arg VLANID="${VLAN_ID}" --arg IFCONFIG="${_ifconfig}"
	    fi
        fi
    fi
    if [ -n "${THICK_JAIL}" ]; then
        if [ -n "${bastille_template_thick}" ]; then
            bastille template "${NAME}" ${bastille_template_thick} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    elif [ -n "${CLONE_JAIL}" ]; then
        if [ -n "${bastille_template_clone}" ]; then
            bastille template "${NAME}" ${bastille_template_clone} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    elif [ -n "${EMPTY_JAIL}" ]; then
        if [ -n "${bastille_template_empty}" ]; then
            bastille template "${NAME}" ${bastille_template_empty} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    ## Using templating function to fetch necessary packges @hackacad
    elif [ -n "${LINUX_JAIL}" ]; then
        info "\nFetching packages..."
        jexec -l "${NAME}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive rm /var/cache/apt/archives/rsyslog*.deb"
        jexec -l "${NAME}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive dpkg --force-depends --force-confdef --force-confold -i /var/cache/apt/archives/*.deb"
        jexec -l "${NAME}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive dpkg --force-depends --force-confdef --force-confold -i /var/cache/apt/archives/*.deb"
        jexec -l "${NAME}" /bin/bash -c "chmod 777 /tmp"
        jexec -l "${NAME}" /bin/bash -c "apt update"
    else
        # Thin jail.
        if [ -n "${bastille_template_thin}" ]; then
            bastille template "${NAME}" ${bastille_template_thin} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    fi

    # Apply nameserver (if set)
    if [ -n "${OPT_NAMESERVER}" ]; then
        sed -i '' "\#nameserver.*# s#nameserver.*#nameserver ${OPT_NAMESERVER}#" "${bastille_jail_resolv_conf}"
    fi

    # Apply values changed by the template. -- cwells
    if [ -z "${EMPTY_JAIL}" ] && [ -z "${LINUX_JAIL}" ]; then
        bastille restart "${NAME}"
    elif [ -n "${EMPTY_JAIL}" ]; then
        # Don't restart empty jails unless a template defined.
        if [ -n "${bastille_template_empty}" ]; then
            bastille restart "${NAME}"
        fi
    fi
}

bastille_root_check

if echo "${3}" | grep '@'; then
    # shellcheck disable=SC2034
    BASTILLE_JAIL_IP=$(echo "$3" | awk -F@ '{print $2}')
    # shellcheck disable=SC2034
    BASTILLE_JAIL_INTERFACES=$( echo "$3" | awk -F@ '{print $1}')
fi

# Handle options.
BOOT="on"
EMPTY_JAIL=""
THICK_JAIL=""
CLONE_JAIL=""
VNET_JAIL=""
VLAN_ID=""
LINUX_JAIL=""
STATIC_MAC=""
DUAL_STACK=""
VALIDATE_RELEASE="1"
PRIORITY="99"
OPT_GATEWAY=""
OPT_NAMESERVER=""
while [ $# -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -B|--bridge)
            VNET_JAIL="1"
            VNET_JAIL_BRIDGE="1"
            shift
            ;;
        -C|--clone)
            CLONE_JAIL="1"
            shift
            ;;
        -D|--dual)
            DUAL_STACK="1"
            shift
            ;;
        -E|--empty)
            EMPTY_JAIL="1"
            shift
            ;;
        -g|--gateway|--defaultrouter)
            OPT_GATEWAY="${2}"
	    # Validate gateway
            if [ -n "${OPT_GATEWAY}" ]; then
                if ! validate_ip "${OPT_GATEWAY}" >/dev/null 2>/dev/null; then
                    error_exit "[ERROR]: Not a valid gateway: ${OPT_GATEWAY}"
                fi
            fi
            shift 2
            ;;
        -L|--linux)
            LINUX_JAIL="1"
            shift
            ;;
        -M|--static-mac)
            STATIC_MAC="1"
            shift
            ;;
        -n|--nameserver)
            OPT_NAMESERVER="${2}"
	    # Validate nameserver
            if [ -n "${OPT_NAMESERVER}" ]; then
                if ! validate_ip "${OPT_NAMESERVER}" >/dev/null 2>/dev/null; then
                    error_exit "[ERROR]: Not a valid nameserver: ${OPT_NAMESERVER}"
                fi
            fi
            shift 2
            ;;
        -p|--priority)
	    if echo "${2}" | grep -Eoq "^[0-9]+$"; then
                PRIORITY="${2}"
		shift 2
	    else 
                error_exit "Not a valid priority value: \"${2}\""
	    fi
            ;;
        --no-boot)
            BOOT="off"
            shift
            ;;
        --no-validate|no-validate)
            VALIDATE_RELEASE=""
            shift
            ;;
        -T|--thick)
            THICK_JAIL="1"
            shift
            ;;
        -V|--vnet)
            VNET_JAIL="1"
            shift
            ;;
        -v|--vlan)
            if echo "${2}" | grep -Eq '^[0-9]+$'; then
                VLAN_ID="${2}"
            else
                error_exit "Not a valid VLAN ID: ${2}"
            fi
            shift 2
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -Z|--zfs-opts)
            bastille_zfs_options="${2}"
            shift 2
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    B) VNET_JAIL=1 VNET_JAIL_BRIDGE=1 ;;
                    C) CLONE_JAIL=1 ;;
                    D) DUAL_STACK=1 ;;
                    E) EMPTY_JAIL=1 ;;
                    L) LINUX_JAIL=1 ;;
                    M) STATIC_MAC=1 ;;
                    T) THICK_JAIL=1 ;;
                    V) VNET_JAIL=1 ;;
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

# Validate options
if [ -n "${EMPTY_JAIL}" ]; then
    if [ -n "${CLONE_JAIL}" ] || [ -n "${THICK_JAIL}" ] || [ -n "${VNET_JAIL}" ] || [ -n "${LINUX_JAIL}" ]; then
        error_exit "[ERROR]: Empty jail option can't be used with other options."
    fi
elif [ -n "${LINUX_JAIL}" ]; then
    if [ -n "${EMPTY_JAIL}" ] || [ -n "${VNET_JAIL}" ] || [ -n "${THICK_JAIL}" ] || [ -n "${CLONE_JAIL}" ]; then
        error_exit "[ERROR]: Linux jail option can't be used with other options."
    fi
elif [ -n "${CLONE_JAIL}" ] && [ -n "${THICK_JAIL}" ]; then
    error_exit "[ERROR]: Clonejail and Thickjail can't be used together."
elif [ -z "${VNET_JAIL}" ] && [ -z "${VNET_JAIL_BRIDGE}" ] && [ -n "${VLAN_ID}" ]; then
    error_exit "[ERROR]: VLANs can only be used with VNET and bridged VNET jails."
fi

NAME="$1"
RELEASE="$2"
IP="$3"
INTERFACE="$4"

info "\nAttempting to create jail: ${NAME}"

if [ -n "${EMPTY_JAIL}" ]; then
    if [ $# -ne 1 ]; then
        usage
    fi
else
    if [ $# -gt 4 ] || [ $# -lt 3 ]; then
        usage
    fi
fi

# Validate jail name
if [ -n "${NAME}" ]; then
    validate_name
fi

# Validate interface type
if [ -n "${VNET_JAIL}" ] && [ -n "${VNET_JAIL_BRIDGE}" ]; then
    if ! ifconfig -g bridge | grep -owq "${INTERFACE}"; then
        error_exit "[ERROR]: Interface is not a bridge: ${INTERFACE}"
    fi
elif [ -n "${VNET_JAIL}" ] && [ -z "${VNET_JAIL_BRIDGE}" ]; then
    if ifconfig -g bridge | grep -owq "${INTERFACE}"; then
        error_exit "[ERROR]: Interface is a bridge: ${INTERFACE}"
    fi
fi

# Do not allow netgraph with -B|--bridge yet...
if [ "${bastille_network_vnet_type}" = "netgraph" ] && [ -n "${VNET_JAIL_BRIDGE}" ]; then
    error_exit "[ERROR]: Netgraph does not support the [-B|--bridge] option."
fi

if [ -n "${LINUX_JAIL}" ] && [ -n "${VALIDATE_RELEASE}" ]; then
    case "${RELEASE}" in
    bionic|ubuntu_bionic|ubuntu|ubuntu-bionic)
        ## check for FreeBSD releases name
        NAME_VERIFY=ubuntu_bionic
        ;;
    focal|ubuntu_focal|ubuntu-focal)
        ## check for FreeBSD releases name
        NAME_VERIFY=ubuntu_focal
        ;;
    jammy|ubuntu_jammy|ubuntu-jammy)
        ## check for FreeBSD releases name
        NAME_VERIFY=ubuntu_jammy
        ;;
    debian_buster|buster|debian-buster)
        ## check for FreeBSD releases name
        NAME_VERIFY=buster
        ;;
    debian_bullseye|bullseye|debian-bullseye)
        ## check for FreeBSD releases name
        NAME_VERIFY=bullseye
        ;;
    debian_bookworm|bookworm|debian-bookworm)
        ## check for FreeBSD releases name
        NAME_VERIFY=bookworm
        ;;
    *)
        error_notify "[ERROR]: Unknown linux release."
        usage
        ;;
    esac
fi

if [ -z "${EMPTY_JAIL}" ]; then
    if [ -n "${VALIDATE_RELEASE}" ]; then
        ## verify release
        case "${RELEASE}" in
        2.[0-9]*)
            ## check for MidnightBSD releases name
            NAME_VERIFY=$(echo "${RELEASE}")
            validate_release
            ;;
        *-CURRENT|*-CURRENT-I386|*-CURRENT-i386|*-current)
            ## check for FreeBSD releases name
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-CURRENT|-CURRENT-i386)$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
            validate_release
            ;;
        *-RELEASE|*-RELEASE-I386|*-RELEASE-i386|*-release|*-RC[1-9]|*-rc[1-9]|*-BETA[1-9])
            ## check for FreeBSD releases name
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RELEASE-i386|-RC[1-9]|-BETA[1-9])$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
            validate_release
            ;;
        *-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
            ## check for HardenedBSD releases name(previous infrastructure)
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})(-stable-last)$' | sed 's/STABLE/stable/g' | sed 's/last/LAST/g')
            validate_release
            ;;
        *-stable-build-[0-9]*|*-STABLE-BUILD-[0-9]*)
            ## check for HardenedBSD(specific stable build releases)
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '([0-9]{1,2})(-stable-build)-([0-9]{1,3})$' | sed 's/BUILD/build/g' | sed 's/STABLE/stable/g')
            validate_release
            ;;
        *-stable-build-latest|*-stable-BUILD-LATEST|*-STABLE-BUILD-LATEST)
            ## check for HardenedBSD(latest stable build release)
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '([0-9]{1,2})(-stable-build-latest)$' | sed 's/STABLE/stable/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
            validate_release
            ;;
        current-build-[0-9]*|CURRENT-BUILD-[0-9]*)
            ## check for HardenedBSD(specific current build releases)
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '(current-build)-([0-9]{1,3})' | sed 's/BUILD/build/g' | sed 's/CURRENT/current/g')
            validate_release
            ;;
        current-build-latest|current-BUILD-LATEST|CURRENT-BUILD-LATEST)
            ## check for HardenedBSD(latest current build release)
            NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '(current-build-latest)' | sed 's/CURRENT/current/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
            validate_release
            ;;
        ubuntu_bionic|bionic|ubuntu-bionic)
            UBUNTU="1"
            NAME_VERIFY=Ubuntu_1804
            validate_release
            ;;
        ubuntu_focal|focal|ubuntu-focal)
            UBUNTU="1"
            NAME_VERIFY=Ubuntu_2004
            validate_release
            ;;
        ubuntu_jammy|jammy|ubuntu-jammy)
            UBUNTU="1"
            NAME_VERIFY=Ubuntu_2204
            validate_release
            ;;
        debian_buster|buster|debian-buster)
            NAME_VERIFY=Debian10
            validate_release
            ;;
        debian_bullseye|bullseye|debian-bullseye)
            NAME_VERIFY=Debian11
            validate_release
            ;;
        debian_bookworm|bookworm|debian-bookworm)
            NAME_VERIFY=Debian12
            validate_release
            ;;
        *)
            error_notify "Unknown Release."
            usage
            ;;
        esac
    fi

    # Check for name/root/.bastille
    if [ -d "${bastille_jailsdir}/${NAME}/root/.bastille" ]; then
        error_exit "[ERROR]: ${NAME} already exists. ${NAME}/root/.bastille exists."
    fi

    # Check for required release
    if [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        error_notify "[ERROR]: Release must be bootstrapped first."
        error_exit "See 'bastille bootstrap'."
    fi

    # Validate IP address
    if [ -n "${IP}" ]; then
        validate_ips
    else
        usage
    fi

    # Validate interface
    if [ -n "${INTERFACE}" ]; then
        validate_netif
        validate_netconf
    elif [ -n "${VNET_JAIL}" ]; then
        if [ -z "${INTERFACE}" ]; then
            if [ -z "${bastille_network_shared}" ]; then
                # User must specify interface on vnet jails.
                error_exit "[ERROR]: Network interface not defined."
            else
                validate_netconf
            fi
        fi
    else
        validate_netconf
    fi
else
    info "\nCreating empty jail: ${NAME}."
fi

# May not exist on deployments created before Bastille 0.7.20200714, so creating it. -- cwells
if [ ! -e "${bastille_templatesdir}/default" ]; then
    ln -s "${bastille_sharedir}/templates/default" "${bastille_templatesdir}/default"
fi

# These variables were added after Bastille 0.7.20200714, so they may not exist in the user's config.
# We're checking for existence of the variables rather than empty since empty is a valid value. -- cwells
if [ -z ${bastille_template_base+x} ]; then
    bastille_template_base='default/base'
fi
if [ -z ${bastille_template_empty+x} ]; then
    bastille_template_empty='default/empty'
fi
if [ -z ${bastille_template_linux+x} ]; then
    bastille_template_linux='default/linux'
fi
if [ -z ${bastille_template_thick+x} ]; then
    bastille_template_thick='default/thick'
fi
if [ -z ${bastille_template_clone+x} ]; then
    bastille_template_clone='default/clone'
fi
if [ -z ${bastille_template_thin+x} ]; then
    bastille_template_thin='default/thin'
fi
if [ -z ${bastille_template_vnet+x} ]; then
    bastille_template_vnet='default/vnet'
fi

if check_target_exists "${NAME}"; then
    error_exit "[ERROR]: Jail already exists: ${NAME}"
fi

create_jail "${NAME}" "${RELEASE}" "${IP}" "${INTERFACE}"

echo
