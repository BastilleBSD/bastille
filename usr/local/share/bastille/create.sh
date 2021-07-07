#!/bin/sh
#
# Copyright (c) 2018-2021, Christer Edwards <christer.edwards@gmail.com>
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
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_exit "Usage: bastille create [empty|thick|vnet] name release ip [interface]"
}

running_jail() {
    if [ -n "$(jls name | awk "/^${NAME}$/")" ]; then
        error_exit "A running jail matches name."
    elif [ -d "${bastille_jailsdir}/${NAME}" ]; then
        error_exit "Jail: ${NAME} already created."
    fi
}

validate_name() {
    local NAME_VERIFY=${NAME}
    local NAME_SANITY=$(echo "${NAME_VERIFY}" | tr -c -d 'a-zA-Z0-9-_')
    if [ -n "$(echo "${NAME_SANITY}" | awk "/^[-_].*$/" )" ]; then
        error_exit "Container names may not begin with (-|_) characters!"
    elif [ "${NAME_VERIFY}" != "${NAME_SANITY}" ]; then
        error_exit "Container names may not contain special characters!"
    fi
}

validate_ip() {
    IPX_ADDR="ip4.addr"
    IP6_MODE="disable"
    ip6=$(echo "${IP}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$))')
    if [ -n "${ip6}" ]; then
        info "Valid: (${ip6})."
        IPX_ADDR="ip6.addr"
        IP6_MODE="new"
    else
        local IFS
        if echo "${IP}" | grep -Eq '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$'; then
            TEST_IP=$(echo "${IP}" | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    echo "Invalid: (${TEST_IP})"
                    exit 1
                fi
            done
            if ifconfig | grep -qw "${TEST_IP}"; then
                warn "Warning: IP address already in use (${TEST_IP})."
            else
                info "Valid: (${IP})."
            fi
        else
            error_exit "Invalid: (${IP})."
        fi
    fi
}

validate_netif() {
    local LIST_INTERFACES=$(ifconfig -l)
    if echo "${LIST_INTERFACES} VNET" | grep -qwo "${INTERFACE}"; then
        info "Valid: (${INTERFACE})."
    else
        error_exit "Invalid: (${INTERFACE})."
    fi
}

validate_netconf() {
    if [ -n "${bastille_network_loopback}" ] && [ -n "${bastille_network_shared}" ]; then
        error_exit "Invalid network configuration."
    fi
}

validate_release() {
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
    cat << EOF > "${bastille_jail_conf}"
${NAME} {
  devfs_ruleset = 4;
  enforce_statfs = 2;
  exec.clean;
  exec.consolelog = ${bastille_jail_log};
  exec.start = '/bin/sh /etc/rc';
  exec.stop = '/bin/sh /etc/rc.shutdown';
  host.hostname = ${NAME};
  mount.devfs;
  mount.fstab = ${bastille_jail_fstab};
  path = ${bastille_jail_path};
  securelevel = 2;

  interface = ${bastille_jail_conf_interface};
  ${IPX_ADDR} = ${IP};
  ip6 = ${IP6_MODE};
}
EOF
}

generate_vnet_jail_conf() {
    ## determine number of containers + 1
    ## iterate num and grep all jail configs
    ## define uniq_epair
    local jail_list=$(bastille list jails)
    if [ -n "${jail_list}" ]; then
        local list_jails_num=$(echo "${jail_list}" | wc -l | awk '{print $1}')
        local num_range=$(expr "${list_jails_num}" + 1)
        for _num in $(seq 0 "${num_range}"); do
            if ! grep -q "e0b_bastille${_num}" "${bastille_jailsdir}"/*/jail.conf; then
                uniq_epair="bastille${_num}"
                break
            fi
        done
    else
        uniq_epair="bastille0"
    fi

    ## generate config
    cat << EOF > "${bastille_jail_conf}"
${NAME} {
  devfs_ruleset = 13;
  enforce_statfs = 2;
  exec.clean;
  exec.consolelog = ${bastille_jail_log};
  exec.start = '/bin/sh /etc/rc';
  exec.stop = '/bin/sh /etc/rc.shutdown';
  host.hostname = ${NAME};
  mount.devfs;
  mount.fstab = ${bastille_jail_fstab};
  path = ${bastille_jail_path};
  securelevel = 2;

  vnet;
  vnet.interface = e0b_${uniq_epair};
  exec.prestart += "jib addm ${uniq_epair} ${bastille_jail_conf_interface}";
  exec.poststop += "jib destroy ${uniq_epair}";
}
EOF
}

create_jail() {
    bastille_jail_base="${bastille_jailsdir}/${NAME}/root/.bastille"  ## dir
    bastille_jail_template="${bastille_jailsdir}/${NAME}/root/.template"  ## dir
    bastille_jail_path="${bastille_jailsdir}/${NAME}/root"  ## dir
    bastille_jail_fstab="${bastille_jailsdir}/${NAME}/fstab"  ## file
    bastille_jail_conf="${bastille_jailsdir}/${NAME}/jail.conf"  ## file
    bastille_jail_log="${bastille_logsdir}/${NAME}_console.log"  ## file
    bastille_jail_rc_conf="${bastille_jailsdir}/${NAME}/root/etc/rc.conf" ## file
    bastille_jail_resolv_conf="${bastille_jailsdir}/${NAME}/root/etc/resolv.conf" ## file

    if [ ! -d "${bastille_jailsdir}/${NAME}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                ## create required zfs datasets, mountpoint inherited from system
                zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}"
                if [ -z "${THICK_JAIL}" ]; then
                    zfs create ${bastille_zfs_options} "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"
                fi
            fi
        else
            mkdir -p "${bastille_jailsdir}/${NAME}/root"
        fi
    fi

    if [ -z "${EMPTY_JAIL}" ]; then
        if [ ! -d "${bastille_jail_base}" ]; then
            mkdir -p "${bastille_jail_base}"
        fi

        if [ ! -d "${bastille_jail_path}/usr/local" ]; then
            mkdir -p "${bastille_jail_path}/usr/local"
        fi

        if [ ! -d "${bastille_jail_template}" ]; then
            mkdir -p "${bastille_jail_template}"
        fi

        if [ ! -f "${bastille_jail_fstab}" ]; then
            if [ -z "${THICK_JAIL}" ]; then
                echo -e "${bastille_releasesdir}/${RELEASE} ${bastille_jail_base} nullfs ro 0 0" > "${bastille_jail_fstab}"
            else
                touch "${bastille_jail_fstab}"
            fi
        fi

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

            ## generate the jail configuration file
            if [ -n "${VNET_JAIL}" ]; then
                generate_vnet_jail_conf
            else
                generate_jail_conf
            fi
        fi

        ## using relative paths here
        ## MAKE SURE WE'RE IN THE RIGHT PLACE
        cd "${bastille_jail_path}"
        echo
        info "NAME: ${NAME}."
        info "IP: ${IP}."
        if [ -n  "${INTERFACE}" ]; then
            info "INTERFACE: ${INTERFACE}."
        fi
        info "RELEASE: ${RELEASE}."
        echo

        if [ -z "${THICK_JAIL}" ]; then
            LINK_LIST="bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/sbin usr/share"
            for _link in ${LINK_LIST}; do
                ln -sf /.bastille/${_link} ${_link}
            done
            # Copy optional distfiles if they exist on the base release.
            if [ -d "${bastille_releasesdir}/${RELEASE}/usr/ports" ]; then
                if [ ! -d "${bastille_jail_path}/usr/ports" ]; then
                    info "Copying ports tree..."
                    cp -a ${bastille_releasesdir}/${RELEASE}/usr/ports ${bastille_jail_path}/usr
                fi
            fi
            if [ -d "${bastille_releasesdir}/${RELEASE}/usr/src" ]; then
                if [ ! -d "${bastille_jail_path}/usr/src" ]; then
                    info "Copying source tree..."
                    ln -sf usr/src sys
                    cp -a ${bastille_releasesdir}/${RELEASE}/usr/src ${bastille_jail_path}/usr
                fi
            fi
            echo
        fi

        if [ -z "${THICK_JAIL}" ]; then
            ## rw
            ## copy only required files for thin jails
            FILE_LIST=".cshrc .profile COPYRIGHT dev etc media mnt net proc root tmp var usr/obj usr/tests"
            for files in ${FILE_LIST}; do
                if [ -f "${bastille_releasesdir}/${RELEASE}/${files}" ] || [ -d "${bastille_releasesdir}/${RELEASE}/${files}" ]; then
                    cp -a "${bastille_releasesdir}/${RELEASE}/${files}" "${bastille_jail_path}/${files}"
                    if [ "$?" -ne 0 ]; then
                        ## notify and clean stale files/directories
                        bastille destroy "${NAME}"
                        error_exit "Failed to copy release files. Please retry create!"
                    fi
                fi
            done
        else
            info "Creating a thickjail. This may take a while..."
            if [ "${bastille_zfs_enable}" = "YES" ]; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    ## perform release base replication

                    ## sane bastille zfs options
                    ZFS_OPTIONS=$(echo ${bastille_zfs_options} | sed 's/-o//g')

                    ## take a temp snapshot of the base release
                    SNAP_NAME="bastille-$(date +%Y-%m-%d-%H%M%S)"
                    zfs snapshot "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}"

                    ## replicate the release base to the new thickjail and set the default mountpoint
                    zfs send -R "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}" | \
                    zfs receive "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"
                    zfs set ${ZFS_OPTIONS} mountpoint=none "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"
                    zfs inherit mountpoint "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"

                    ## cleanup temp snapshots initially
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"@"${SNAP_NAME}"
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root"@"${SNAP_NAME}"

                    if [ "$?" -ne 0 ]; then
                        ## notify and clean stale files/directories
                        bastille destroy "${NAME}"
                        error_exit "Failed release base replication. Please retry create!"
                    fi
                fi
            else
                ## copy all files for thick jails
                cp -a "${bastille_releasesdir}/${RELEASE}/" "${bastille_jail_path}"
                if [ "$?" -ne 0 ]; then
                    ## notify and clean stale files/directories
                    bastille destroy "${NAME}"
                    error_exit "Failed to copy release files. Please retry create!"
                fi
            fi
        fi

        ## create home directory if missing
        if [ ! -d "${bastille_jail_path}/usr/home" ]; then
            mkdir -p "${bastille_jail_path}/usr/home"
        fi
        ## link home properly
        if [ ! -L "home" ]; then
            ln -s usr/home home
        fi

        ## TZ: configurable (default: Etc/UTC)
        ln -s "/usr/share/zoneinfo/${bastille_tzdata}" etc/localtime

        # Post-creation jail misc configuration
        # Create a dummy fstab file
        touch "etc/fstab"
        # Disables adjkerntz, avoids spurious error messages
        sed -i '' 's|[0-9],[0-9]\{2\}.*[0-9]-[0-9].*root.*kerntz -a|#& # Disabled by bastille|' "etc/crontab"

        ## VNET specific
        if [ -n "${VNET_JAIL}" ]; then
            ## VNET requires jib script
            if [ ! "$(command -v jib)" ]; then
                if [ -f /usr/share/examples/jails/jib ] && [ ! -f /usr/local/bin/jib ]; then
                    install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib
                fi
            fi
        fi
    else
        ## Generate minimal configuration for empty jail
        generate_minimal_conf
    fi

    # Set strict permissions on the jail by default
    chmod 0700 "${bastille_jailsdir}/${NAME}"

    # Jail must be started before applying the default template. -- cwells
    if [ -z "${EMPTY_JAIL}" ]; then
        bastille start "${NAME}"
    elif [ -n "${EMPTY_JAIL}" ]; then
        # Don't start empty jails unless a template defined.
        if [ -n "${bastille_template_empty}" ]; then
            bastille start "${NAME}"
        fi
    fi

    if [ -n "${VNET_JAIL}" ]; then
        if [ -n "${bastille_template_vnet}" ]; then
            ## rename interface to generic vnet0
            uniq_epair=$(grep vnet.interface "${bastille_jailsdir}/${NAME}/jail.conf" | awk '{print $3}' | sed 's/;//')

            _gateway=''
            _ifconfig=SYNCDHCP
            if [ "${IP}" != "0.0.0.0" ]; then # not using DHCP, so set static address.
                if [ -n "${ip6}" ]; then
                    _ifconfig="inet6 ${IP}"
                else
                    _ifconfig="inet ${IP}"
                fi
                if [ -n "${bastille_network_gateway}" ]; then
                    _gateway="${bastille_network_gateway}"
                else
            if [ -z ${ip6} ]; then
                _gateway="$(netstat -4rn | awk '/default/ {print $2}')"
            else
                _gateway="$(netstat -6rn | awk '/default/ {print $2}')"
            fi
                fi
            fi
            bastille template "${NAME}" ${bastille_template_vnet} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}" --arg EPAIR="${uniq_epair}" --arg GATEWAY="${_gateway}" --arg IFCONFIG="${_ifconfig}"
        fi
    elif [ -n "${THICK_JAIL}" ]; then
        if [ -n "${bastille_template_thick}" ]; then
            bastille template "${NAME}" ${bastille_template_thick} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    elif [ -n "${EMPTY_JAIL}" ]; then
        if [ -n "${bastille_template_empty}" ]; then
            bastille template "${NAME}" ${bastille_template_empty} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    else # Thin jail.
        if [ -n "${bastille_template_thin}" ]; then
            bastille template "${NAME}" ${bastille_template_thin} --arg BASE_TEMPLATE="${bastille_template_base}" --arg HOST_RESOLV_CONF="${bastille_resolv_conf}"
        fi
    fi

    # Apply values changed by the template. -- cwells
    if [ -z "${EMPTY_JAIL}" ]; then
        bastille restart "${NAME}"
    elif [ -n "${EMPTY_JAIL}" ]; then
        # Don't restart empty jails unless a template defined.
        if [ -n "${bastille_template_empty}" ]; then
            bastille restart "${NAME}"
        fi
    fi
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if echo "$3" | grep '@'; then
    BASTILLE_JAIL_IP=$(echo "$3" | awk -F@ '{print $2}')
    BASTILLE_JAIL_INTERFACES=$( echo "$3" | awk -F@ '{print $1}')
fi

## reset this options
EMPTY_JAIL=""
THICK_JAIL=""
VNET_JAIL=""

# Handle and parse options
while [ $# -gt 0 ]; do
    case "${1}" in
        -E|--empty|empty)
            EMPTY_JAIL="1"
            shift
            ;;
        -T|--thick|thick)
            THICK_JAIL="1"
            shift
            ;;
        -V|--vnet|vnet)
            VNET_JAIL="1"
            shift
            ;;
        -*|--*)
            error_notify "Unknown Option."
            usage
            ;;
       *)
            break
            ;;
    esac
done

## validate for combined options
if [ -n "${EMPTY_JAIL}" ]; then 
    if [ -n "${THICK_JAIL}" ] || [ -n "${VNET_JAIL}" ]; then
        error_exit "Error: Empty jail option can't be used with other options."
    fi
fi

NAME="$1"
RELEASE="$2"
IP="$3"
INTERFACE="$4"

if [ -n "${EMPTY_JAIL}" ]; then
    if [ $# -ne 1 ]; then
        usage
    fi
else
    if [ $# -gt 4 ] || [ $# -lt 3 ]; then
        usage
    fi
fi

## validate jail name
if [ -n "${NAME}" ]; then
    validate_name
fi

if [ -z "${EMPTY_JAIL}" ]; then
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
    *-RELEASE|*-RELEASE-I386|*-RELEASE-i386|*-release|*-RC1|*-rc1|*-RC2|*-rc2|*-BETA1|*-BETA2|*-BETA3|*-BETA4|*-BETA5)
        ## check for FreeBSD releases name
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RELEASE-i386|-RC[1-2]|-BETA[1-5])$' | tr '[:lower:]' '[:upper:]' | sed 's/I/i/g')
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
    *)
        error_notify "Unknown Release."
        usage
        ;;
    esac

    ## check for name/root/.bastille
    if [ -d "${bastille_jailsdir}/${NAME}/root/.bastille" ]; then
        error_exit "Jail: ${NAME} already created. ${NAME}/root/.bastille exists."
    fi

    ## check for required release
    if [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        error_exit "Release must be bootstrapped first; see 'bastille bootstrap'."
    fi

    ## check if ip address is valid
    if [ -n "${IP}" ]; then
        validate_ip
    else
        usage
    fi

    ## check if interface is valid
    if [ -n "${INTERFACE}" ]; then
        validate_netif
        validate_netconf
    elif [ -n "${VNET_JAIL}" ]; then
        if [ -z "${INTERFACE}" ]; then
            if [ -z "${bastille_network_shared}" ]; then
                # User must specify interface on vnet jails.
                error_exit "Error: Network interface not defined."
            else
                validate_netconf
            fi
        fi
    else
        validate_netconf
    fi
else
    info "Creating empty jail: ${NAME}."
fi

## check if a running jail matches name or already exist
if [ -n "${NAME}" ]; then
    running_jail
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
if [ -z ${bastille_template_thick+x} ]; then
    bastille_template_thick='default/thick'
fi
if [ -z ${bastille_template_thin+x} ]; then
    bastille_template_thin='default/thin'
fi
if [ -z ${bastille_template_vnet+x} ]; then
    bastille_template_vnet='default/vnet'
fi

create_jail "${NAME}" "${RELEASE}" "${IP}" "${INTERFACE}"
