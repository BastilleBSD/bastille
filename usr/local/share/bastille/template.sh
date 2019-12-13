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

bastille_usage() {
    echo -e "${COLOR_RED}Usage: bastille template TARGET project/template.${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    bastille_usage
    ;;
esac

if [ $# -gt 2 ] || [ $# -lt 2 ]; then
    bastille_usage
fi

TARGET="${1}"
shift

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(jls name)
fi
if [ "${TARGET}" != 'ALL' ]; then
    JAILS=$(jls name | grep -w "${TARGET}")
fi

TEMPLATE="${1}"
shift

if [ ! -d "${bastille_templatesdir}/${TEMPLATE}" ]; then
    echo -e "${COLOR_RED}${TEMPLATE} not found.${COLOR_RESET}"
    exit 1
fi

if [ -z "${JAILS}" ]; then
    echo -e "${COLOR_RED}Container ${TARGET} is not running.${COLOR_RESET}"
    exit 1
fi

## global variables
bastille_template=${bastille_templatesdir}/${TEMPLATE}
for _jail in ${JAILS}; do
    ## jail-specific variables. 
    bastille_jail_path=$(jls -j "${_jail}" path)

    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"

    ## TARGET
    if [ -s "${bastille_template}/TARGET" ]; then
        if [ $(grep -w "${_jail}" ${bastille_template}/TARGET) ]; then
            echo -e "${COLOR_GREEN}TARGET: !${_jail}.${COLOR_RESET}"
            echo
            continue
        fi
    if [ ! $(grep -E "(^|\b)(${_jail}|ALL)($|\b)" ${bastille_template}/TARGET) ]; then
            echo -e "${COLOR_GREEN}TARGET: ?${_jail}.${COLOR_RESET}"
            echo
            continue
        fi
    fi

    ## INCLUDE
    if [ -s "${bastille_template}/INCLUDE" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:INCLUDE -- START${COLOR_RESET}"
        while read _include; do
            echo
            echo -e "${COLOR_GREEN}INCLUDE: ${_include}${COLOR_RESET}"
            echo -e "${COLOR_GREEN}Bootstrapping ${_include}...${COLOR_RESET}"

            case ${_include} in
                http?://github.com/*/*|http?://gitlab.com/*/*)
                    bastille bootstrap ${_include}
                ;;
                */*)
                    BASTILLE_TEMPLATE_USER=$(echo "${_include}" | awk -F / '{ print $1 }')
                    BASTILLE_TEMPLATE_REPO=$(echo "${_include}" | awk -F / '{ print $2 }')
                    bastille template ${_jail} ${BASTILLE_TEMPLATE_USER}/${BASTILLE_TEMPLATE_REPO}
                ;;
                *)
                    echo -e "${COLOR_RED}Template INCLUDE content not recognized.${COLOR_RESET}"
		    exit 1
	        ;;
            esac

            echo
            echo -e "${COLOR_GREEN}Applying ${_include}...${COLOR_RESET}"
            BASTILLE_TEMPLATE_PROJECT=$(echo "${_include}" | awk -F / '{ print $4}')
            BASTILLE_TEMPLATE_REPO=$(echo "${_include}" | awk -F / '{ print $5}')
            bastille template ${_jail} ${BASTILLE_TEMPLATE_PROJECT}/${BASTILLE_TEMPLATE_REPO}
        done < "${bastille_template}/INCLUDE"
        echo -e "${COLOR_GREEN}[${_jail}]:INCLUDE -- END${COLOR_RESET}"
        echo
    fi

    ## PRE
    if [ -s "${bastille_template}/PRE" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:PRE -- START${COLOR_RESET}"
        jexec -l ${_jail} /bin/sh < "${bastille_template}/PRE" || exit 1
        echo -e "${COLOR_GREEN}[${_jail}]:PRE -- END${COLOR_RESET}"
        echo
    fi

    ## FSTAB
    if [ -s "${bastille_template}/FSTAB" ]; then
        echo -e "${COLOR_GREEN}NOT YET IMPLEMENTED.${COLOR_RESET}"
    fi

    ## PF
    if [ -s "${bastille_template}/PF" ]; then
        echo -e "${COLOR_GREEN}NOT YET IMPLEMENTED.${COLOR_RESET}"
    fi

    ## PKG (bootstrap + pkg)
    if [ -s "${bastille_template}/PKG" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:PKG -- START${COLOR_RESET}"
        jexec -l "${_jail}" env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg bootstrap || exit 1
        jexec -l "${_jail}" env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install $(cat ${bastille_template}/PKG) || exit 1
        jexec -l "${_jail}" env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg audit -F
        echo -e "${COLOR_GREEN}[${_jail}]:PKG -- END${COLOR_RESET}"
        echo
    fi

    ## CONFIG / OVERLAY
    if [ -s "${bastille_template}/OVERLAY" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:OVERLAY -- START${COLOR_RESET}"
        while read _dir; do
            cp -av "${bastille_template}/${_dir}" "${bastille_jail_path}" || exit 1
        done < ${bastille_template}/OVERLAY
        echo -e "${COLOR_GREEN}[${_jail}]:OVERLAY -- END${COLOR_RESET}"
        echo
    fi
    if [ -s "${bastille_template}/CONFIG" ]; then
        echo -e "${COLOR_YELLOW}CONFIG deprecated; rename to OVERLAY.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}[${_jail}]:CONFIG -- START${COLOR_RESET}"
        while read _dir; do
            cp -av "${bastille_template}/${_dir}" "${bastille_jail_path}" || exit 1
        done < ${bastille_template}/CONFIG
        echo -e "${COLOR_GREEN}[${_jail}]:CONFIG -- END${COLOR_RESET}"
        echo
    fi

    ## SYSRC
    if [ -s "${bastille_template}/SYSRC" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:SYSRC -- START${COLOR_RESET}"
        while read _sysrc; do
            jexec -l ${_jail} /usr/sbin/sysrc "${_sysrc}" || exit 1
        done < "${bastille_template}/SYSRC"
        echo -e "${COLOR_GREEN}[${_jail}]:SYSRC -- END${COLOR_RESET}"
        echo
    fi

    ## SERVICE
    if [ -s "${bastille_template}/SERVICE" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:SERVICE -- START${COLOR_RESET}"
        while read _service; do
            jexec -l ${_jail} /usr/sbin/service ${_service} || exit 1
        done < "${bastille_template}/SERVICE"
        echo -e "${COLOR_GREEN}[${_jail}]:SERVICE -- END${COLOR_RESET}"
        echo
    fi

    ## CMD
    if [ -s "${bastille_template}/CMD" ]; then
        echo -e "${COLOR_GREEN}[${_jail}]:CMD -- START${COLOR_RESET}"
        jexec -l ${_jail} /bin/sh < "${bastille_template}/CMD" || exit 1
        echo -e "${COLOR_GREEN}[${_jail}]:CMD -- END${COLOR_RESET}"
        echo
    fi

    echo -e "${COLOR_GREEN}Template Complete.${COLOR_RESET}"
    echo
done
