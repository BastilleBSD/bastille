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
    error_notify "Usage: bastille bootstrap [option(s)] RELEASE [update|arch]"
    error_notify "                                      TEMPLATE"
    cat << EOF

    Options:

    -p | --pkgbase     Bootstrap using pkgbase (15.0-RELEASE and above).
    -x | --debug       Enable debug mode.

EOF
    exit 1
}

bootstrap_directories() {

    ## ${bastille_prefix}
    if [ ! -d "${bastille_prefix}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_prefix_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}"
            fi
        else
            mkdir -p "${bastille_prefix}"
        fi
        chmod 0750 "${bastille_prefix}"
    # Make sure the dataset is mounted in the proper place
    elif [ -d "${bastille_prefix}" ] && checkyesno bastille_zfs_enable; then
        if ! zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}" >/dev/null 2>&1; then
            zfs create ${bastille_zfs_options} -o mountpoint="${bastille_prefix_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}"
        elif [ "$(zfs get -H -o value mountpoint ${bastille_zfs_zpool}/${bastille_zfs_prefix})" != "${bastille_prefix}" ]; then
            zfs set mountpoint="${bastille_prefix_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}"
        fi
    fi

    ## ${bastille_backupsdir}
    if [ ! -d "${bastille_backupsdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_backupsdir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/backups"
            fi
        else
            mkdir -p "${bastille_backupsdir}"
        fi
        chmod 0750 "${bastille_backupsdir}"
    fi

    ## ${bastille_cachedir}
    if [ ! -d "${bastille_cachedir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_cachedir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache"
                # Don't create unused/stale cache/RELEASE directory on Linux jails creation.
                if [ -z "${NOCACHEDIR}" ]; then
                    zfs create ${bastille_zfs_options} -o mountpoint="${bastille_cachedir_mountpoint}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}"
                fi
            fi
        else
            mkdir -p "${bastille_cachedir}"
            # Don't create unused/stale cache/RELEASE directory on Linux jails creation.
            if [ -z "${NOCACHEDIR}" ]; then
                mkdir -p "${bastille_cachedir}/${RELEASE}"
            fi
        fi
    ## create subsequent cache/XX.X-RELEASE datasets
    elif [ ! -d "${bastille_cachedir}/${RELEASE}" ]; then
        # Don't create unused/stale cache/RELEASE directory on Linux jails creation.
        if [ -z "${NOCACHEDIR}" ]; then
            if checkyesno bastille_zfs_enable; then
                if [ -n "${bastille_zfs_zpool}" ]; then
                    zfs create ${bastille_zfs_options} -o mountpoint="${bastille_cachedir_mountpoint}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}"
                fi
            else
                mkdir -p "${bastille_cachedir}/${RELEASE}"
            fi
        fi
    fi

    ## ${bastille_jailsdir}
    if [ ! -d "${bastille_jailsdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_jailsdir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails"
            fi
        else
            mkdir -p "${bastille_jailsdir}"
        fi
    fi

    ## ${bastille_logsdir}
    if [ ! -d "${bastille_logsdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_logsdir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/logs"
            fi
        else
            mkdir -p "${bastille_logsdir}"
        fi
    fi

    ## ${bastille_templatesdir}
    if [ ! -d "${bastille_templatesdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_templatesdir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/templates"
            fi
        else
            mkdir -p "${bastille_templatesdir}"
        fi
    fi

    ## ${bastille_releasesdir}
    if [ ! -d "${bastille_releasesdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_releasesdir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases"
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_releasesdir_mountpoint}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"
            fi
        else
            mkdir -p "${bastille_releasesdir}/${RELEASE}"
        fi
    ## create subsequent releases/XX.X-RELEASE datasets
    elif [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_releasesdir_mountpoint}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"
            fi
       else
           mkdir -p "${bastille_releasesdir}/${RELEASE}"
       fi
    fi
}

cleanup_directories() {

    # Cleanup on failed bootstrap
    if checkyesno bastille_zfs_enable; then
        if [ -n "${bastille_zfs_zpool}" ]; then
            if zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}" >/dev/null 2>/dev/null; then
                zfs destroy "${bastille_zfs_zpool:?}/${bastille_zfs_prefix:?}/cache/${RELEASE}"
            fi
            if zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}" >/dev/null 2>/dev/null; then
                zfs destroy "${bastille_zfs_zpool:?}/${bastille_zfs_prefix:?}/releases/${RELEASE}"
            fi
        fi
    fi
    if [ -d "${bastille_cachedir}/${RELEASE}" ]; then
        if [ -d "${bastille_cachedir}/${RELEASE}" ]; then
            rm -rf "${bastille_cachedir:?}/${RELEASE}"
        fi
        if [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
            rm -rf "${bastille_releasesdir:?}/${RELEASE}"
        fi
    fi
}

validate_release() {

    # Set release name to sane release
    RELEASE="${NAME_VERIFY}"

    info "\nAttempting to bootstrap ${PLATFORM_OS} release: ${RELEASE}"

    ### FreeBSD ###
    if [ "${PLATFORM_OS}" = "FreeBSD" ]; then
        MAJOR_VERSION=$(echo ${RELEASE} | grep -Eo '^[0-9]+')
        MINOR_VERSION=$(echo ${RELEASE} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')
        if [ "${MAJOR_VERSION}" -ge 16 ]; then
            PKGBASE=1
        elif [ "${MAJOR_VERSION}" -le 14 ]  && [ "${PKGBASE}" -eq 1 ]; then
            error_exit "[ERROR]: Pkgbase is not supported for release: ${RELEASE}"
        fi
    ### Linux ###
    elif [ "${PLATFORM_OS}" = "Linux/Debian" ] || [ "${PLATFORM_OS}" = "Linux/Ubuntu" ]; then
        info "\nEnsuring Linux compatability..."
        if ! bastille setup -y linux >/dev/null 2>/dev/null; then
            error_notify "[ERROR]: Failed to configure linux."
            error_exit "See 'bastille setup linux' for more details."
        fi
    elif [ "${PLATFORM_OS}" != "FreeBSD" ]  && [ "${PKGBASE}" -eq 1 ]; then
            error_exit "[ERROR]: Pkgbase is not supported for platform: ${PLATFORM_OS}"
    fi


    # Validate OPTION
    if [ -n "${OPTION}" ]; then
        # Alternate RELEASE/ARCH fetch support
        if [ "${OPTION}" = "--i386" ] || [ "${OPTION}" = "--32bit" ]; then
            ARCH="i386"
            RELEASE="${RELEASE}-${ARCH}"
        fi
    fi
}

bootstrap_release_legacy() {

    # Verify release URL
    if ! fetch -qo /dev/null "${UPSTREAM_URL}/MANIFEST" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        error_notify "Unable to fetch MANIFEST. See 'bootstrap urls'."
        return 1
    fi

    # Validate already installed archives
    if [ -f "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" ]; then
        bastille_bootstrap_archives=$(echo "${bastille_bootstrap_archives}" | sed "s/base//")
        # shellcheck disable=SC2010
        bastille_cached_files=$(ls "${bastille_cachedir}/${RELEASE}" | grep -v "MANIFEST" | tr -d ".txz")
        for distfile in ${bastille_cached_files}; do
            bastille_bootstrap_archives=$(echo "${bastille_bootstrap_archives}" | sed "s/${distfile}//")
        done
        if [ -z "${bastille_bootstrap_archives}" ]; then
            info "\nBootstrap appears complete!\n"
            exit 0
        fi
    fi

    # Bootstrap archives
    for archive in ${bastille_bootstrap_archives}; do
        if [ -f "${bastille_cachedir}/${RELEASE}/${archive}.txz" ]; then
            info "\nExtracting ${PLATFORM_OS} archive: ${archive}.txz"
            if ! /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${archive}.txz"; then
                ERRORS=$((ERRORS + 1))
                error_continue "[ERROR]: Failed to extract archive: ${archive}.txz."
            fi
        else
            # Fetch MANIFEST
            if [ ! -f "${bastille_cachedir}/${RELEASE}/MANIFEST" ]; then
                info "\nFetching MANIFEST..."
                if ! fetch "${UPSTREAM_URL}/MANIFEST" -o "${bastille_cachedir}/${RELEASE}/MANIFEST"; then
                    ERRORS=$((ERRORS + 1))
                    error_continue "[ERROR]: Failed to fetch MANIFEST."
                fi
            fi

            # Fetch distfile
            if [ ! -f "${bastille_cachedir}/${RELEASE}/${archive}.txz" ]; then
                info "\nFetching distfile: ${archive}.txz"
                if ! fetch "${UPSTREAM_URL}/${archive}.txz" -o "${bastille_cachedir}/${RELEASE}/${archive}.txz"; then
                    ERRORS=$((ERRORS + 1))
                    error_continue "[ERROR]: Failed to fetch archive: ${archive}.txz"
                fi
            fi

            # Validate checksums
            info "\nValidating checksum for archive: ${archive}.txz"
            if [ -f "${bastille_cachedir}/${RELEASE}/${archive}.txz" ]; then
                SHA256_DIST=$(grep -w "${archive}.txz" "${bastille_cachedir}/${RELEASE}/MANIFEST" | awk '{print $2}')
                SHA256_FILE=$(sha256 -q "${bastille_cachedir}/${RELEASE}/${archive}.txz")
                if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
                    ERRORS=$((ERRORS + 1))
                    error_continue "[ERROR]: Failed to validate checksum for archive: ${archive}.txz"
                else
                    echo "MANIFEST: ${SHA256_DIST}"
                    echo "DOWNLOAD: ${SHA256_FILE}"
                    info "\nChecksum validated."
                fi
            fi

            # Extract distfile
            info "\nExtracting archive: ${archive}.txz"
            if [ -f "${bastille_cachedir}/${RELEASE}/${archive}.txz" ]; then
                if ! /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${archive}.txz"; then
                    ERRORS=$((ERRORS + 1))
                    error_continue "[ERROR]: Failed to extract archive: ${archive}.txz."
                fi
            fi
        fi
    done

    # Cleanup on error
    if [ "${ERRORS}" -ne 0 ]; then
        return 1
    fi

    # Silence motd at container login
    touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
    touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"
}

bootstrap_release_pkgbase() {

    info "\nUsing PkgBase..."

    ### FreeBSD ###
    if [ "${PLATFORM_OS}" = "FreeBSD" ]; then

        local abi="${PLATFORM_OS}:${MAJOR_VERSION}:${HW_MACHINE_ARCH}"
        local repo_dir="${bastille_sharedir}/pkgbase"
        if [ "${FREEBSD_BRANCH}" = "release" ]; then
            local repo_name="FreeBSD-base-release-${MINOR_VERSION}"
            local release_fingerprintsdir="${bastille_releasesdir}/${RELEASE}/usr/share/keys"
            local host_fingerprintsdir="/usr/share/keys/pkgbase-${MAJOR_VERSION}"
            local fingerprints="${bastille_releasesdir}/${RELEASE}/usr/share/keys/pkgbase-${MAJOR_VERSION}"
        elif [ "${FREEBSD_BRANCH}" = "current" ]; then
            local repo_name="FreeBSD-base-latest"
            local release_fingerprintsdir="${bastille_releasesdir}/${RELEASE}/usr/share/keys"
            local host_fingerprintsdir="/usr/share/keys/pkg"
            local fingerprints="${bastille_releasesdir}/${RELEASE}/usr/share/keys/pkg"
        fi

        # Verify trusted pkg keys
        if [ "${FREEBSD_BRANCH}" = "release" ]; then
            if [ ! -f "${host_fingerprintsdir}/trusted/awskms-${MAJOR_VERSION}" ]; then
                if ! fetch -o "${host_fingerprintsdir}/trusted" https://cgit.freebsd.org/src/tree/share/keys/pkgbase-${MAJOR_VERSION}/trusted/awskms-${MAJOR_VERSION}; then
                    ERRORS=$((ERRORS + 1))
                    error_notify "[ERROR]: Failed to fetch trusted pkg keys."
                    return 1
                fi
            fi
            if [ ! -f "${host_fingerprintsdir}/trusted/backup-signing-${MAJOR_VERSION}" ]; then
                if ! fetch -o "${host_fingerprintsdir}/trusted" https://cgit.freebsd.org/src/tree/share/keys/pkgbase-${MAJOR_VERSION}/trusted/backup-signing-${MAJOR_VERSION}; then
                    ERRORS=$((ERRORS + 1))
                    error_notify "[ERROR]: Failed to fetch trusted backup pkg keys."
                    return 1
                fi
            fi
        fi

        # Validate COPYRIGHT existence
        if [ -f "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" ]; then
            # Verify package sets
            bastille_pkgbase_packages=$(echo "${bastille_pkgbase_packages}" | sed "s/base-jail//")
            if [ -z "${bastille_pkgbase_packages}" ]; then
                info "\nBootstrap appears complete!"
                exit 0
            fi
        fi

        # Copy fingerprints into releasedir
        if ! mkdir -p "${release_fingerprintsdir}"; then
            ERRORS=$((ERRORS + 1))
            error_notify "[ERROR]: Faild to create fingerprints directory."
            return 1
        fi
        if ! cp -a "${host_fingerprintsdir}" "${release_fingerprintsdir}"; then
            ERRORS=$((ERRORS + 1))
            error_notify "[ERROR]: Failed to copy fingerprints directory."
            return 1
        fi

        info "\nUpdating ${repo_name} repository..."

        # Update PkgBase repo
        if ! pkg --rootdir "${bastille_releasesdir}/${RELEASE}" \
                 --repo-conf-dir="${repo_dir}" \
                 -o IGNORE_OSVERSION="yes" \
                 -o VERSION_MAJOR="${MAJOR_VERSION}" \
                 -o VERSION_MINOR="${MINOR_VERSION}" \
                 -o ABI="${abi}" \
                 -o ASSUME_ALWAYS_YES="yes" \
                 -o FINGERPRINTS="${fingerprints}" \
                 update -r "${repo_name}"; then

            ERRORS=$((ERRORS + 1))
            error_notify "[ERROR]: Failed to update repository: ${repo_name}"
        fi

        info "\nInstalling packages..."

        for package in ${bastille_pkgbase_packages}; do	

            # Check if package set is already installed
            if ! pkg --rootdir "${bastille_releasesdir}/${RELEASE}" info "FreeBSD-set-${package}" 2>/dev/null; then
                # Install package set
                if ! pkg --rootdir "${bastille_releasesdir}/${RELEASE}" \
                         --repo-conf-dir="${repo_dir}" \
                         -o IGNORE_OSVERSION="yes" \
                         -o VERSION_MAJOR="${MAJOR_VERSION}" \
                         -o VERSION_MINOR="${MINOR_VERSION}" \
                         -o ABI="${abi}" \
                         -o ASSUME_ALWAYS_YES="yes" \
                         -o FINGERPRINTS="${fingerprints}" \
                         install -r "${repo_name}" \
                         FreeBSD-set-"${package}"; then

                    ERRORS=$((ERRORS + 1))
                    error_continue "[ERROR]: Failed to install package set: ${package}"
                fi
            else
                info "\nPackage set already installed: ${package}"
            fi
        done

        # Cleanup on error
        if [ "${ERRORS}" -ne 0 ]; then
            return 1
        fi

        # Silence motd at login
        touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
        touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"
    fi
}

bootstrap_release_linux() {

    if [ "${PLATFORM_OS}" = "Linux/Debian" ] || [ "${PLATFORM_OS}" = "Linux/Ubuntu" ]; then
        # Fetch the Linux flavor
        if ! debootstrap --foreign --arch=${ARCH_BOOTSTRAP} --no-check-gpg ${LINUX_FLAVOR} "${bastille_releasesdir}"/${RELEASE}; then
            ERRORS=$((ERRORS + 1))
            error_notify "[ERROR]: Failed to fetch Linux release: ${LINUX_FLAVOR}"
            return 1
        fi

        # Set necessary settings
        case "${LINUX_FLAVOR}" in
            bionic|focal|jammy|buster|bullseye|bookworm|noble)
            info "Increasing APT::Cache-Start"
            echo "APT::Cache-Start 251658240;" > "${bastille_releasesdir}"/${RELEASE}/etc/apt/apt.conf.d/00aptitude
            ;;
        esac
    fi
}

bootstrap_template() {

    ## ${bastille_templatesdir}
    if [ ! -d "${bastille_templatesdir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_templatesdir_mountpoint}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/templates"
            fi
        else
            mkdir -p "${bastille_templatesdir}"
        fi
        ln -s "${bastille_sharedir}/templates/default" "${bastille_templatesdir}/default"
    fi

    ## define basic variables
    url=${BASTILLE_TEMPLATE_URL}
    user=${BASTILLE_TEMPLATE_USER}
    repo=${BASTILLE_TEMPLATE_REPO%.*} # Remove the trailing ".git"
    raw_template_dir=${bastille_templatesdir}/${user}/${repo}

    ## support for non-git
    if ! which -s git; then
        error_notify "Git not found."
        error_exit "Not yet implemented."
    else
        if [ ! -d "${raw_template_dir}/.git" ]; then
            git clone "${url}" "${raw_template_dir}" ||\
                error_notify "Clone unsuccessful."
        elif [ -d "${raw_template_dir}/.git" ]; then
            git -C "${raw_template_dir}" pull ||\
                error_notify "Template update unsuccessful."
        fi
    fi

    if [ ! -f ${raw_template_dir}/Bastillefile ]; then
        # Extract template in project/template format
        find "${raw_template_dir}" -type f -name Bastillefile | while read -r file; do
            template_dir="$(dirname ${file})"
            project_dir="$(dirname ${template_dir})"
            template_name="$(basename ${template_dir})"
            project_name="$(basename ${project_dir})"
            complete_template="${project_name}/${template_name}"
            cp -fR "${project_dir}" "${bastille_templatesdir}"
            bastille verify "${complete_template}"
        done

        # Remove the cloned repo
        if [ -n "${user}" ]; then
            rm -r "${bastille_templatesdir:?}/${user:?}"
        fi

    else
        # Verify a single template
        bastille verify "${user}/${repo}"
    fi
}

# Handle options.
PKGBASE=0
ERRORS=0
FETCH_PKG_KEYS=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -p|--pkgbase)
            PKGBASE=1
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    p) PKGBASE=1 ;;
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

RELEASE="${1}"
OPTION="${2}"
NOCACHEDIR=""
HW_MACHINE=$(sysctl hw.machine | awk '{ print $2 }')
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

bastille_root_check

# Validate if ZFS is enabled in rc.conf and bastille.conf.
if [ "$(sysrc -n zfs_enable)" = "YES" ] && ! checkyesno bastille_zfs_enable; then
    warn "ZFS is enabled in rc.conf but not bastille.conf. Do you want to continue? (N|y)"
    read answer
    case $answer in
        no|No|n|N|"")
            error_exit "[ERROR]: Missing ZFS parameters. See bastille_zfs_enable."
            ;;
        yes|Yes|y|Y) ;;
    esac
fi

# Validate ZFS parameters
if checkyesno bastille_zfs_enable; then
    ## check for the ZFS pool and bastille prefix
    if [ -z "${bastille_zfs_zpool}" ]; then
        error_exit "[ERROR]: Missing ZFS parameters. See bastille_zfs_zpool."
    elif [ -z "${bastille_zfs_prefix}" ]; then
        error_exit "[ERROR]: Missing ZFS parameters. See bastille_zfs_prefix."
    elif ! zfs list "${bastille_zfs_zpool}" > /dev/null 2>&1; then
        error_exit "[ERROR]: ${bastille_zfs_zpool} is not a ZFS pool."
    fi

    ## check for the ZFS dataset prefix if already exist
    if [ -d "/${bastille_zfs_zpool}/${bastille_zfs_prefix}" ]; then
        if ! zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}" > /dev/null 2>&1; then
            error_exit "[ERROR]: ${bastille_zfs_zpool}/${bastille_zfs_prefix} is not a ZFS dataset."
        fi
    fi
fi

# bootstrapping from aarch64/arm64 Debian or Ubuntu require a different value for ARCH
if [ "${HW_MACHINE_ARCH}" = "aarch64" ]; then
    HW_MACHINE_ARCH_LINUX="arm64"
else
    HW_MACHINE_ARCH_LINUX=${HW_MACHINE_ARCH}
fi

# Alternate RELEASE/ARCH fetch support(experimental)
if [ -n "${OPTION}" ] && [ "${OPTION}" != "${HW_MACHINE}" ] && [ "${OPTION}" != "update" ]; then
    # Supported architectures
    if [ "${OPTION}" = "--i386" ] || [ "${OPTION}" = "--32bit" ]; then
        HW_MACHINE="i386"
        HW_MACHINE_ARCH="i386"
    else
        error_exit "[ERROR]: Unsupported architecture."
    fi
fi

## allow override bootstrap URLs via environment variables
[ -n "${BASTILLE_URL_FREEBSD}" ] && bastille_url_freebsd="${BASTILLE_URL_FREEBSD}"
[ -n "${BASTILLE_URL_HARDENEDBSD}" ] && bastille_url_hardenedbsd="${BASTILLE_URL_HARDENEDBSD}"
[ -n "${BASTILLE_URL_MIDNIGHTBSD}" ] && bastille_url_midnightbsd="${BASTILLE_URL_MIDNIGHTBSD}"

## Filter sane release names
case "${RELEASE}" in
    [2-4].[0-9]*)
        ### MidnightBSD ###
        PLATFORM_OS="MidnightBSD"
        NAME_VERIFY=$(echo "${RELEASE}")
        UPSTREAM_URL="${bastille_url_midnightbsd}${HW_MACHINE_ARCH}/${NAME_VERIFY}"
        ;;
    *-current|*-CURRENT)
        ### FreeBSD ###
        PLATFORM_OS="FreeBSD"
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]+)\.[0-9](-CURRENT)$' | tr '[:lower:]' '[:upper:]')
        UPSTREAM_URL=$(echo "${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}" | sed 's/releases/snapshots/')
        FREEBSD_BRANCH="current"
        ;;
    *\.*-stable|*\.*-STABLE)
        ### FreeBSD ###
        PLATFORM_OS="FreeBSD"
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]+)\.[0-9](-STABLE)$' | tr '[:lower:]' '[:upper:]')
        UPSTREAM_URL=$(echo "${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}" | sed 's/releases/snapshots/')
        FREEBSD_BRANCH="current"
        ;;
    *-release|*-RELEASE|*-rc[1-9]|*-RC[1-9]|*-beta[1-9]|*-BETA[1-9])
        ### FreeBSD ###
        PLATFORM_OS="FreeBSD"
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([0-9]+)\.[0-9](-RELEASE|-RC[1-9]|-BETA[1-9])$' | tr '[:lower:]' '[:upper:]')
        UPSTREAM_URL="${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}"
        FREEBSD_BRANCH="release"
        ;;
    current|CURRENT)
        ### HardenedBSD ###
        PLATFORM_OS="HardenedBSD"
        NAME_VERIFY=$(echo "${RELEASE}" | sed 's/CURRENT/current/g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_VERIFY}/${HW_MACHINE}/${HW_MACHINE_ARCH}/installer/LATEST"
        ;;
    [1-9]*-stable|[1-9]*-STABLE)
        ### HardenedBSD ###
        PLATFORM_OS="HardenedBSD"
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]+)(-stable)$' | sed 's/STABLE/stable/g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_VERIFY}/${HW_MACHINE}/${HW_MACHINE_ARCH}/installer/LATEST"
        ;;
    http?://*/*/*)
        BASTILLE_TEMPLATE_URL=${1}
        BASTILLE_TEMPLATE_USER=$(echo "${1}" | awk -F / '{ print $4 }')
        BASTILLE_TEMPLATE_REPO=$(echo "${1}" | awk -F / '{ print $5 }')
        bootstrap_template
        exit 0
        ;;
    git@*:*/*)
        BASTILLE_TEMPLATE_URL=${1}
        git_repository=$(echo "${1}" | awk -F : '{ print $2 }')
        BASTILLE_TEMPLATE_USER=$(echo "${git_repository}" | awk -F / '{ print $1 }')
        BASTILLE_TEMPLATE_REPO=$(echo "${git_repository}" | awk -F / '{ print $2 }')
        bootstrap_template
        exit 0
        ;;
    ubuntu_bionic|bionic|ubuntu-bionic)
        PLATFORM_OS="Linux/Ubuntu"
        LINUX_FLAVOR="bionic"
        NAME_VERIFY="Ubuntu_1804"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    ubuntu_focal|focal|ubuntu-focal)
        PLATFORM_OS="Linux/Ubuntu"
        LINUX_FLAVOR="focal"
        NAME_VERIFY="Ubuntu_2004"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    ubuntu_jammy|jammy|ubuntu-jammy)
        PLATFORM_OS="Linux/Ubuntu"
        LINUX_FLAVOR="jammy"
        NAME_VERIFY="Ubuntu_2204"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    ubuntu_noble|noble|ubuntu-noble)
        PLATFORM_OS="Linux/Ubuntu"
        LINUX_FLAVOR="noble"
        NAME_VERIFY="Ubuntu_2404"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    debian_buster|buster|debian-buster|debian10|Debian10)
        PLATFORM_OS="Linux/Debian"
        LINUX_FLAVOR="buster"
        NAME_VERIFY="Debian10"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    debian_bullseye|bullseye|debian-bullseye|debian11|Debian11)
        PLATFORM_OS="Linux/Debian"
        LINUX_FLAVOR="bullseye"
        NAME_VERIFY="Debian11"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    debian_bookworm|bookworm|debian-bookworm|debian12|Debian12)
        PLATFORM_OS="Linux/Debian"
        LINUX_FLAVOR="bookworm"
        NAME_VERIFY="Debian12"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        ;;
    *)
        usage
        ;;
esac

# Bootstrap
case ${PLATFORM_OS} in
    FreeBSD|HardenedBSD|MidnightBSD)
        validate_release
        bootstrap_directories
        if [ "${PKGBASE}" -eq 1 ]; then
            bootstrap_release_pkgbase || cleanup_directories
        else
            bootstrap_release_legacy || cleanup_directories
        fi
        ;;
    Linux/Ubuntu|Linux/Debian)
        validate_release
        bootstrap_directories
        bootstrap_release_linux || cleanup_directories
        ;;
    *)
        error_exit "[ERROR]: Unsupported platform."
        ;;
esac

# Check for errors
if [ "${ERRORS}" -eq 0 ]; then

    # Check for OPTION=update
    case "${OPTION}" in
        update)
            bastille update "${RELEASE}"
            ;;
    esac

    # Success
    info "\nBootstrap successful."
    echo "See 'bastille --help' for available commands."
    echo
else
    error_exit "[ERROR]: Bootstrap failed!"
fi
