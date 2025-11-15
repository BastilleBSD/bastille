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
    error_notify "Usage: bastille upgrade [option(s)] TARGET NEW_RELEASE|install"
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
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\"" ;;
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
NEW_RELEASE="${2}"

bastille_root_check
set_target_single "${TARGET}"

# Check for unsupported actions
if [ -f "/bin/midnightbsd-version" ]; then
    error_exit "[ERROR]: Not yet supported on MidnightBSD."
fi

if freebsd-version | grep -qi HBSD; then
    error_exit "[ERROR]: Not yet supported on HardenedBSD."
fi

thick_jail_check() {

    # Validate jail state
    check_target_is_running "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${TARGET}"
    else
        info "\n[${TARGET}]:"
        error_notify "Jail is not running."
        error_exit "Use [-a|--auto] to auto-start the jail."
    fi
}

thin_jail_check() {

    # Validate jail state
    check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${TARGET}"
    else
        info "\n[${TARGET}]:"
        error_notify "Jail is running."
        error_exit "Use [-a|--auto] to auto-stop the jail."
    fi
}

release_check() {

    # Validate the release
    if ! echo "${NEW_RELEASE}" | grep -q "[0-9]\{2\}.[0-9]-[RELEASE,BETA,RC]"; then
        error_exit "[ERROR]: ${NEW_RELEASE} is not a valid release."
    fi

    # Exit if NEW_RELEASE doesn't exist
    if [ "${THIN_JAIL}" -eq 1 ]; then
        if [ ! -d "${bastille_releasesdir}/${NEW_RELEASE}" ]; then
            error_notify "[ERROR]: Release not found: ${NEW_RELEASE}"
            error_exit "See 'bastille bootstrap ${NEW_RELEASE} to bootstrap the release."
        fi
    fi
}

jail_upgrade_pkgbase() {

    # Only thick jails should be targetted here
    local jailpath="${bastille_jailsdir}/${TARGET}/root"
    local abi="FreeBSD:${NEW_MAJOR_VERSION}:${HW_MACHINE_ARCH}"
    local fingerprints="${jailpath}/usr/share/keys/pkg"
    if [ "${FREEBSD_BRANCH}" = "release" ]; then
        local repo_name="FreeBSD-base-release-${NEW_MINOR_VERSION}"
    elif [ "${FREEBSD_BRANCH}" = "current" ]; then
        local repo_name="FreeBSD-base-latest"
    fi
    local repo_dir="${bastille_sharedir}/pkgbase"

    info "\n[${TARGET}]:"

    if [ "${OLD_RELEASE}" = "${NEW_RELEASE}" ]; then
        error_notify "[ERROR]: Jail is already running '${NEW_RELEASE}'"
        error_notify "See 'bastille update TARGET' to update jail."
    fi

    # Upgrade jail with pkgbase (thick only)
    if [ -d "${jailpath}" ]; then
        # Update repo (pkgbase)
        if ! pkg --rootdir "${jailpath}" \
                 --repo-conf-dir "${repo_dir}" \
                  -o IGNORE_OSVERSION="yes" \
                  -o ABI="${abi}" \
                  -o ASSUME_ALWAYS_YES="yes" \
                  -o FINGERPRINTS="${fingerprints}" \
                  update -r "${repo_name}"; then
            error_exit "[ERROR]: Failed to update pkg repo: ${repo_name}"
        fi
        # Update jail
        if ! pkg --rootdir "${jailpath}" \
                 --repo-conf-dir "${repo_dir}" \
                  -o IGNORE_OSVERSION="yes" \
                  -o ABI="${abi}" \
                  -o ASSUME_ALWAYS_YES="yes" \
                  -o FINGERPRINTS="${fingerprints}" \
                  upgrade -r "${repo_name}"; then
            error_exit "[ERROR]: Failed to upgrade jail: ${TARGET}"
        fi
        # Update release version (including patch level)
        NEW_VERSION=$(/usr/sbin/jexec -l "${TARGET}" freebsd-version 2>/dev/null)
        bastille config ${TARGET} set osrelease ${NEW_VERSION}
    else
        error_exit "[ERROR]: Jail not found: ${TARGET}"
    fi
    info "\nUpgraded ${TARGET}: ${OLD_RELEASE} -> ${NEW_RELEASE}"
}

jail_upgrade() {

    info "\n[${TARGET}]:"

    local jailpath="${bastille_jailsdir}/${TARGET}/root"
    local work_dir="${jailpath}/var/db/freebsd-update"
    local freebsd_update_conf="${jailpath}/etc/freebsd-update.conf"

    # Upgrade a thin jail
    if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
        # Update "osrelease" entry inside fstab
        sed -i '' "/.bastille/ s|${OLD_RELEASE}|${NEW_RELEASE}|g" "${bastille_jailsdir}/${TARGET}/fstab"
        # Update "osrelease" inside jail.conf using 'bastille config'
        bastille config ${TARGET} set osrelease ${NEW_RELEASE}
        # Start jail if AUTO=1
        if [ "${AUTO}" -eq 1 ]; then
            bastille start "${TARGET}"
        fi
        info "\nUpgraded ${TARGET}: ${OLD_RELEASE} -> ${NEW_RELEASE}"
        echo "See 'bastille etcupdate TARGET' to update /etc"
    else
        # Upgrade a thick jail
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron \
        --currently-running "${OLD_RELEASE}" \
        -j "${TARGET}" \
        -d "${work_dir}" \
        -f "${freebsd_update_conf}" \
        -r "${NEW_RELEASE}" upgrade

        # Update "osrelease" inside jail.conf using 'bastille config'
        bastille config ${TARGET} set osrelease ${NEW_RELEASE}
        warn "Please run 'bastille upgrade ${TARGET} install', restart the jail, then run 'bastille upgrade ${TARGET} install' again to finish installing updates."
    fi
}

jail_updates_install() {

    local jailpath="${bastille_jailsdir}/${TARGET}/root"
    local work_dir="${jailpath}/var/db/freebsd-update"
    local freebsd_update_conf="${jailpath}/etc/freebsd-update.conf"

    info "\n[${TARGET}]:"

    # Finish installing upgrade on a thick container
    if [ -d "${jailpath}" ]; then
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron \
        -j "${TARGET}" \
        -d "${work_dir}" \
        -f "${freebsd_update_conf}" \
        install
    else
        error_exit "[ERROR]: ${TARGET} not found. See 'bastille bootstrap RELEASE'."
    fi
}

# Set needed variables
THIN_JAIL=0
PKGBASE=0
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

# Validate jail type (thick/thin)
if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
    THIN_JAIL=1
fi

# Check what we should upgrade
if [ "${NEW_RELEASE}" = "install" ]; then
    if [ "${THIN_JAIL}" -eq 1 ]; then
        thin_jail_check "${TARGET}"
    else
        thick_jail_check "${TARGET}"
    fi
    jail_updates_install "${TARGET}"
else
    release_check
    if [ "${THIN_JAIL}" -eq 1 ]; then
        thin_jail_check "${TARGET}"
    else
        thick_jail_check "${TARGET}"
    fi
    OLD_RELEASE="$(${bastille_jailsdir}/${TARGET}/root/bin/freebsd-version 2>/dev/null)"
    if [ -z "${OLD_RELEASE}" ]; then
        OLD_RELEASE="$(bastille config ${TARGET} get osrelease)"
    fi
    OLD_MINOR_VERSION=$(echo ${OLD_RELEASE} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')
    OLD_MAJOR_VERSION=$(echo ${OLD_RELEASE} | grep -Eo '^[0-9]+')
    NEW_MINOR_VERSION=$(echo ${NEW_RELEASE} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')
    NEW_MAJOR_VERSION=$(echo ${NEW_RELEASE} | grep -Eo '^[0-9]+')
    # Check if jail is already running NEW_RELEASE
    if [ "${OLD_MAJOR_VERSION}.${OLD_MINOR_VERSION}" = "${NEW_MAJOR_VERSION}.${NEW_MINOR_VERSION}" ]; then
        error_notify "[ERROR]: Jail is already running '${NEW_RELEASE}' release."
        if [ "${THIN_JAIL}" -eq 1 ]; then
            error_exit "See 'bastille update RELEASE' to update the release."
        else
            error_exit "See 'bastille update TARGET' to update the jail."
        fi
    fi
    # Validate PKGBASE or non-PKGBASE
    if echo "${NEW_RELEASE}" | grep -oq "\-CURRENT"; then
        FREEBSD_BRANCH="current"
    else
        FREEBSD_BRANCH="release"
    fi
    if [ "${NEW_MAJOR_VERSION}" -ge 16 ] || pkg -r "${bastille_jailsdir}/${TARGET}/root" which /usr/bin/uname > /dev/null 2>&1; then
        PKGBASE=1
    fi
    # Validate THIN_JAIL+PKGBASE
	if [ "${PKGBASE}" -eq 1 ] && [ "${THIN_JAIL}" -eq 0 ]; then
        jail_upgrade_pkgbase
    else
        jail_upgrade
    fi
fi
