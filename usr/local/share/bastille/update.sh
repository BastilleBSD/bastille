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
    echo -e "${COLOR_RED}Usage: bastille update release | container.${COLOR_RESET}"
    exit 1
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

TARGET="${1}"
shift

if [ ! -z "$(freebsd-version | grep -i HBSD)" ]; then
    echo -e "${COLOR_RED}Not yet supported on HardenedBSD.${COLOR_RESET}"
    exit 1
fi

if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
    if ! grep -qw ".bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
            if [ "$(jls name | grep -w "${TARGET}")" ]; then
                # Update a thick container.
                CURRENT_VERSION=$(/usr/sbin/jexec -l ${TARGET} freebsd-version 2>/dev/null)
                if [ -z "${CURRENT_VERSION}" ]; then
                    echo -e "${COLOR_RED}Can't determine '${TARGET}' version.${COLOR_RESET}"
                    exit 1
                else
                    env PAGER="/bin/cat" freebsd-update --not-running-from-cron -b "${bastille_jailsdir}/${TARGET}/root" \
                    fetch install --currently-running "${CURRENT_VERSION}"
                fi
            else
                echo -e "${COLOR_RED}${TARGET} is not running.${COLOR_RESET}"
                echo -e "${COLOR_RED}See 'bastille start ${TARGET}'.${COLOR_RESET}"
                exit 1
            fi
    else
        echo -e "${COLOR_RED}${TARGET} is not a thick container.${COLOR_RESET}"
        exit 1
    fi
else
    if [ -d "${bastille_releasesdir}/${TARGET}" ]; then
        # Update container base(affects child containers).
        env PAGER="/bin/cat" freebsd-update --not-running-from-cron -b "${bastille_releasesdir}/${TARGET}" \
        fetch install --currently-running "${TARGET}"
    else
        echo -e "${COLOR_RED}${TARGET} not found. See bootstrap.${COLOR_RESET}"
        exit 1
    fi
fi
