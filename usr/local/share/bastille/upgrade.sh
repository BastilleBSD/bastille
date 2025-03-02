#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
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

usage() {
    error_notify "Usage: bastille upgrade [option(s)] TARGET [NEWRELEASE|install]"
    cat << EOF
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -f | --force          Force upgrade a release.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
OPTION=""
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -f|--force)
            OPTION="-F"
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    f) OPTION="-F" ;;
                    x) enable_debug ;;
                    *) error_exit "Unknown Option: \"${1}\"" ;; 
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

TARGET="${1}"
NEWRELEASE="${2}"

bastille_root_check

# Check for unsupported actions    
if [ -f "/bin/midnightbsd-version" ]; then
    echo -e "${COLOR_RED}Not yet supported on MidnightBSD.${COLOR_RESET}"
    exit 1
fi

if freebsd-version | grep -qi HBSD; then
    error_exit "Not yet supported on HardenedBSD."
fi

thick_jail_check() {
    # Check if the jail is thick and is running
    set_target_single "${TARGET}"
    check_target_is_running "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${TARGET}"
    else   
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi
}

thin_jail_check() {
    # Check if the jail is thick and is running
    set_target_single "${TARGET}"
    check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${TARGET}"
    else   
        error_notify "Jail is running."
        error_continue "Use [-a|--auto] to auto-stop the jail."
    fi
}

release_check() {
    # Validate the release
    if ! echo "${NEWRELEASE}" | grep -q "[0-9]\{2\}.[0-9]-[RELEASE,BETA,RC]"; then
        error_exit "${NEWRELEASE} is not a valid release."
    fi
    # Exit if NEWRELEASE doesn't exist
    if [ "${THIN_JAIL}" -eq 1 ]; then
        if [ ! -d "${bastille_releasesdir}/${NEWRELEASE}" ]; then
            error_notify "Release not found: ${NEWRELEASE}"
            error_exit "See 'bastille bootstrap ${NEWRELEASE} to bootstrap the release."
        fi
    fi
}

jail_upgrade() {
    local _jailname="${1}"
    if [ "${THIN_JAIL}" -eq 1 ]; then
        local _oldrelease="$(bastille config ${_jailname} get osrelease)"
    else
        local _oldrelease="$(jexec -l ${TARGET} freebsd-version)"
    fi
    local _newrelease="${2}"
    local _jailpath="${bastille_jailsdir}/${TARGET}/root"
    local _workdir="${_jailpath}/var/db/freebsd-update"
    local _freebsd_update_conf="${_jailpath}/etc/freebsd-update.conf"

    # Upgrade a thin jail
    if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
        local _oldrelease="$(grep osrelease ${bastille_jailsdir}/${TARGET}/jail.conf | awk -F"= " '{print $2}' | sed 's/;//g')"
        local _newrelease="${NEWRELEASE}"
        # Update "osrelease" entry inside jail.conf
        sed -i '' "/.bastille/ s|${_oldrelease}|${_newrelease}|g" "${bastille_jailsdir}/${TARGET}/fstab"
        # Update "fstab" entry
        sed -i '' "/osrelease/ s|${_oldrelease}|${_newrelease}|g" "${bastille_jailsdir}/${TARGET}/jail.conf"
        info "Upgraded ${TARGET}: ${_oldrelease} -> ${_newrelease}"
        info "See 'bastille etcupdate TARGET' to update /etc/rc.conf"
    else
        # Upgrade a thick jail
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron \
        --currently-running "${_oldrelease}" \
        -j "${_jailname}" \
        -d "${_workdir}" \
        -f "${_freebsd_update_conf}" \
        -r "${_newrelease}" upgrade
        
        # Update "osrelease" entry inside jail.conf
        sed -i '' "/osrelease/ s|${_oldrelease}|${_newrelease}|g" "${bastille_jailsdir}/${TARGET}/jail.conf"
        echo
        echo -e "${COLOR_YELLOW}Please run 'bastille upgrade ${TARGET} install', restart the jail, then run 'bastille upgrade ${TARGET} install' again to finish installing updates.${COLOR_RESET}"
    fi
}

jail_updates_install() {
    local _jailname="${1}"
    local _jailpath="${bastille_jailsdir}/${TARGET}/root"
    local _workdir="${_jailpath}/var/db/freebsd-update"
    local _freebsd_update_conf="${_jailpath}/etc/freebsd-update.conf"
    # Finish installing upgrade on a thick container
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then 
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron \
        -j "${_jailname}" \
        -d "${_workdir}" \
        -f "${_freebsd_update_conf}" \
        install
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap RELEASE'."
    fi
}

# Check if jail is thick or thin
THIN_JAIL=0
if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
    THIN_JAIL=1
fi

# Check what we should upgrade
if [ "${NEWRELEASE}" = "install" ]; then
    if [ "${THIN_JAIL}" -eq 1 ]; then
        thin_jail_check
    else
        thick_jail_check
    fi
    jail_updates_install "${TARGET}"
else
    if [ "${THIN_JAIL}" -eq 1 ]; then
        thin_jail_check
    else
        thick_jail_check
    fi
    release_check
    jail_upgrade "${TARGET}" "${NEWRELEASE}"
fi
