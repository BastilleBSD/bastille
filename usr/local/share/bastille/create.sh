#!/bin/sh
# 
# Copyright (c) 2018-2019, Christer Edwards <christer.edwards@gmail.com>
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
    echo -e "${COLOR_RED}Usage: bastille create [option] name release ip | interface.${COLOR_RESET}"
    exit 1
}

running_jail() {
    jls name | grep -w "${NAME}"
}

validate_ip() {
    local IFS
    ip=${IP}
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
      IFS=.
      set $ip
      for quad in 1 2 3 4; do
        if eval [ \$$quad -gt 255 ]; then
          echo "fail ($ip)"
          exit 1
        fi
      done
      echo -e "${COLOR_GREEN}Valid: ($ip).${COLOR_RESET}"
    else
      echo -e "${COLOR_RED}Invalid: ($ip).${COLOR_RESET}"
      exit 1
    fi
}

validate_netif() {
    local LIST_INTERFACES=$(ifconfig -l)
    interface=${INTERFACE}
    if echo "${LIST_INTERFACES}" | grep -qwo "${INTERFACE}"; then
        echo -e "${COLOR_GREEN}Valid: ($interface).${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}Invalid: ($interface).${COLOR_RESET}"
        exit 1
    fi
}

validate_netconf() {
    if [ ! -z "${bastille_jail_external}" ]; then
        break
    elif [ ! -z ${bastille_jail_loopback} ] && [ -z ${bastille_jail_external} ]; then
        if [ -z "${bastille_jail_interface}" ]; then
            echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
            exit 1
        fi
    elif [ -z ${bastille_jail_loopback} ] && [ ! -z ${bastille_jail_interface} ]; then
        echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
        exit 1
    elif [ -z ${bastille_jail_external} ]; then
        echo -e "${COLOR_RED}Invalid network configuration.${COLOR_RESET}"
        exit 1
    fi
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
                ## create required zfs datasets
                zfs create ${bastille_zfs_options} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}
                if [ -z "${THICK_JAIL}" ]; then
                    zfs create ${bastille_zfs_options} -o mountpoint=${bastille_jailsdir}/${NAME}/root ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${NAME}/root
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
        if [ -z ${bastille_jail_loopback} ] && [ ! -z ${bastille_jail_external} ]; then
            local bastille_jail_conf_interface=${bastille_jail_external}
        fi
        if [ ! -z ${bastille_jail_loopback} ] && [ -z ${bastille_jail_external} ]; then
            local bastille_jail_conf_interface=${bastille_jail_interface}
        fi
        if [ ! -z  ${INTERFACE} ]; then
            local bastille_jail_conf_interface=${INTERFACE}
        fi

        ## generate the jail configuration file 
        cat << EOF > ${bastille_jail_conf}
interface = ${bastille_jail_conf_interface};
host.hostname = ${NAME};
exec.consolelog = ${bastille_jail_log};
path = ${bastille_jail_path};
ip6 = disable;
securelevel = 2;
devfs_ruleset = 4;
enforce_statfs = 2;
exec.start = '/bin/sh /etc/rc';
exec.stop = '/bin/sh /etc/rc.shutdown';
exec.clean;
mount.devfs;
mount.fstab = ${bastille_jail_fstab};

${NAME} {
	ip4.addr = ${IP};
}
EOF
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
        echo
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
    THICK_JAIL="0"
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
if [ -n "${NAME_VERIFY}" ]; then
    RELEASE="${NAME_VERIFY}"
else
    usage
fi
    ;;
*-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
## check for HardenedBSD releases name
NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})(-stable-LAST|-STABLE-last|-stable-last|-STABLE-LAST)$' | sed 's/STABLE/stable/g' | sed 's/last/LAST/g')
if [ -n "${NAME_VERIFY}" ]; then
    RELEASE="${NAME_VERIFY}"
else
    usage
fi
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

## check if a running jail matches name
if running_jail ${NAME}; then
    echo -e "${COLOR_RED}A running jail matches name.${COLOR_RESET}"
    echo -e "${COLOR_RED}Jails must be stopped before they are destroyed.${COLOR_RESET}"
    exit 1
fi

## check if ip address is valid
if [ ! -z ${IP} ]; then
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
