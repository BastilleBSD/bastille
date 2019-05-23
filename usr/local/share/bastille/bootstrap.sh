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

bootstrap_release() {
    ## ensure required directories are in place
    if [ ! -d ${bastille_jailsdir} ]; then
        mkdir -p ${bastille_jailsdir}
    fi
    if [ ! -d ${bastille_logsdir} ]; then
        mkdir -p ${bastille_logsdir}
    fi
    if [ ! -d ${bastille_templatesdir} ]; then
        mkdir -p ${bastille_templatesdir}
    fi
    if [ ! -d "${bastille_cachedir}/${RELEASE}" ]; then
        mkdir -p "${bastille_cachedir}/${RELEASE}"
    fi

    ## if release exists, quit
    if [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
        echo -e "${COLOR_RED}Bootstrap appears complete.${COLOR_RESET}"
        exit 1
    fi

    ## if existing ${CACHEDIR}/${RELEASE}/base.txz; extract
    if [ -f "${bastille_cachedir}/${RELEASE}/base.txz" ] && [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        mkdir -p "${bastille_releasesdir}/${RELEASE}"
        for _archive in ${bastille_bootstrap_archives}; do
            echo -e "${COLOR_GREEN}Extracting FreeBSD ${RELEASE} ${_archive}.txz.${COLOR_RESET}"
            /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"
        done

        echo -e "${COLOR_GREEN}Bootstrap successful.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}See 'bastille --help' for available commands.${COLOR_RESET}"
        echo
    fi

    ## if no existing ${CACHEDIR}/${RELEASE} download and extract
    if [ ! -f "${bastille_cachedir}/${RELEASE}/base.txz" ] && [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        mkdir -p "${bastille_releasesdir}/${RELEASE}"
	fetch ${UPSTREAM_URL}/base.txz -o ${bastille_cachedir}/${RELEASE}/base.txz

        echo
        for _archive in ${bastille_bootstrap_archives}; do
            echo -e "${COLOR_GREEN}Extracting FreeBSD ${RELEASE} ${_archive}.txz.${COLOR_RESET}"
            /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"
        done

        echo -e "${COLOR_GREEN}Bootstrap successful.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}See 'bastille --help' for available commands.${COLOR_RESET}"
        echo
    fi
}

bootstrap_template() {
    ## define basic variables
    _url=${BASTILLE_TEMPLATE_URL}
    _user=${BASTILLE_TEMPLATE_USER}
    _repo=${BASTILLE_TEMPLATE_REPO}
    _template=${bastille_templatesdir}/${_user}/${_repo}

    ## verify essential directories are in place
    if [ ! -d ${bastille_jailsdir} ]; then
        mkdir -p ${bastille_jailsdir}
    fi
    if [ ! -d ${bastille_logsdir} ]; then
        mkdir -p ${bastille_logsdir}
    fi
    if [ ! -d ${bastille_templatesdir} ]; then
        mkdir -p ${bastille_templatesdir}
    fi
    if [ ! -d ${_template} ]; then
        mkdir -p ${_template}
    fi

    ## support for non-git
    if [ ! -x /usr/local/bin/git ]; then
	echo -e "${COLOR_RED}We're gonna have to use fetch. Strap in.${COLOR_RESET}"
	echo -e "${COLOR_RED}Not yet implemented...${COLOR_RESET}"
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
    if [ -s ${_template}/CONFIG ]; then
        _hook_validate=$((_hook_validate+1))
        echo -e "${COLOR_GREEN}Detected CONFIG hook.${COLOR_RESET}"
        while read _dir; do
            echo -e "${COLOR_GREEN}[${_dir}]:${COLOR_RESET}"
            tree -a ${_template}/${_dir}
        done < ${_template}/CONFIG
        echo
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

#Usage: bastille bootstrap [release|template].${COLOR_RESET}"

HW_MACHINE=$(sysctl hw.machine | awk '{ print $2 }')
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

# Filter sane release names
case "${1}" in
11.2-RELEASE)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/11.2-RELEASE/"
    bootstrap_release
    ;;
12.0-RELEASE)
    RELEASE="${1}"
    UPSTREAM_URL="http://ftp.freebsd.org/pub/FreeBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/12.0-RELEASE/"
    bootstrap_release
    ;;
11-stable-LAST)
    RELEASE="${1}"
    UPSTREAM_URL="https://installer.hardenedbsd.org/pub/HardenedBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/hardenedbsd-11-stable-LAST/"
    bootstrap_release
    ;;
12-stable-LAST)
    RELEASE="${1}"
    UPSTREAM_URL="https://installer.hardenedbsd.org/pub/HardenedBSD/releases/${HW_MACHINE}/${HW_MACHINE_ARCH}/hardenedbsd-12-stable-LAST/"
    bootstrap_release
    ;;
http?://github.com/*/*)
    BASTILLE_TEMPLATE_URL=${1}
    BASTILLE_TEMPLATE_USER=$(echo "${1}" | awk -F / '{ print $4 }')
    BASTILLE_TEMPLATE_REPO=$(echo "${1}" | awk -F / '{ print $5 }')
    echo -e "${COLOR_GREEN}Template: ${1}${COLOR_RESET}"
    echo
    bootstrap_template
    ;;
*)
    usage
    ;;
esac
