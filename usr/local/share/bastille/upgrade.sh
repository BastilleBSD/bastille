#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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

. /usr/local/share/bastille/common.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    error_exit "Usage: bastille upgrade release newrelease | target newrelease | target install | [force]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 3 ] || [ $# -lt 2 ]; then
    usage
fi

bastille_root_check

TARGET="$1"
NEWRELEASE="$2"
OPTION="$3"

# Check for unsupported actions
if [ "${TARGET}" = "ALL" ]; then
    error_exit "Batch upgrade is unsupported."
fi

if [ -f "/bin/midnightbsd-version" ]; then
    echo -e "${COLOR_RED}Not yet supported on MidnightBSD.${COLOR_RESET}"
    exit 1
fi

if freebsd-version | grep -qi HBSD; then
    error_exit "Not yet supported on HardenedBSD."
fi

# Handle options
case "${OPTION}" in
    -f|--force)
        OPTION="-F"
        ;;
    *)
        OPTION=
        ;;
esac

jail_check() {
    # Check if the jail is thick and is running
    if [ ! "$(/usr/sbin/jls name | awk "/^${TARGET}$/")" ]; then
        error_exit "[${TARGET}]: Not started. See 'bastille start ${TARGET}'."
    else
        if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
            error_exit "${TARGET} is not a thick container."
        fi
    fi
}

release_check() {
    # Validate the release
    if ! echo "${NEWRELEASE}" | grep -q "[0-9]\{2\}.[0-9]-[RELEASE,BETA,RC]"; then
        error_exit "${NEWRELEASE} is not a valid release."
    fi
}

release_upgrade() {
    # Upgrade a release
    if [ -d "${bastille_releasesdir}/${TARGET}" ]; then
        release_check
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_releasesdir}/${TARGET}" --currently-running "${TARGET}" -r "${NEWRELEASE}" upgrade
        echo
        echo -e "${COLOR_YELLOW}Please run 'bastille upgrade ${TARGET} install' to finish installing updates.${COLOR_RESET}"
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap'."
    fi
}

jail_upgrade() {
    # Upgrade a thick container
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        jail_check
        release_check
        CURRENT_VERSION=$(jexec -l ${TARGET} freebsd-version)
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_jailsdir}/${TARGET}/root" --currently-running "${CURRENT_VERSION}" -r ${NEWRELEASE} upgrade
        echo
        echo -e "${COLOR_YELLOW}Please run 'bastille upgrade ${TARGET} install' to finish installing updates.${COLOR_RESET}"
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap'."
    fi
}

jail_updates_install() {
    # Finish installing upgrade on a thick container
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then 
        jail_check
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_jailsdir}/${TARGET}/root" install
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap'."
    fi
}

release_updates_install() {
    # Finish installing upgrade on a release
    if [ -d "${bastille_releasesdir}/${TARGET}" ]; then 
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_releasesdir}/${TARGET}" install
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap'."
    fi
}

# Check what we should upgrade
if echo "${TARGET}" | grep -q "[0-9]\{2\}.[0-9]-RELEASE"; then
    if [ "${NEWRELEASE}" = "install" ]; then
        release_updates_install
    else
        release_upgrade
    fi
elif [ "${NEWRELEASE}" = "install" ]; then
    jail_updates_install
else
    jail_upgrade
fi
