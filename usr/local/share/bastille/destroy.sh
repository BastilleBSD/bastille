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
    echo -e "${COLOR_RED}Usage: bastille destroy name.${COLOR_RESET}"
    exit 1
}

destroy_jail() {
    bastille_jail_base="${bastille_jailsdir}/${NAME}"            ## dir
    bastille_jail_log="${bastille_logsdir}/${NAME}_console.log"  ## file

    if [ $(jls name | grep ${NAME}) ]; then
        echo -e "${COLOR_RED}Jail running.${COLOR_RESET}"
        echo -e "${COLOR_RED}See 'bastille stop ${NAME}'.${COLOR_RESET}"
        exit 1
    fi

    if [ ! -d "${bastille_jail_base}" ]; then
        echo -e "${COLOR_RED}Jail not found.${COLOR_RESET}"
        exit 1
    fi

    if [ -d "${bastille_jail_base}" ]; then
        echo -e "${COLOR_GREEN}Deleting Jail: ${NAME}.${COLOR_RESET}"
        chflags -R noschg ${bastille_jail_base}
        rm -rf ${bastille_jail_base}
        mv ${bastille_jail_log} ${bastille_jail_log}-$(date +%F)
        echo -e "${COLOR_GREEN}Note: jail console logs archived.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}${bastille_jail_log}-$(date +%F)${COLOR_RESET}"
        echo
    fi
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

NAME="$1"

destroy_jail
