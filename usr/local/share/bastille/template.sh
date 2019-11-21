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
    echo -e "${COLOR_RED}Usage: bastille template [ALL|glob] template.${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 2 ] || [ $# -lt 2 ]; then
    usage
fi

if [ "$1" = 'ALL' ]; then
    JAILS=$(jls name)
fi
if [ "$1" != 'ALL' ]; then
    JAILS=$(jls name | grep -E "(^|\b)${1}($|\b)")
fi

## global variables
TEMPLATE=$2
bastille_template=${bastille_templatesdir}/${TEMPLATE}
bastille_template_TARGET=${bastille_template}/TARGET
bastille_template_INCLUDE=${bastille_template}/INCLUDE
bastille_template_PRE=${bastille_template}/PRE
bastille_template_OVERLAY=${bastille_template}/OVERLAY
bastille_template_FSTAB=${bastille_template}/FSTAB
bastille_template_PF=${bastille_template}/PF
bastille_template_PKG=${bastille_template}/PKG
bastille_template_SYSRC=${bastille_template}/SYSRC
bastille_template_SERVICE=${bastille_template}/SERVICE
bastille_template_CMD=${bastille_template}/CMD

for _jail in ${JAILS}; do
    ## jail-specific variables. 
    bastille_jail_path=$(jls -j "${_jail}" path)

    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"

    ## TARGET
    if [ -s "${bastille_template_TARGET}" ]; then
        if [ $(grep -E "(^|\b)\!${_jail}($|\b)" ${bastille_template_TARGET}) ]; then
            echo -e "${COLOR_GREEN}TARGET: !${_jail}.${COLOR_RESET}"
	    echo
            continue
        fi
	if [ ! $(grep -E "(^|\b)(${_jail}|ALL)($|\b)" ${bastille_template_TARGET}) ]; then
            echo -e "${COLOR_GREEN}TARGET: ?${_jail}.${COLOR_RESET}"
	    echo
            continue
        fi
    fi

    ## INCLUDE
    if [ -s "${bastille_template_INCLUDE}" ]; then
        echo -e "${COLOR_GREEN}Detected INCLUDE.${COLOR_RESET}"
        while read _include; do
            echo
            echo -e "${COLOR_GREEN}INCLUDE: ${_include}${COLOR_RESET}"
            echo -e "${COLOR_GREEN}Bootstrapping ${_include}...${COLOR_RESET}"
            bastille bootstrap ${_include}

            echo
            echo -e "${COLOR_GREEN}Applying ${_include}...${COLOR_RESET}"
            BASTILLE_TEMPLATE_PROJECT=$(echo "${_include}" | awk -F / '{ print $4}')
            BASTILLE_TEMPLATE_REPO=$(echo "${_include}" | awk -F / '{ print $5}')
            bastille template ${_jail} ${BASTILLE_TEMPLATE_PROJECT}/${BASTILLE_TEMPLATE_REPO}
        done < "${bastille_template_INCLUDE}"
    fi

    ## PRE
    if [ -s "${bastille_template_PRE}" ]; then
        echo -e "${COLOR_GREEN}Executing PRE-command(s).${COLOR_RESET}"
        jexec -l ${_jail} /bin/sh < "${bastille_template_PRE}" || exit 1
    fi

    ## CONFIG / OVERLAY
    if [ -s "${bastille_template_OVERLAY}" ]; then
        echo -e "${COLOR_GREEN}Copying files...${COLOR_RESET}"
        while read _dir; do
            cp -a "${bastille_template}/${_dir}" "${bastille_jail_path}" || exit 1
        done < ${bastille_template_OVERLAY}
        echo -e "${COLOR_GREEN}Copy complete.${COLOR_RESET}"
    fi
    if [ -s "${bastille_template}/CONFIG" ]; then
        echo -e "${COLOR_YELLOW}CONFIG deprecated; rename to OVERLAY.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}Copying files...${COLOR_RESET}"
        while read _dir; do
            cp -a "${bastille_template}/${_dir}" "${bastille_jail_path}" || exit 1
        done < ${bastille_template}/CONFIG
        echo -e "${COLOR_GREEN}Copy complete.${COLOR_RESET}"
    fi

    ## FSTAB
    if [ -s "${bastille_template_FSTAB}" ]; then
        bastille_templatefstab=$(cat "${bastille_template_FSTAB}")
        echo -e "${COLOR_GREEN}Updating fstab.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}NOT YET IMPLEMENTED.${COLOR_RESET}"
    fi

    ## PF
    if [ -s "${bastille_template_PF}" ]; then
        bastille_templatepf=$(cat "${bastille_template_PF}")
        echo -e "${COLOR_GREEN}Generating PF profile.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}NOT YET IMPLEMENTED.${COLOR_RESET}"
    fi

    ## PKG (bootstrap + pkg)
    if [ -s "${bastille_template_PKG}" ]; then
        echo -e "${COLOR_GREEN}Installing packages.${COLOR_RESET}"
        jexec -l "${_jail}" env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg bootstrap || exit 1
        jexec -l "${_jail}" env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg audit -F || exit 1
        jexec -l "${_jail}" env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install $(cat ${bastille_template_PKG}) || exit 1
    fi

    ## SYSRC
    if [ -s "${bastille_template_SYSRC}" ]; then
        echo -e "${COLOR_GREEN}Updating services.${COLOR_RESET}"
        while read _sysrc; do
            jexec -l ${_jail} /usr/sbin/sysrc "${_sysrc}" || exit 1
        done < "${bastille_template_SYSRC}"
    fi

    ## SERVICE
    if [ -s "${bastille_template_SERVICE}" ]; then
        echo -e "${COLOR_GREEN}Managing services.${COLOR_RESET}"
        while read _service; do
            jexec -l ${_jail} /usr/sbin/service ${_service} || exit 1
        done < "${bastille_template_SERVICE}"
    fi

    ## CMD
    if [ -s "${bastille_template_CMD}" ]; then
        echo -e "${COLOR_GREEN}Executing final command(s).${COLOR_RESET}"
        jexec -l ${_jail} /bin/sh < "${bastille_template_CMD}" || exit 1
    fi
    echo -e "${COLOR_GREEN}Template Complete.${COLOR_RESET}"
    echo
done
