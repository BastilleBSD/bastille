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
    error_notify "Usage: bastille update [option(s)] TARGET"
    cat << EOF
    Options:

    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -f | --force            Force update a release.
    -x | --debug            Enable debug mode.

EOF
    exit 1
}

if [ $# -gt 2 ] || [ $# -lt 1 ]; then
    usage
fi

# Handle options.
OPTION=""
AUTO=0
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

TARGET="${1}"
PKGBASE=0

bastille_root_check

if [ -f "/bin/midnightbsd-version" ]; then
    error_exit "[ERROR]: Not yet supported on MidnightBSD."
fi

if freebsd-version | grep -qi HBSD; then
    error_exit "[ERROR]: Not yet supported on HardenedBSD."
fi

jail_check() {

    # Check if the jail is thick and is running
    set_target_single "${TARGET}"

    check_target_is_running "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${TARGET}"
    else
        info "\n[${TARGET}]:"
        error_notify "Jail is not running."
        error_exit "Use [-a|--auto] to auto-start the jail."
    fi

    info "\n[${TARGET}]:"

    if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
        error_notify "[ERROR]: ${TARGET} is not a thick container."
        error_exit "See 'bastille update RELEASE' to update thin jails."
    fi

    # Validate update method
    CURRENT_VERSION="$(/usr/sbin/jexec -l "${TARGET}" freebsd-version 2>/dev/null)"
    MINOR_VERSION=$(echo ${CURRENT_VERSION} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')
    MAJOR_VERSION=$(echo ${CURRENT_VERSION} | grep -Eo '^[0-9]+')
    if echo "${CURRENT_VERSION}" | grep -oq "\-CURRENT"; then
        FREEBSD_BRANCH="current"
    else
        FREEBSD_BRANCH="release"
    fi
    if [ -z "${CURRENT_VERSION}" ]; then
        error_exit "[ERROR]: Can't determine '${TARGET}' version."
    fi
    if [ "${MAJOR_VERSION}" -ge 16 ] || pkg -r "${bastille_jailsdir}/${TARGET}/root" -N 2>/dev/null; then
        PKGBASE=1
    fi
}

jail_update_pkgbase() {

    local jailpath="${bastille_jailsdir}/${TARGET}/root"
    local abi="FreeBSD:${MAJOR_VERSION}:${HW_MACHINE_ARCH}"
    local fingerprints="${jailpath}/usr/share/keys/pkg"
    if [ "${FREEBSD_BRANCH}" = "release" ]; then
        local repo_name="FreeBSD-base-release-${MINOR_VERSION}"
    elif [ "${FREEBSD_BRANCH}" = "current" ]; then
        local repo_name="FreeBSD-base-latest"
    fi
    local repo_dir="${bastille_sharedir}/pkgbase"

    # Update jail
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
}

jail_update() {

    local jailname="${TARGET}"
    local jailpath="${bastille_jailsdir}/${TARGET}/root"
    local freebsd_update_conf="${jailpath}/etc/freebsd-update.conf"
    local work_dir="${jailpath}/var/db/freebsd-update"

    # Update a thick container
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        CURRENT_VERSION=$(/usr/sbin/jexec -l "${TARGET}" freebsd-version 2>/dev/null)
        if [ -z "${CURRENT_VERSION}" ]; then
            error_exit "[ERROR]: Can't determine '${TARGET}' version."
        else
            env PAGER="/bin/cat" freebsd-update ${OPTION} \
            --not-running-from-cron \
            -j "${jailname}" \
            -d "${work_dir}" \
            -f "${freebsd_update_conf}" \
            fetch
            env PAGER="/bin/cat" freebsd-update ${OPTION} \
            --not-running-from-cron \
            -j "${jailname}" \
            -d "${work_dir}" \
            -f "${freebsd_update_conf}" \
            install
        fi
        # Update release version (including patch level)
        NEW_VERSION=$(/usr/sbin/jexec -l "${TARGET}" freebsd-version 2>/dev/null)
        bastille config ${TARGET} set osrelease ${NEW_VERSION}
    fi
}

release_check() {

    if echo "${TARGET}" | grep -w "[0-9]\{1,2\}\.[0-9]\-RELEASE\-i386"; then
        ARCH_I386="1"
    fi

    # Validate update method
    MINOR_VERSION=$(echo ${TARGET} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')
    MAJOR_VERSION=$(echo ${TARGET} | grep -Eo '^[0-9]+')
    if echo "${TARGET}" | grep -oq "\-CURRENT"; then
        FREEBSD_BRANCH="current"
    else
        FREEBSD_BRANCH="release"
    fi
    if [ "${MAJOR_VERSION}" -ge 16 ] || pkg -r "${bastille_releasesdir}/${TARGET}" -N 2>/dev/null; then
        PKGBASE=1
    fi
}

release_update_pkgbase() {

    local release_dir="${bastille_releasesdir}/${TARGET}"
    local abi="FreeBSD:${MAJOR_VERSION}:${HW_MACHINE_ARCH}"
    local fingerprints="${release_dir}/usr/share/keys/pkg"
    if [ "${FREEBSD_BRANCH}" = "release" ]; then
        local repo_name="FreeBSD-base-release-${MINOR_VERSION}"
    elif [ "${FREEBSD_BRANCH}" = "current" ]; then
        local repo_name="FreeBSD-base-latest"
    fi
    local repo_dir="${bastille_sharedir}/pkgbase"

    # Update a release base (affects child containers)
    if [ -d "${release_dir}" ]; then
        # Update repo (pkgbase)
        if ! pkg --rootdir "${release_dir}" \
                 --repo-conf-dir "${repo_dir}" \
                  -o IGNORE_OSVERSION="yes" \
                  -o ABI="${abi}" \
                  -o ASSUME_ALWAYS_YES="yes" \
                  -o FINGERPRINTS="${fingerprints}" \
                  update -r "${repo_name}"; then
            error_exit "[ERROR]: Failed to update pkg repo: ${repo_name}"
        fi
        # Update release (pkgbase)
        if ! pkg --rootdir "${release_dir}" \
                 --repo-conf-dir "${repo_dir}" \
                  -o IGNORE_OSVERSION="yes" \
                  -o ABI="${abi}" \
                  -o ASSUME_ALWAYS_YES="yes" \
                  -o FINGERPRINTS="${fingerprints}" \
                  upgrade -r "${repo_name}"; then
            error_exit "[ERROR]: Failed to upgrade release: ${TARGET}"
        fi
    else
        error_notify "[ERROR]: Release not found: ${TARGET}"
        error_exit "See 'bastille bootstrap RELEASE'"
    fi
}

release_update() {

    local release_dir="${bastille_releasesdir}/${TARGET}"
    local freebsd_update_conf="${release_dir}/etc/freebsd-update.conf"
    local work_dir="${release_dir}/var/db/freebsd-update"

    # Update a release base(affects child containers)
    if [ -d "${release_dir}" ]; then
        TARGET_TRIM="${TARGET}"
        if [ -n "${ARCH_I386}" ]; then
            TARGET_TRIM=$(echo "${TARGET}" | sed 's/-i386//')
        fi
        env PAGER="/bin/cat" freebsd-update ${OPTION} \
        --not-running-from-cron \
        -b "${release_dir}" \
        -d "${work_dir}" \
        -f "${freebsd_update_conf}" \
        fetch --currently-running "${TARGET_TRIM}"
        env PAGER="/bin/cat" freebsd-update ${OPTION} \
        --not-running-from-cron \
        -b "${release_dir}" \
        -d "${work_dir}" \
        -f "${freebsd_update_conf}" \
        install --currently-running "${TARGET_TRIM}"
    else
        error_exit "[ERROR]: ${TARGET} not found. See 'bastille bootstrap RELEASE'."
    fi
}

template_update() {

    # Update a template
    template_path=${bastille_templatesdir}/${BASTILLE_TEMPLATE}

    if [ -d ${template_path} ]; then
        info "\n[${BASTILLE_TEMPLATE}]:"
        if ! git -C $_template_path pull; then
            error_exit "[ERROR]: ${BASTILLE_TEMPLATE} update unsuccessful."
        fi
        bastille verify "${BASTILLE_TEMPLATE}"
    else
        error_exit "[ERROR]: ${BASTILLE_TEMPLATE} not found. See 'bastille bootstrap'."
    fi
}

templates_update() {

    # Update all templates
    updated_templates=0

    if [ -d  ${bastille_templatesdir} ]; then
        # shellcheck disable=SC2045
        for template_path in $(ls -d ${bastille_templatesdir}/*/*); do
            if [ -d $template_path/.git ]; then
                BASTILLE_TEMPLATE=$(echo "$template_path" | awk -F / '{ print $(NF-1) "/" $NF }')
                template_update
                updated_templates=$((updated_templates+1))
            fi
        done
    fi

    # Verify template updates
    if [ "$updated_templates" -ne "0" ]; then
        info "\n$updated_templates templates updated."
    else
        error_exit "[ERROR]: No templates found. See 'bastille bootstrap'."
    fi
}

# Set needed variables for pkgbase
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

# Check what we should update
if [ "${TARGET}" = 'TEMPLATES' ]; then
    templates_update
elif echo "${TARGET}" | grep -Eq '^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$'; then
    BASTILLE_TEMPLATE="${TARGET}"
    template_update
elif echo "${TARGET}" | grep -q "[0-9]\{2\}.[0-9]-RELEASE"; then
    release_check
    if [ "${PKGBASE}" -eq 1 ]; then
        release_update_pkgbase
    else
        release_update
    fi
else
    jail_check
    if [ "${PKGBASE}" -eq 1 ]; then
        jail_update_pkgbase
    else
        jail_update
    fi
fi