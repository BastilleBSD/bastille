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
    echo -e "${COLOR_RED}Usage: bastille bootstrap [release|template].${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

# Validate ZFS parameters first.
if [ "${bastille_zfs_enable}" = "YES" ]; then
    ## check for the ZFS pool and bastille prefix
    if [ -z "${bastille_zfs_zpool}" ]; then
        echo -e "${COLOR_RED}ERROR: Missing ZFS parameters, see bastille_zfs_zpool.${COLOR_RESET}"
        exit 1
	elif [ -z "${bastille_zfs_prefix}" ]; then
        echo -e "${COLOR_RED}ERROR: Missing ZFS parameters, see bastille_zfs_prefix.${COLOR_RESET}"
        exit 1
    elif ! zfs list "${bastille_zfs_zpool}" > /dev/null 2>&1; then
        echo -e "${COLOR_RED}ERROR: ${bastille_zfs_zpool} is not a ZFS pool.${COLOR_RESET}"
        exit 1
    fi

    ## check for the ZFS dataset prefix if already exist
	if [ -d "/${bastille_zfs_zpool}/${bastille_zfs_prefix}" ]; then
        if ! zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}" > /dev/null 2>&1; then
            echo -e "${COLOR_RED}ERROR: ${bastille_zfs_zpool}/${bastille_zfs_prefix} is not a ZFS dataset.${COLOR_RESET}"
            exit 1
        fi
    fi
fi

bootstrap_network_interfaces() {

    ## test for both options empty
    if [ -z ${bastille_jail_loopback} ] && [ -z ${bastille_jail_external} ]; then
        echo -e "${COLOR_RED}Please set preferred loopback or external interface.${COLOR_RESET}"
        echo -e "${COLOR_RED}See bastille.conf.${COLOR_RESET}"
        exit 1
    fi

    ## test for required variables -- external
    if [ -z ${bastille_jail_loopback} ] && [ ! -z ${bastille_jail_external} ]; then

       ## test for existing interface
       ifconfig ${bastille_jail_external} 2>&1 >/dev/null
           if [ $? = 0 ]; then

               ## create ifconfig alias
               ifconfig ${bastille_jail_external} inet ${bastille_jail_addr} alias && \
                   echo -e "${COLOR_GREEN}IP alias added to ${bastille_jail_external} successfully.${COLOR_RESET}"
                   echo

               ## attempt to ping gateway
               echo -e "${COLOR_YELLOW}Attempting to ping default gateway...${COLOR_RESET}"
               ping -c3 -t3 -S ${bastille_jail_addr} ${bastille_jail_gateway}
               if [ $? = 0 ]; then
                   echo
                   echo -e "${COLOR_GREEN}External networking appears functional.${COLOR_RESET}"
                   echo
               else
                   echo -e "${COLOR_RED}Unable to ping default gateway.${COLOR_RESET}"
               fi
           fi
    fi

    ## test for required variables -- loopback
    if [ -z ${bastille_jail_external} ] && [ ! -z ${bastille_jail_loopback} ] && \
       [ ! -z ${bastille_jail_addr} ]; then

       echo -e "${COLOR_GREEN}Detecting...${COLOR_RESET}"
       ## test for existing interface
       ifconfig ${bastille_jail_interface} >&2 >/dev/null

       ## if above return code is 1; create interface
       if [ $? = 1 ]; then
           sysrc ifconfig_${bastille_jail_loopback}_name | grep ${bastille_jail_interface} >&2 >/dev/null
           if [ $? = 1 ]; then
               echo
               echo -e "${COLOR_GREEN}Defining secure loopback interface.${COLOR_RESET}"
               sysrc cloned_interfaces+="${bastille_jail_loopback}" &&
               sysrc ifconfig_${bastille_jail_loopback}_name="${bastille_jail_interface}"
               sysrc ifconfig_${bastille_jail_interface}_aliases+="inet ${bastille_jail_addr}/32"

               ## create and name interface; assign address
               echo
               echo -e "${COLOR_GREEN}Creating secure loopback interface.${COLOR_RESET}"
               ifconfig ${bastille_jail_loopback} create name ${bastille_jail_interface}
               ifconfig ${bastille_jail_interface} up
               ifconfig ${bastille_jail_interface} inet ${bastille_jail_addr}/32

               ## reload firewall
               pfctl -f /etc/pf.conf

               ## look for nat rule for bastille_jail_addr
               echo -e "${COLOR_GREEN}Detecting NAT from bastille0 interface...${COLOR_RESET}"
               pfctl -s nat | grep nat | grep ${bastille_jail_addr}
               if [ $? = 0 ]; then
                   ## test connectivity; ping from bastille_jail_addr
                   echo
                   echo -e "${COLOR_YELLOW}Attempting to ping default gateway...${COLOR_RESET}"
                   ping -c3 -t3 -S ${bastille_jail_addr} ${bastille_jail_gateway}
                   if [ $? = 0 ]; then
                       echo
                       echo -e "${COLOR_GREEN}Private networking appears functional.${COLOR_RESET}"
                       echo
                   else
                       echo -e "${COLOR_RED}Unable to ping default gateway.${COLOR_RESET}"
                       echo -e "${COLOR_YELLOW}See https://github.com/BastilleBSD/bastille/blob/master/README.md#etcpfconf.${COLOR_RESET}"
                       echo -e
                   fi
               else
                   echo -e "${COLOR_RED}Unable to detect firewall 'nat' rule.${COLOR_RESET}"
                   echo -e "${COLOR_YELLOW}See https://github.com/BastilleBSD/bastille/blob/master/README.md#etcpfconf.${COLOR_RESET}"
               fi
           else
               echo -e "${COLOR_RED}Interface ${bastille_jail_loopback} already configured; bailing out.${COLOR_RESET}"
           fi
       else
           echo -e "${COLOR_RED}Interface ${bastille_jail_interface} already active; bailing out.${COLOR_RESET}"
       fi
    fi
}

bootstrap_directories() {
    ## ensure required directories are in place

    ## ${bastille_prefix}
    if [ ! -d "${bastille_prefix}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ];then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_prefix} ${bastille_zfs_zpool}/${bastille_zfs_prefix}
            fi
        else
            mkdir -p "${bastille_prefix}"
            chmod 0750 "${bastille_prefix}"
        fi
    fi

    ## ${bastille_cachedir}
    if [ ! -d "${bastille_cachedir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_cachedir} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_cachedir}/${RELEASE} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}
            fi
        else
            mkdir -p "${bastille_cachedir}/${RELEASE}"
        fi
    ## create subsequent cache/XX.X-RELEASE datasets
    elif [ ! -d "${bastille_cachedir}/${RELEASE}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_cachedir}/${RELEASE} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}
            fi
        else
            mkdir -p "${bastille_cachedir}/${RELEASE}"
        fi
    fi

    ## ${bastille_jailsdir}
    if [ ! -d "${bastille_jailsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_jailsdir} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails
            fi
        else
            mkdir -p "${bastille_jailsdir}"
        fi
    fi

    ## ${bastille_logsdir}
    if [ ! -d "${bastille_logsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_logsdir} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/logs
            fi
        else
            mkdir -p "${bastille_logsdir}"
        fi
    fi

    ## ${bastille_templatesdir}
    if [ ! -d "${bastille_templatesdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_templatesdir} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/templates
            fi
        else
            mkdir -p "${bastille_templatesdir}"
        fi
    fi

    ## ${bastille_releasesdir}
    if [ ! -d "${bastille_releasesdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_releasesdir} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_releasesdir}/${RELEASE} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}
            fi
        else
            mkdir -p "${bastille_releasesdir}/${RELEASE}"
        fi
    ## create subsequent releases/XX.X-RELEASE datasets
    elif [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ ! -z "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint=${bastille_releasesdir}/${RELEASE} ${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}
            fi
       else
           mkdir -p "${bastille_releasesdir}/${RELEASE}"
       fi
    fi
}

bootstrap_release() {
    ## if release exists, quit
    if [ -f "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" ]; then
        echo -e "${COLOR_RED}Bootstrap appears complete.${COLOR_RESET}"
        exit 1
    fi

    for _archive in ${bastille_bootstrap_archives}; do
        ## check if the dist files already exists then extract
        if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
            echo -e "${COLOR_GREEN}Extracting FreeBSD ${RELEASE} ${_archive}.txz.${COLOR_RESET}"
            /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"
        else
                ## get the manifest for dist files checksum validation
                if [ ! -f "${bastille_cachedir}/${RELEASE}/MANIFEST" ]; then
                    fetch ${UPSTREAM_URL}/MANIFEST -o ${bastille_cachedir}/${RELEASE}/MANIFEST
                fi

                ## fetch for missing dist files
                if [ ! -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    fetch ${UPSTREAM_URL}/${_archive}.txz -o ${bastille_cachedir}/${RELEASE}/${_archive}.txz
                fi

                ## compare checksums on the fetched dist files
                if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    SHA256_DIST=$(grep -w "${_archive}.txz" ${bastille_cachedir}/${RELEASE}/MANIFEST | awk '{print $2}')
                    SHA256_FILE=$(sha256 -q ${bastille_cachedir}/${RELEASE}/${_archive}.txz)
                    if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
                        echo -e "${COLOR_RED}Failed validation for ${_archive}.txz, please retry bootstrap!${COLOR_RESET}"
                        rm ${bastille_cachedir}/${RELEASE}/${_archive}.txz
                        exit 1
                    fi
                fi

                ## extract the fetched dist files
                if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    echo -e "${COLOR_GREEN}Extracting FreeBSD ${RELEASE} ${_archive}.txz.${COLOR_RESET}"
                    /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"
                fi
        fi
    done
    echo

    echo -e "${COLOR_GREEN}Bootstrap successful.${COLOR_RESET}"
    echo -e "${COLOR_GREEN}See 'bastille --help' for available commands.${COLOR_RESET}"
    echo
}

bootstrap_template() {
    ## define basic variables
    _url=${BASTILLE_TEMPLATE_URL}
    _user=${BASTILLE_TEMPLATE_USER}
    _repo=${BASTILLE_TEMPLATE_REPO}
    _template=${bastille_templatesdir}/${_user}/${_repo}

    ## support for non-git
    if [ ! -x /usr/local/bin/git ]; then
        echo -e "${COLOR_RED}We're gonna have to use fetch. Strap in.${COLOR_RESET}"
        echo -e "${COLOR_RED}Not yet implemented...${COLOR_RESET}"
        exit 1
    fi

    ## support for git
    if [ -x /usr/local/bin/git ]; then
        if [ ! -d "${_template}/.git" ]; then
            /usr/local/bin/git clone "${_url}" "${_template}" ||\
                echo -e "${COLOR_RED}Clone unsuccessful.${COLOR_RESET}"
                echo
        elif [ -d "${_template}/.git" ]; then
            cd ${_template} &&
            /usr/local/bin/git pull ||\
                echo -e "${COLOR_RED}Template update unsuccessful.${COLOR_RESET}"
                echo
        fi
    fi

    ## template validation
    _hook_validate=0
    for _hook in PRE FSTAB PF PKG SYSRC CMD; do
        if [ -s ${_template}/${_hook} ]; then
            _hook_validate=$((_hook_validate+1))
            echo -e "${COLOR_GREEN}Detected ${_hook} hook.${COLOR_RESET}"
            echo -e "${COLOR_GREEN}[${_hook}]:${COLOR_RESET}"
            cat "${_template}/${_hook}"
            echo
        fi
    done

    # template overlay
    if [ -s ${_template}/OVERLAY ]; then
        _hook_validate=$((_hook_validate+1))
        echo -e "${COLOR_GREEN}Detected OVERLAY hook.${COLOR_RESET}"
        while read _dir; do
            echo -e "${COLOR_GREEN}[${_dir}]:${COLOR_RESET}"
            tree -a ${_template}/${_dir}
        done < ${_template}/OVERLAY
        echo
    fi
    if [ -s ${_template}/CONFIG ]; then
        echo -e "${COLOR_GREEN}Detected CONFIG hook.${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}CONFIG deprecated; rename to OVERLAY.${COLOR_RESET}"
        while read _dir; do
            echo -e "${COLOR_GREEN}[${_dir}]:${COLOR_RESET}"
            tree -a ${_template}/${_dir}
        done < ${_template}/CONFIG
    fi

    ## remove bad templates
    if [ ${_hook_validate} -lt 1 ]; then
        echo -e "${COLOR_GREEN}Template validation failed.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}Deleting template.${COLOR_RESET}"
        rm -rf ${_template}
        exit 1
    fi

    ## if validated; ready to use 
    if [ ${_hook_validate} -gt 0 ]; then
        echo -e "${COLOR_GREEN}Template ready to use.${COLOR_RESET}"
        echo
    fi
}

HW_MACHINE=$(sysctl hw.machine | awk '{ print $2 }')
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

# Filter sane release names
case "${1}" in
11.2-RELEASE)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/11.2-RELEASE"
    bootstrap_directories
    bootstrap_release
    ;;
11.3-RELEASE)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/11.3-RELEASE"
    bootstrap_directories
    bootstrap_release
    ;;
12.0-RELEASE)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/12.0-RELEASE"
    bootstrap_directories
    bootstrap_release
    ;;
12.1-RC1)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/12.1-RC1"
    bootstrap_directories
    bootstrap_release
    ;;
12.1-RC2)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/12.1-RC2"
    bootstrap_directories
    bootstrap_release
    ;;
12.1-RELEASE)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/12.1-RELEASE"
    bootstrap_directories
    bootstrap_release
    ;;
11-stable-LAST)
    RELEASE="${1}"
    UPSTREAM_URL="https://installer.hardenedbsd.org/pub/HardenedBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/hardenedbsd-11-stable-LAST"
    bootstrap_directories
    bootstrap_release
    ;;
12-stable-LAST)
    RELEASE="${1}"
    UPSTREAM_URL="https://installer.hardenedbsd.org/pub/HardenedBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/hardenedbsd-12-stable-LAST"
    bootstrap_directories
    bootstrap_release
    ;;
http?://github.com/*/*|http?://gitlab.com/*/*)
    BASTILLE_TEMPLATE_URL=${1}
    BASTILLE_TEMPLATE_USER=$(echo "${1}" | awk -F / '{ print $4 }')
    BASTILLE_TEMPLATE_REPO=$(echo "${1}" | awk -F / '{ print $5 }')
    echo -e "${COLOR_GREEN}Template: ${1}${COLOR_RESET}"
    echo
    bootstrap_directories
    bootstrap_template
    ;;
network)
    bootstrap_network_interfaces
    ;;
*)
    usage
    ;;
esac
