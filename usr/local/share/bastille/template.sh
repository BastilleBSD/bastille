#!/bin/sh
# 
# Copyright (c) 2018, Christer Edwards <christer.edwards@gmail.com>
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
    JAILS=$(jls -N name)
fi
if [ "$1" != 'ALL' ]; then
    JAILS=$(jls -N name | grep "$1")
fi

TEMPLATE=$2
bastille_template=${bastille_templatesdir}/${TEMPLATE}

for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"

    ## pre
    if [ -s "${bastille_template}/PRE" ]; then
        echo -e "${COLOR_GREEN}Executing PRE-command(s).${COLOR_RESET}"
        bastille_templatepre=$(cat "${bastille_template}/PRE")
        jexec -l "${_jail}" "${bastille_templatepre}"
    fi

    ## config
    if [ -s "${bastille_template}/CONFIG" ]; then
        echo -e "${COLOR_GREEN}Copying files...${COLOR_RESET}"
        for _dir in $(cat "${bastille_template}/CONFIG"); do
            cp -a "${bastille_template}/${_dir}" "${bastille_jailsdir}/${_jail}/root"
        done
        echo -e "${COLOR_GREEN}Copy complete.${COLOR_RESET}"
    fi

    ## fstab
    if [ -s "${bastille_template}/FSTAB" ]; then
        bastille_templatefstab=$(cat "${bastille_template}/FSTAB")
        echo -e "${COLOR_GREEN}Updating fstab.${COLOR_RESET}"
    fi

    ## pf
    if [ -s "${bastille_template}/PF" ]; then
        bastille_templatepf=$(cat "${bastille_template}/PF")
        echo -e "${COLOR_GREEN}Generating PF profile.${COLOR_RESET}"
    fi

    ## pkg (bootstrap + pkg)
    if [ -s "${bastille_template}/PKG" ]; then
        bastille_templatepkg=$(cat "${bastille_template}/PKG")
        echo -e "${COLOR_GREEN}Installing packages.${COLOR_RESET}"
        jexec -l ${_jail} env ASSUME_ALWAYS_YES="YES" /usr/sbin/pkg bootstrap
        jexec -l ${_jail} env ASSUME_ALWAYS_YES="YES" /usr/sbin/pkg audit -F
        jexec -l ${_jail} env ASSUME_ALWAYS_YES="YES" /usr/sbin/pkg install -y ${bastille_templatepkg}
    fi

    ## sysrc
    if [ -s "${bastille_template}/SYSRC" ]; then
        bastille_templatesys=$(cat "${bastille_template}/SYSRC")
        echo -e "${COLOR_GREEN}Updating services.${COLOR_RESET}"
        jexec -l ${_jail} /usr/sbin/sysrc ${bastille_templatesys}
    fi

    ## cmd
    if [ -s "${bastille_template}/CMD" ]; then
        bastille_templatecmd=$(cat "${bastille_template}/CMD")
        echo -e "${COLOR_GREEN}Executing final command(s).${COLOR_RESET}"
        jexec -l ${_jail} ${bastille_templatecmd}
    fi
    echo -e "${COLOR_GREEN}Template Complete.${COLOR_RESET}"
    echo
    echo
done
