#!/bin/sh
# 
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille create [option] name release ip [interface].${COLOR_RESET}"
    exit 1
}

running_jail() {
    if [ -n "$(jls name | awk "/^${NAME}$/")" ]; then
        echo -e "${COLOR_RED}A running jail matches name.${COLOR_RESET}"
        exit 1
    elif [ -d "${bastille_jailsdir}/${NAME}" ]; then
        echo -e "${COLOR_RED}Jail: ${NAME} already created.${COLOR_RESET}"
        exit 1
    fi
}

validate_ip() {
    IPX_ADDR="ip4.addr"
    IP6_MODE="disable"
    ip6=$(echo "${IP}" | grep -E '^(([a-fA-F0-9:]+$)|([a-fA-F0-9:]+\/[0-9]{1,3}$))')
    if [ -n "${ip6}" ]; then
        echo -e "${COLOR_GREEN}Valid: (${ip6}).${COLOR_RESET}"
        IPX_ADDR="ip6.addr"
        IP6_MODE="new"
    else
        local IFS
        if echo "${IP}" | grep -E '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))?$' >/dev/null; then
            TEST_IP=$(echo ${IP} | cut -d / -f1)
            IFS=.
            set ${TEST_IP}
            for quad in 1 2 3 4; do
                if eval [ \$$quad -gt 255 ]; then
                    echo "fail (${TEST_IP})"
                    exit 1
                fi
            done
            if ifconfig | grep -w "$TEST_IP" >/dev/null; then
                echo -e "${COLOR_YELLOW}Warning: ip address already in use (${TEST_IP}).${COLOR_RESET}"
            else
                echo -e "${COLOR_GREEN}Valid: (${IP}).${COLOR_RESET}"
            fi
        else
            echo -e "${COLOR_RED}Invalid: (${IP}).${COLOR_RESET}"
            exit 1
        fi
    fi
}

validate_netif() {
    local LIST_INTERFACES=$(ifconfig -l)
    if echo "${LIST_INTERFACES} VNET" | grep -qwo "${INTERFACE}"; then
        echo -e "${COLOR_GREEN}Valid: (${INTERFACE}).${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}Invalid: (${INTERFACE}).${COLOR_RESET}"
        exit 1
    fi
}

validate_netconf() {
    if [ -n "${bastille_jail_loopback}" ] && [ -n "${bastille_jail_interface}" ] && [ -n "${bastille_jail_external}" ]; then
        echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
        exit 1
    fi
    if [ ! -z "${bastille_jail_external}" ]; then
        break
    elif [ ! -z "${bastille_jail_loopback}" ] && [ -z "${bastille_jail_external}" ]; then
        if [ -z "${bastille_jail_interface}" ]; then
            echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
            exit 1
        fi
    elif [ -z "${bastille_jail_loopback}" ] && [ ! -z "${bastille_jail_interface}" ]; then
        echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
        exit 1
    elif [ -z "${bastille_jail_external}" ]; then
        echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
        exit 1
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

generate_jail_conf() {
    cat << EOF > ${bastille_jail_conf}
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
  ip6 = disable;
}
EOF
}

generate_vnet_jail_conf() {
    ## determine number of containers + 1
    ## iterate num and grep all jail configs
    ## define uniq_epair
    local list_jails_num=$(bastille list jails | wc -l | awk '{print $1}')
    local num_range=$(expr "${list_jails_num}" + 1)
    for _num in $(seq 0 "${num_range}"); do
        if ! grep "e0b_bastille${_num}" "${bastille_jailsdir}"/*/jail.conf >/dev/null; then
            uniq_epair="bastille${_num}"
	    break
        fi
    done

    ## generate config
    cat << EOF > ${bastille_jail_conf}
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
  exec.prestart += "jib addm ${uniq_epair} ${INTERFACE}";
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
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                ## create required zfs datasets, mountpoint inherited from system
                zfs create ${bastille_zfs_options} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}
                if [ -z "${THICK_JAIL}" ]; then
                    zfs create ${bastille_zfs_options} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root
                fi
            fi
        else
            mkdir -p "${bastille_jailsdir}/${NAME}"
        fi
    fi

    if [ ! -d "${bastille_jail_base}" ]; then
        mkdir -p "${bastille_jail_base}"
    fi

    if [ ! -d "${bastille_jail_path}/usr/home" ]; then
        mkdir -p "${bastille_jail_path}/usr/home"
    fi

    if [ ! -d "${bastille_jail_path}/usr/local" ]; then
        mkdir -p "${bastille_jail_path}/usr/local"
    fi

    if [ ! -d "${bastille_jail_template}" ]; then
        mkdir -p "${bastille_jail_template}"
    fi

    if [ ! -f "${bastille_jail_fstab}" ]; then
        if [ -z "${THICK_JAIL}" ]; then
            echo -e "${bastille_releasesdir}/${RELEASE} ${bastille_jail_base} nullfs ro 0 0" > ${bastille_jail_fstab}
        else
            touch ${bastille_jail_fstab}
        fi
    fi

    if [ ! -f "${bastille_jail_conf}" ]; then
        if [ -z "${bastille_jail_loopback}" ] && [ ! -z "${bastille_jail_external}" ]; then
            local bastille_jail_conf_interface=${bastille_jail_external}
        fi
        if [ ! -z "${bastille_jail_loopback}" ] && [ -z "${bastille_jail_external}" ]; then
            local bastille_jail_conf_interface=${bastille_jail_interface}
        fi
        if [ ! -z  ${INTERFACE} ]; then
            local bastille_jail_conf_interface=${INTERFACE}
        fi

        ## generate the jail configuration file 
        if [ -n ${VNET_JAIL} ]; then
            generate_vnet_jail_conf
        else
            generate_jail_conf
        fi
    fi

    ## using relative paths here
    ## MAKE SURE WE'RE IN THE RIGHT PLACE
    cd "${bastille_jail_path}"
    echo
    echo -e "${COLOR_GREEN}NAME: ${NAME}.${COLOR_RESET}"
    echo -e "${COLOR_GREEN}IP: ${IP}.${COLOR_RESET}"
    if [ ! -z  ${INTERFACE} ]; then
        echo -e "${COLOR_GREEN}INTERFACE: ${INTERFACE}.${COLOR_RESET}"
    fi
    echo -e "${COLOR_GREEN}RELEASE: ${RELEASE}.${COLOR_RESET}"
    echo

    if [ -z "${THICK_JAIL}" ]; then
        for _link in bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/sbin usr/share usr/src; do
            ln -sf /.bastille/${_link} ${_link}
        done
    fi

    ## link home properly
    ln -s usr/home home

    if [ -z "${THICK_JAIL}" ]; then
        ## rw
        ## copy only required files for thin jails
        FILE_LIST=".cshrc .profile COPYRIGHT dev etc media mnt net proc root tmp var usr/obj usr/tests"
        for files in ${FILE_LIST}; do
            if [ -f "${bastille_releasesdir}/${RELEASE}/${files}" ] || [ -d "${bastille_releasesdir}/${RELEASE}/${files}" ]; then
                cp -a "${bastille_releasesdir}/${RELEASE}/${files}" "${bastille_jail_path}/${files}"
                if [ $? -ne 0 ]; then
                    ## notify and clean stale files/directories
                    echo -e "${COLOR_RED}Failed to copy release files, please retry create!${COLOR_RESET}"
                    bastille destroy ${NAME}
                    exit 1
                fi
            fi
        done
    else
        echo -e "${COLOR_GREEN}Creating a thickjail, this may take a while...${COLOR_RESET}"
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                ## perform release base replication

                ## sane bastille zfs options 
                ZFS_OPTIONS=$(echo ${bastille_zfs_options} | sed 's/-o//g')

                ## take a temp snapshot of the base release
                SNAP_NAME="bastille-$(date +%Y-%m-%d-%H%M%S)"
                zfs snapshot ${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}@${SNAP_NAME}

                ## replicate the release base to the new thickjail and set the default mountpoint
                zfs send -R ${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}@${SNAP_NAME} | \
                zfs receive ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root
                zfs set ${ZFS_OPTIONS} mountpoint=${bastille_jailsdir}/${NAME}/root ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root

                ## cleanup temp snapshots initially
                zfs destroy ${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}@${SNAP_NAME}
                zfs destroy ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root@${SNAP_NAME}

                if [ $? -ne 0 ]; then
                    ## notify and clean stale files/directories
                    echo -e "${COLOR_RED}Failed release base replication, please retry create!${COLOR_RESET}"
                    bastille destroy ${NAME}
                    exit 1
                fi
            fi
        else
            ## copy all files for thick jails
            cp -a "${bastille_releasesdir}/${RELEASE}/" "${bastille_jail_path}"
            if [ $? -ne 0 ]; then
                ## notify and clean stale files/directories
                echo -e "${COLOR_RED}Failed to copy release files, please retry create!${COLOR_RESET}"
                bastille destroy ${NAME}
                exit 1
            fi
        fi
    fi

    ## rc.conf
    ##  + syslogd_flags="-ss"
    ##  + sendmail_none="NONE"
    ##  + cron_flags="-J 60" ## cedwards 20181118
    if [ ! -f "${bastille_jail_rc_conf}" ]; then
        touch "${bastille_jail_rc_conf}"
        /usr/sbin/sysrc -f "${bastille_jail_rc_conf}" syslogd_flags=-ss
        /usr/sbin/sysrc -f "${bastille_jail_rc_conf}" sendmail_enable=NONE
        /usr/sbin/sysrc -f "${bastille_jail_rc_conf}" cron_flags='-J 60'

	## VNET specific
        if [ -n "${VNET_JAIL}" ]; then
            ## rename interface to generic vnet0
            uniq_epair=$(grep vnet.interface ${bastille_jailsdir}/${NAME}/jail.conf | awk '{print $3}' | sed 's/;//')
            /usr/sbin/sysrc -f "${bastille_jail_rc_conf}" "ifconfig_${uniq_epair}_name"=vnet0

	    ## if 0.0.0.0 set DHCP
	    ## else set static address
            if [ "${IP}" == "0.0.0.0" ]; then
                /usr/sbin/sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="DHCP"
            else
                /usr/sbin/sysrc -f "${bastille_jail_rc_conf}" ifconfig_vnet0="inet ${IP}"
            fi

	    ## VNET requires jib script
	    if [ ! $(command -v jib) ]; then
	        if [ -f /usr/share/examples/jails/jib ] && [ ! -f /usr/local/bin/jib ]; then
                    install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib
	        fi
	    fi
        fi
    fi

    ## resolv.conf (default: copy from host)
    if [ ! -f "${bastille_jail_resolv_conf}" ]; then
        cp -L ${bastille_resolv_conf} ${bastille_jail_resolv_conf}
    fi

    ## TZ: configurable (default: etc/UTC)
    ln -s /usr/share/zoneinfo/${bastille_tzdata} etc/localtime
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $(echo $3 | grep '@' ) ]; then
    BASTILLE_JAIL_IP=$(echo $3 | awk -F@ '{print $2}')
    BASTILLE_JAIL_INTERFACES=$( echo $3 | awk -F@ '{print $1}')
fi

TYPE="$1"
NAME="$2"
RELEASE="$3"
IP="$4"
INTERFACE="$5"

## handle additional options
case "${TYPE}" in
-T|--thick|thick)
    if [ $# -gt 5 ] || [ $# -lt 4 ]; then
        usage
    fi
    THICK_JAIL="1"
    break
    ;;
-V|--vnet|vnet)
    if [ $# -gt 5 ] || [ $# -lt 4 ]; then
        usage
    fi
    VNET_JAIL="1"
    break
    ;;
-*)
    echo -e "${COLOR_RED}Unknown Option.${COLOR_RESET}"
    usage
    ;;
*)
    if [ $# -gt 4 ] || [ $# -lt 3 ]; then
        usage
    fi
    THICK_JAIL=""
    NAME="$1"
    RELEASE="$2"
    IP="$3"
    INTERFACE="$4"
    ;;
esac

## don't allow for dots(.) in container names
if [ $(echo "${NAME}" | grep "[.]") ]; then
    echo -e "${COLOR_RED}Container names may not contain a dot(.)!${COLOR_RESET}"
    exit 1
fi

## verify release
case "${RELEASE}" in
*-RELEASE|*-release|*-RC1|*-rc1|*-RC2|*-rc2)
    ## check for FreeBSD releases name
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-2])$' | tr '[:lower:]' '[:upper:]')
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
    echo -e "${COLOR_RED}Unknown Release.${COLOR_RESET}"
    usage
    ;;
esac

## check for name/root/.bastille
if [ -d "${bastille_jailsdir}/${NAME}/root/.bastille" ]; then
    echo -e "${COLOR_RED}Jail: ${NAME} already created. ${NAME}/root/.bastille exists.${COLOR_RESET}"
    exit 1
fi

## check for required release
if [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
    echo -e "${COLOR_RED}Release must be bootstrapped first; see `bastille bootstrap`.${COLOR_RESET}"
    exit 1
fi

## check if a running jail matches name or already exist
if [ -n "${NAME}" ]; then
    running_jail
fi

## check if ip address is valid
if [ ! -z "${IP}" ]; then
    validate_ip
else
    usage
fi

## check if interface is valid
if [ ! -z  ${INTERFACE} ]; then
    validate_netif
else
    validate_netconf
fi

create_jail ${NAME} ${RELEASE} ${IP} ${INTERFACE}
