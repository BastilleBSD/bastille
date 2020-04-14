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
    echo -e "${COLOR_RED}Usage: bastille list [-j] [release|template|(jail|container)|log|limit|(import|export|backup)].${COLOR_RESET}"
    exit 1
}

if [ $# -eq 0 ]; then
   jls -N
fi

if [ "$1" == "-j" ]; then
    jls -N --libxo json
    exit 0
fi

if [ $# -gt 0 ]; then
    # Handle special-case commands first.
    case "$1" in
    help|-h|--help)
        usage
        ;;
    release|releases)
        if [ -d "${bastille_releasesdir}" ]; then
            REL_LIST=$(ls "${bastille_releasesdir}" | sed "s/\n//g")
            for _REL in ${REL_LIST}; do
                if [ -f "${bastille_releasesdir}/${_REL}/root/.profile" ]; then
                    echo "${_REL}"
                fi
            done
        fi
        ;;
    template|templates)
        find "${bastille_templatesdir}" -type d -maxdepth 2
        ;;
    jail|jails|container|containers)
        if [ -d "${bastille_jailsdir}" ]; then
            JAIL_LIST=$(ls "${bastille_jailsdir}" | sed "s/\n//g")
            for _JAIL in ${JAIL_LIST}; do
                if [ -f "${bastille_jailsdir}/${_JAIL}/jail.conf" ]; then
                    echo "${_JAIL}"
                fi
            done
        fi
        ;;
    log|logs)
        find "${bastille_logsdir}" -type f -maxdepth 1
        ;;
    limit|limits)
        rctl -h jail:
        ;;
    import|imports|export|exports|backup|backups)
        ls "${bastille_backupsdir}" | grep -Ev "*.sha256"
    exit 0
    ;;
    *)
        usage
        ;;
    esac
fi
