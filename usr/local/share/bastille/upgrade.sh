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

thick_jail_check() {

    # Validate jail state
    check_target_is_running "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${TARGET}"
    else
        info "\n[${TARGET}]:"
        error_notify "Jail is not running."
        error_exit "Use [-a|--auto] to auto-start the jail."
    fi

    # Verify PLATFORM_OS inside jail
    JAIL_PLATFORM_OS="$(${bastille_jailsdir}/${TARGET}/root/bin/freebsd-version)"
    if echo "${JAIL_PLATFORM_OS}" | grep -q "HBSD"; then
        JAIL_PLATFORM_OS="HardenedBSD"
    else
        JAIL_PLATFORM_OS="FreeBSD"
    fi

    if [ "${JAIL_PLATFORM_OS}" = "FreeBSD" ]; then

        # Set OLD_RELEASE
        OLD_RELEASE="$(${bastille_jailsdir}/${TARGET}/root/bin/freebsd-version 2>/dev/null)"
        if [ -z "${OLD_RELEASE}" ]; then
            error_exit "[ERROR]: Can't determine '${TARGET}' version."
        fi

        # Set VERSION
        NEW_MINOR_VERSION=$(echo ${NEW_RELEASE} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')
        NEW_MAJOR_VERSION=$(echo ${NEW_RELEASE} | grep -Eo '^[0-9]+')

        # Validate PKGBASE or non-PKGBASE
        if pkg -r "${bastille_jailsdir}/${TARGET}/root" which /usr/bin/uname > /dev/null 2>&1; then
            PKGBASE=1
            if echo "${NEW_RELEASE}" | grep -Eoq "(\-CURRENT|\-STABLE)"; then
                FREEBSD_BRANCH="current"
            else
                FREEBSD_BRANCH="release"
            fi
        fi

        # Check if jail is already running NEW_RELEASE
        if [ "${OLD_RELEASE}" = "${NEW_RELEASE}" ]; then
            error_notify "[ERROR]: Jail is already running '${NEW_RELEASE}' release."
            error_exit "See 'bastille update TARGET' to update the jail."
        fi

    elif [ "${JAIL_PLATFORM_OS}" = "HardenedBSD" ]; then

        # Set VERSION
        OLD_RELEASE="$(${bastille_jailsdir}/${TARGET}/root/bin/freebsd-version 2>/dev/null)"
        OLD_CONFIG_RELEASE="$(bastille config ${TARGET} get osrelease)"
        if [ -z "${OLD_RELEASE}" ] || [ -z "${OLD_CONFIG_RELEASE}" ]; then
            error_exit "[ERROR]: Can't determine '${TARGET}' version."
        fi

        # Check if jail is already running NEW_RELEASE
        if [ "${OLD_CONFIG_RELEASE}" = "${NEW_RELEASE}" ]; then
            error_notify "[ERROR]: Jail is already running '${NEW_RELEASE}' release."
            error_exit "See 'bastille update TARGET' to update the jail."
        fi
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

    # Set OLD_RELEASE
    OLD_RELEASE="$(bastille config ${TARGET} get osrelease)"
    if [ -z "${OLD_RELEASE}" ]; then
        error_exit "[ERROR]: Can't determine '${TARGET}' version."
    fi

    # Check if jail is already running NEW_RELEASE
    if [ "${OLD_RELEASE}" = "${NEW_RELEASE}" ]; then
        error_notify "[ERROR]: Jail is already running '${NEW_RELEASE}' release."
        error_exit "See 'bastille update RELEASE' to update the release."
    fi
}

release_check() {

    # Validate the release name
    case "${NEW_RELEASE}" in
        [2-4].[0-9]*)
            PLATFORM_OS="MidnightBSD"
            NAME_VERIFY=$(echo "${NEW_RELEASE}")
            ;;
        *-current|*-CURRENT)
            PLATFORM_OS="FreeBSD"
            NAME_VERIFY=$(echo "${NEW_RELEASE}" | grep -iwE '^([1-9]+)\.[0-9](-CURRENT)$' | tr '[:lower:]' '[:upper:]')
            ;;
        *\.*-stable|*\.*-STABLE)
            PLATFORM_OS="FreeBSD"
            NAME_VERIFY=$(echo "${NEW_RELEASE}" | grep -iwE '^([1-9]+)\.[0-9](-STABLE)$' | tr '[:lower:]' '[:upper:]')
            ;;
        *-release|*-RELEASE|*-rc[1-9]|*-RC[1-9]|*-beta[1-9]|*-BETA[1-9])
            PLATFORM_OS="FreeBSD"
            NAME_VERIFY=$(echo "${NEW_RELEASE}" | grep -iwE '^([0-9]+)\.[0-9](-RELEASE|-RC[1-9]|-BETA[1-9])$' | tr '[:lower:]' '[:upper:]')
            ;;
        current|CURRENT)
            PLATFORM_OS="HardenedBSD"
            NAME_VERIFY=$(echo "${NEW_RELEASE}" | sed 's/CURRENT/current/g')
            ;;
        [1-9]*-stable|[1-9]*-STABLE)
            PLATFORM_OS="HardenedBSD"
            NAME_VERIFY=$(echo "${NEW_RELEASE}" | grep -iwE '^([1-9]+)(-stable)$' | sed 's/STABLE/stable/g')
            ;;
        *)
            error_exit "[ERROR]: Invalid release: ${RELEASE}"
            ;;
    esac

    NEW_RELEASE="${NAME_VERIFY}"

    # Exit if NEW_RELEASE doesn't exist
    if [ "${JAIL_TYPE}" = "thin" ]; then
        if [ ! -d "${bastille_releasesdir}/${NEW_RELEASE}" ]; then
            error_notify "[ERROR]: Release not found: ${NEW_RELEASE}"
            error_exit "See 'bastille bootstrap'."
        fi
    fi
}

jail_upgrade() {

    info "\n[${TARGET}]:"

    # Upgrade a thin jail
    if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then

        # Update "osrelease" entry inside fstab
        if ! sed -i '' "/.bastille/ s|${OLD_RELEASE}|${NEW_RELEASE}|g" "${bastille_jailsdir}/${TARGET}/fstab"; then
            error_exit "[ERROR]: Failed to update fstab."
        fi

        # Update "osrelease" inside jail.conf using 'bastille config'
        bastille config ${TARGET} set osrelease ${NEW_RELEASE} >/dev/null 2>/dev/null

        # Start jail if AUTO=1
        if [ "${AUTO}" -eq 1 ]; then
            bastille start "${TARGET}"
        fi

        info "\nUpgraded ${TARGET}: ${OLD_RELEASE} -> ${NEW_RELEASE}"
        echo "See 'bastille etcupdate TARGET' to update /etc"
        echo

    else

        if [ "${JAIL_PLATFORM_OS}" = "FreeBSD" ]; then

            local jailpath="${bastille_jailsdir}/${TARGET}/root"
            local work_dir="${jailpath}/var/db/freebsd-update"
            local freebsd_update_conf="${jailpath}/etc/freebsd-update.conf"

            # Upgrade a thick jail
            if env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron \
                --currently-running "${OLD_RELEASE}" \
                -j "${TARGET}" \
                -d "${work_dir}" \
                -f "${freebsd_update_conf}" \
                -r "${NEW_RELEASE}" upgrade; then

                # Update "osrelease" inside jail.conf using 'bastille config'
                bastille config ${TARGET} set osrelease ${UPGRADED_RELEASE} >/dev/null 2>/dev/null
                info "\nUpgraded ${TARGET}: ${OLD_RELEASE} > ${NEW_RELEASE}"
                warn "\nPlease run 'bastille upgrade ${TARGET} install', restart the jail, then run 'bastille upgrade ${TARGET} install' again to finish installing the upgrade.\n"
            else
                info "\nNo upgrades available.\n"
            fi

        elif [ "${JAIL_PLATFORM_OS}" = "HardenedBSD" ]; then

            local jailname="${TARGET}"
            local jailpath="${bastille_jailsdir}/${TARGET}/root"
            local hbsd_update_conf="${jailpath}/etc/hbsd-update.conf"

            # Set proper vars in hbsd-update.conf
            case ${NEW_RELEASE} in
                current)
                    branch="hardened/current/master"
                    dnsrec="\$(uname -m).master.current.hardened.hardenedbsd.updates.hardenedbsd.org"
                    ;;
                *-stable)
                    NEW_MAJOR_VERSION=$(echo ${NEW_RELEASE} | grep -Eo '^[0-9]+')
                    branch="hardened/${MAJOR_VERSION}-stable/master"
                    dnsrec="\$(uname -m).main.${MAJOR_VERSION}-stable.hardened.hardenedbsd.updates.hardenedbsd.org"
                    ;;
                *)
                    error_exit "[ERROR]: Unknown ${PLATFORM_OS} release: ${NEW_RELEASE}"
                    ;;
            esac
            sysrc -f "${hbsd_update_conf}" branch="${branch}" >/dev/null 2>/dev/null
            sysrc -f "${hbsd_update_conf}" dnsrec="${dnsrec}" >/dev/null 2>/dev/null

            hbsd-update \
            -j "${jailname}" \
            -c "${hbsd_update_conf}"

            UPGRADED_RELEASE="$(${bastille_jailsdir}/${TARGET}/root/bin/freebsd-version 2>/dev/null)"
            if [ "${OLD_RELEASE}" != "${UPGRADED_RELEASE}" ]; then
                info "\nUpgraded ${TARGET}: ${OLD_RELEASE} -> ${UPGRADED_RELEASE}\n"
            else
                info "\nNo upgrades available.\n"
            fi
        fi
    fi
}

jail_upgrade_pkgbase() {

    if [ "${JAIL_PLATFORM_OS}" = "FreeBSD" ]; then

        local jailpath="${bastille_jailsdir}/${TARGET}/root"
        local abi="FreeBSD:${NEW_MAJOR_VERSION}:${HW_MACHINE_ARCH}"
        local repo_dir="${bastille_sharedir}/pkgbase"
        if [ "${FREEBSD_BRANCH}" = "release" ]; then
            local repo_name="FreeBSD-base-release-${NEW_MINOR_VERSION}"
            local fingerprints="${jailpath}/usr/share/keys/pkgbase-${MAJOR_VERSION}"
        elif [ "${FREEBSD_BRANCH}" = "current" ]; then
            local repo_name="FreeBSD-base-latest"
            local fingerprints="${jailpath}/usr/share/keys/pkg"
        fi

        info "\n[${TARGET}]:"

        # Verify trusted pkg keys
        if [ "${FREEBSD_BRANCH}" = "release" ]; then
            if [ ! -f "${fingerprints}/trusted/awskms-${NEW_MAJOR_VERSION}" ]; then
                if ! fetch -o "${fingerprints}/trusted" https://cgit.freebsd.org/src/tree/share/keys/pkgbase-${NEW_MAJOR_VERSION}/trusted/awskms-${NEW_MAJOR_VERSION}; then
                    error_exit "[ERROR]: Failed to fetch trusted pkg keys."
                fi
            fi
            if [ ! -f "${fingerprints}/trusted/backup-signing-${NEW_MAJOR_VERSION}" ]; then
                if ! fetch -o "${fingerprints}/trusted" https://cgit.freebsd.org/src/tree/share/keys/pkgbase-${NEW_MAJOR_VERSION}/trusted/backup-signing-${NEW_MAJOR_VERSION}; then
                    error_exit "[ERROR]: Failed to fetch trusted backup pkg keys."
                fi
            fi
        fi

        # Upgrade jail with pkgbase (thick only)
        # Update repo (pkgbase)
        if ! pkg --rootdir "${jailpath}" \
                 --repo-conf-dir "${repo_dir}" \
                 -o IGNORE_OSVERSION="yes" \
                 -o VERSION_MAJOR="${NEW_MAJOR_VERSION}" \
                 -o VERSION_MINOR="${NEW_MINOR_VERSION}" \
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
                 -o VERSION_MAJOR="${NEW_MAJOR_VERSION}" \
                 -o VERSION_MINOR="${NEW_MINOR_VERSION}" \
                 -o ABI="${abi}" \
                 -o ASSUME_ALWAYS_YES="yes" \
                 -o FINGERPRINTS="${fingerprints}" \
                 upgrade -r "${repo_name}"; then

            error_exit "[ERROR]: Failed to upgrade jail: ${TARGET}"
        fi

        # Update release version (including patch level)
        UPGRADED_RELEASE=$(/usr/sbin/jexec -l "${TARGET}" freebsd-version 2>/dev/null)
        if [ "${OLD_RELEASE}" != "${UPGRADED_RELEASE}" ]; then
            bastille config ${TARGET} set osrelease ${UPGRADED_RELEASE} >/dev/null 2>/dev/null
            info "\nUpgrade complete: ${OLD_RELEASE} > ${UPGRADED_RELEASE}\n"
        else
            info "\nNo updates available.\n"
        fi

        info "\nUpgraded ${TARGET}: ${OLD_RELEASE} -> ${UPGRADED_RELEASE}"
    else
        error_exit "[ERROR]: Not implemented for platform: ${PLATFORM_OS}"
    fi

}

jail_updates_install() {

    if [ "${JAIL_PLATFORM_OS}" = "FreeBSD" ]; then

        local jailpath="${bastille_jailsdir}/${TARGET}/root"
        local work_dir="${jailpath}/var/db/freebsd-update"
        local freebsd_update_conf="${jailpath}/etc/freebsd-update.conf"

        info "\n[${TARGET}]:"

        # Finish installing upgrade on a thick container
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron \
        -j "${TARGET}" \
        -d "${work_dir}" \
        -f "${freebsd_update_conf}" \
        install
    else
        error_exit "[ERROR]: Not implemented for platform: ${PLATFORM_OS}"
    fi
}

# Set needed variables
JAIL_TYPE=""
PKGBASE=0
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

# Validate jail type (thick/thin)
if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
    JAIL_TYPE="thin"
fi

case ${NEW_RELEASE} in
    install)
        if [ "${JAIL_TYPE}" = "thin" ]; then
            thin_jail_check "${TARGET}"
        else
            thick_jail_check "${TARGET}"
        fi
        jail_updates_install "${TARGET}"
        ;;
    *)
        release_check
        # Unsupported platforms
        if [ "${PLATFORM_OS}" = "MidnightBSD" ] || [ -f "/bin/midnightbsd-version" ]; then
            error_exit "[ERROR]: Not yet supported on MidnightBSD."
        fi
        if [ "${JAIL_TYPE}" = "thin" ]; then
            thin_jail_check "${TARGET}"
            jail_upgrade
        else
            thick_jail_check "${TARGET}"
            if [ "${PKGBASE}" -eq 1 ]; then
                jail_upgrade_pkgbase
            else
                jail_upgrade
            fi
        fi
        ;;
esac