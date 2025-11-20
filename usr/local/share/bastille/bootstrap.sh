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
    error_notify "Usage: bastille bootstrap [option(s)] RELEASE|TEMPLATE [update|arch]"
    cat << EOF

    Options:

    -p | --pkgbase     Bootstrap using pkgbase (15.0-RELEASE and above).
    -x | --debug       Enable debug mode.

EOF
    exit 1
}

validate_release() {

    MAJOR_VERSION=$(echo ${RELEASE} | grep -Eo '^[0-9]+')
    MINOR_VERSION=$(echo ${RELEASE} | sed -E 's/^[0-9]+\.([0-9]+)-.*$/\1/')

    if [ "${PKGBASE}" -eq 1 ] && [ "${MAJOR_VERSION}" -le 14 ]; then
        error_exit "[ERROR]: Pkgbase is not supported for release: ${RELEASE}"
    fi

    if [ "${MAJOR_VERSION}" -ge 16 ]; then
        PKGBASE=1
    fi

    if [ "${PLATFORM_OS}" != "FreeBSD" ] && [ "${PKGBASE}" -eq 1 ]; then
        error_exit "[ERROR]: Pkgbase can only be used with FreeBSD releases."
    fi

    info "\nBootstrapping release: ${RELEASE}..."

    ## check upstream url, else warn user
    if [ -n "${NAME_VERIFY}" ]; then
        # Alternate RELEASE/ARCH fetch support
        if [ "${OPTION}" = "--i386" ] || [ "${OPTION}" = "--32bit" ]; then
            ARCH="i386"
            RELEASE="${RELEASE}-${ARCH}"
        fi

        if [ "${PKGBASE}" -eq 1 ]; then
            info "\nUsing PkgBase..."
            bootstrap_directories
            bootstrap_pkgbase_release
        elif [ "${PKGBASE}" -eq 0 ]; then
            info "\nFetching ${PLATFORM_OS} distfiles..."
            if ! fetch -qo /dev/null "${UPSTREAM_URL}/MANIFEST" 2>/dev/null; then
                error_exit "Unable to fetch MANIFEST. See 'bootstrap urls'."
            fi
            bootstrap_directories
            bootstrap_release
        fi
    else
        usage
    fi
}

bootstrap_directories() {

    # Ensure required directories are in place

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

bootstrap_pkgbase_release() {

    local abi="${PLATFORM_OS}:${MAJOR_VERSION}:${HW_MACHINE_ARCH}"
    local fingerprints="${bastille_releasesdir}/${RELEASE}/usr/share/keys/pkg"
    local host_fingerprintsdir="/usr/share/keys/pkg"
    local release_fingerprintsdir="${bastille_releasesdir}/${RELEASE}/usr/share/keys"
    if [ "${FREEBSD_BRANCH}" = "release" ]; then
        local repo_name="FreeBSD-base-release-${MINOR_VERSION}"
    elif [ "${FREEBSD_BRANCH}" = "current" ]; then
        local repo_name="FreeBSD-base-latest"
    fi
    local repo_dir="${bastille_sharedir}/pkgbase"

    ## If release exists quit, else bootstrap additional packages
    if [ -f "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" ]; then

        ## check pkgbase package list and skip existing sets
        bastille_pkgbase_packages=$(echo "${bastille_pkgbase_packages}" | sed "s/base-jail//")

        ## check if release already bootstrapped, else continue bootstrapping
        if [ -z "${bastille_pkgbase_packages}" ]; then
            info "\nBootstrap appears complete!"
            exit 0
        else
            info "\nFetching additional packages..."
        fi
    fi

    # Copy fingerprints into releasedir
    if ! mkdir -p "${release_fingerprintsdir}"; then
        error_exit "[ERROR]: Faild to create fingerprints directory."
    fi
    if ! cp -a "${host_fingerprintsdir}" "${release_fingerprintsdir}"; then
        error_exit "[ERROR]: Failed to copy fingerprints directory."
    fi

    # Ensure repo is up to date
    if ! pkg --rootdir "${bastille_releasesdir}/${RELEASE}" \
             --repo-conf-dir="${repo_dir}" \
             -o IGNORE_OSVERSION="yes" \
             -o ABI="${abi}" \
             -o ASSUME_ALWAYS_YES="yes" \
             -o FINGERPRINTS="${fingerprints}" \
             update -r "${repo_name}"; then
        error_notify "[ERROR]: Failed to update repository: ${repo_name}"
    fi

    # Reset ERROR_COUNT
    ERROR_COUNT="0"

    for package in ${bastille_pkgbase_packages}; do	

        # Check if package set is already installed
        if ! pkg --rootdir "${bastille_releasesdir}/${RELEASE}" info "FreeBSD-set-${package}" 2>/dev/null; then
            # Install package set
            if ! pkg --rootdir "${bastille_releasesdir}/${RELEASE}" \
                     --repo-conf-dir="${repo_dir}" \
                     -o IGNORE_OSVERSION="yes" \
                     -o ABI="${abi}" \
                     -o ASSUME_ALWAYS_YES="yes" \
                     -o FINGERPRINTS="${fingerprints}" \
                     install -r "${repo_name}" \
                     freebsd-set-"${package}"; then

                ERROR_COUNT=$((ERROR_COUNT + 1))
            fi
        else
            error_continue "[ERROR]: Package set already installed: ${package}"
        fi
    done

    # Cleanup if failed
    if [ "${ERROR_COUNT}" -ne "0" ]; then
        ## perform cleanup only for stale/empty directories on failure
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ ! "$(ls -A "${bastille_releasesdir}/${RELEASE}")" ]; then
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"
                fi
            fi
        elif [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
            if [ ! "$(ls -A "${bastille_releasesdir}/${RELEASE}")" ]; then
                rm -rf "${bastille_releasesdir:?}/${RELEASE}"
            fi
        fi
        error_exit "[ERROR]: Bootstrap failed."
    else

        # Silence motd at login
        touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
        touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"

        # Success
        info "\nBootstrap successful."
        echo "See 'bastille --help' for available commands."

    fi
}

bootstrap_release() {

    ## if release exists quit, else bootstrap additional distfiles
    if [ -f "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" ]; then
        ## check distfiles list and skip existing cached files
        bastille_bootstrap_archives=$(echo "${bastille_bootstrap_archives}" | sed "s/base//")
        # TODO check how to handle this
        # shellcheck disable=SC2010
        bastille_cached_files=$(ls "${bastille_cachedir}/${RELEASE}" | grep -v "MANIFEST" | tr -d ".txz")
        for distfile in ${bastille_cached_files}; do
            bastille_bootstrap_archives=$(echo "${bastille_bootstrap_archives}" | sed "s/${distfile}//")
        done

        ## check if release already bootstrapped, else continue bootstrapping
        if [ -z "${bastille_bootstrap_archives}" ]; then
            info "\nBootstrap appears complete!\n"
            exit 0
        else
            info "\nFetching additional distfiles..."
        fi
    fi

    for _archive in ${bastille_bootstrap_archives}; do
        ## check if the dist files already exists then extract
        FETCH_VALIDATION="0"
        if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
            info "\nExtracting ${PLATFORM_OS} ${RELEASE} ${_archive}.txz..."
            if /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"; then
                ## silence motd at container login
                touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
                touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"
            else
                error_exit "[ERROR]: Failed to extract ${_archive}.txz."
            fi
        else
            ## get the manifest for dist files checksum validation
            if [ ! -f "${bastille_cachedir}/${RELEASE}/MANIFEST" ]; then
                fetch "${UPSTREAM_URL}/MANIFEST" -o "${bastille_cachedir}/${RELEASE}/MANIFEST" || FETCH_VALIDATION="1"
            fi

            if [ "${FETCH_VALIDATION}" -ne "0" ]; then
                ## perform cleanup only for stale/empty directories on failure
                if checkyesno bastille_zfs_enable; then
                    if [ -n "${bastille_zfs_zpool}" ]; then
                        if [ ! "$(ls -A "${bastille_cachedir}/${RELEASE}")" ]; then
                            zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}"
                        fi
                        if [ ! "$(ls -A "${bastille_releasesdir}/${RELEASE}")" ]; then
                            zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"
                        fi
                        fi
                    fi
                    if [ -d "${bastille_cachedir}/${RELEASE}" ]; then
                        if [ ! "$(ls -A "${bastille_cachedir}/${RELEASE}")" ]; then
                            rm -rf "${bastille_cachedir:?}/${RELEASE}"
                        fi
                    fi
                    if [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
                        if [ ! "$(ls -A "${bastille_releasesdir}/${RELEASE}")" ]; then
                            rm -rf "${bastille_releasesdir:?}/${RELEASE}"
                        fi
                    fi
                    error_exit "[ERROR]: Bootstrap failed."
                fi

                ## fetch for missing dist files
                if [ ! -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    if ! fetch "${UPSTREAM_URL}/${_archive}.txz" -o "${bastille_cachedir}/${RELEASE}/${_archive}.txz"; then
                        ## alert only if unable to fetch additional dist files
                        error_exit "[ERROR]: Failed to fetch ${_archive}.txz"
                    fi
                fi

                ## compare checksums on the fetched dist files
                if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    SHA256_DIST=$(grep -w "${_archive}.txz" "${bastille_cachedir}/${RELEASE}/MANIFEST" | awk '{print $2}')
                    SHA256_FILE=$(sha256 -q "${bastille_cachedir}/${RELEASE}/${_archive}.txz")
                    if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
                        rm "${bastille_cachedir}/${RELEASE}/${_archive}.txz"
                        error_exit "[ERROR]: Failed validation for ${_archive}.txz. Please retry bootstrap!"
                    else
                        info "\nValidated checksum for ${RELEASE}: ${_archive}.txz"
                        echo "MANIFEST: ${SHA256_DIST}"
                        echo "DOWNLOAD: ${SHA256_FILE}"
                    fi
                fi

                ## extract the fetched dist files
                if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    info "\nExtracting ${PLATFORM_OS} ${RELEASE} ${_archive}.txz..."
                    if /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"; then
                        ## silence motd at container login
                        touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
                        touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"
                    else
                        error_exit "[ERROR]: Failed to extract ${_archive}.txz."
                    fi
                fi
        fi
    done

    info "\nBootstrap successful."
    echo "See 'bastille --help' for available commands."

}

debootstrap_release() {

    # Make sure to check/bootstrap directories first.
    NOCACHEDIR=1
    RELEASE="${DIR_BOOTSTRAP}"
    bootstrap_directories

    #check and install OS dependencies @hackacad
    #ToDo: add function 'linux_pre' for sysrc etc.

    required_mods="fdescfs linprocfs linsysfs tmpfs"
    linuxarc_mods="linux linux64"
    for _req_kmod in ${required_mods}; do
        if [ ! "$(sysrc -f /boot/loader.conf -qn ${_req_kmod}_load)" = "YES" ] && \
            [ ! "$(sysrc -f /boot/loader.conf.local -qn ${_req_kmod}_load)" = "YES" ]; then
            warn "${_req_kmod} not enabled in /boot/loader.conf, Should I do that for you?  (N|y)"
            read  answer
            case "${answer}" in
                [Nn][Oo]|[Nn]|"")
                    error_exit "Cancelled, Exiting."
                    ;;
                [Yy][Ee][Ss]|[Yy])
                    # Skip already loaded known modules.
                    if ! kldstat -m ${_req_kmod} >/dev/null 2>&1; then
                        info "\nLoading kernel module: ${_req_kmod}"
                        kldload -v ${_req_kmod}
                    fi
                    info "\nPersisting module: ${_req_kmod}"
                    sysrc -f /boot/loader.conf ${_req_kmod}_load=YES
                ;;
            esac
        else
            # If already set in /boot/loader.conf, check and try to load the module.
            if ! kldstat -m ${_req_kmod} >/dev/null 2>&1; then
                info "\nLoading kernel module: ${_req_kmod}"
                kldload -v ${_req_kmod}
            fi
        fi
    done

        # Mandatory Linux modules/rc.
        for _lin_kmod in ${linuxarc_mods}; do
            if ! kldstat -n ${_lin_kmod} >/dev/null 2>&1; then
                info "\nLoading kernel module: ${_lin_kmod}"
                kldload -v ${_lin_kmod}
            fi
        done

        if [ ! "$(sysrc -qn linux_enable)" = "YES" ] && \
            [ ! "$(sysrc -f /etc/rc.conf.local -qn linux_enable)" = "YES" ]; then
            sysrc linux_enable=YES
        fi

    if ! which -s debootstrap; then
        warn "Debootstrap not found. Should it be installed? (N|y)"
        read  answer
        case $answer in
            [Nn][Oo]|[Nn]|"")
                error_exit "[ERROR]: debootstrap is required for boostrapping a Linux jail."
                ;;
            [Yy][Ee][Ss]|[Yy])
                pkg install -y debootstrap
                ;;
        esac
    fi

    # Fetch the Linux flavor
    info "\nFetching ${PLATFORM_OS} distfiles..."
    if ! debootstrap --foreign --arch=${ARCH_BOOTSTRAP} --no-check-gpg ${LINUX_FLAVOR} "${bastille_releasesdir}"/${DIR_BOOTSTRAP}; then

        ## perform cleanup only for stale/empty directories on failure
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                if [ ! "$(ls -A "${bastille_releasesdir}/${DIR_BOOTSTRAP}")" ]; then
                    zfs destroy "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${DIR_BOOTSTRAP}"
                fi
            fi
        fi

        if [ -d "${bastille_releasesdir}/${DIR_BOOTSTRAP}" ]; then
            if [ ! "$(ls -A "${bastille_releasesdir}/${DIR_BOOTSTRAP}")" ]; then
                rm -rf "${bastille_releasesdir:?}/${DIR_BOOTSTRAP}"
            fi
        fi
        error_exit "[ERROR]: Bootstrap failed."
    fi

    case "${LINUX_FLAVOR}" in
        bionic|focal|jammy|buster|bullseye|bookworm|noble)
        info "Increasing APT::Cache-Start"
        echo "APT::Cache-Start 251658240;" > "${bastille_releasesdir}"/${DIR_BOOTSTRAP}/etc/apt/apt.conf.d/00aptitude
        ;;
    esac

    info "\nBootstrap successful."
    info "\nSee 'bastille --help' for available commands."
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
    _url=${BASTILLE_TEMPLATE_URL}
    _user=${BASTILLE_TEMPLATE_USER}
    _repo=${BASTILLE_TEMPLATE_REPO%.*} # Remove the trailing ".git"
    _raw_template_dir=${bastille_templatesdir}/${_user}/${_repo}

    ## support for non-git
    if ! which -s git; then
        error_notify "Git not found."
        error_exit "Not yet implemented."
    else
        if [ ! -d "${_raw_template_dir}/.git" ]; then
            git clone "${_url}" "${_raw_template_dir}" ||\
                error_notify "Clone unsuccessful."
        elif [ -d "${_raw_template_dir}/.git" ]; then
            git -C "${_raw_template_dir}" pull ||\
                error_notify "Template update unsuccessful."
        fi
    fi

    if [ ! -f ${_raw_template_dir}/Bastillefile ]; then
        # Extract template in project/template format
        find "${_raw_template_dir}" -type f -name Bastillefile | while read -r _file; do
            _template_dir="$(dirname ${_file})"
            _project_dir="$(dirname ${_template_dir})"
            _template_name="$(basename ${_template_dir})"
            _project_name="$(basename ${_project_dir})"
            _complete_template="${_project_name}/${_template_name}"
            cp -fR "${_project_dir}" "${bastille_templatesdir}"
            bastille verify "${_complete_template}"
        done

        # Remove the cloned repo
        if [ -n "${_user}" ]; then
            rm -r "${bastille_templatesdir:?}/${_user:?}"
        fi

    else
        # Verify a single template
        bastille verify "${_user}/${_repo}"
    fi
}

# Handle options.
PKGBASE=0
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
NOCACHEDIR=
HW_MACHINE=$(sysctl hw.machine | awk '{ print $2 }')
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')

bastille_root_check

#Validate if ZFS is enabled in rc.conf and bastille.conf.
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
# create a new variable
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
        ## check for MidnightBSD releases name
        NAME_VERIFY=$(echo "${RELEASE}")
        UPSTREAM_URL="${bastille_url_midnightbsd}${HW_MACHINE_ARCH}/${NAME_VERIFY}"
        PLATFORM_OS="MidnightBSD"
        validate_release
        ;;
    *-CURRENT|*-current)
        ## check for FreeBSD releases name
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-CURRENT)$' | tr '[:lower:]' '[:upper:]')
        UPSTREAM_URL=$(echo "${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}" | sed 's/releases/snapshots/')
        PLATFORM_OS="FreeBSD"
        FREEBSD_BRANCH="current"
        validate_release
        ;;
    *-RELEASE|*-release|*-RC[1-9]|*-rc[1-9]|*-BETA[1-9])
        ## check for FreeBSD releases name
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([0-9]{1,2})\.[0-9](-RELEASE|-RC[1-9]|-BETA[1-9])$' | tr '[:lower:]' '[:upper:]')
        UPSTREAM_URL="${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}"
        PLATFORM_OS="FreeBSD"
        FREEBSD_BRANCH="release"
        validate_release
        ;;
    *-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
        ## check for HardenedBSD releases name(previous infrastructure, keep for reference)
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})(-stable-last)$' | sed 's/STABLE/stable/g' | sed 's/last/LAST/g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/hardenedbsd-${NAME_VERIFY}"
        PLATFORM_OS="HardenedBSD"
        validate_release
        ;;
    *-stable-build-[0-9]*|*-STABLE-BUILD-[0-9]*)
        ## check for HardenedBSD(specific stable build releases)
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '([0-9]{1,2})(-stable-build)-([0-9]{1,3})$' | sed 's/BUILD/build/g' | sed 's/STABLE/stable/g')
        NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/-build-[0-9]\{1,3\}//g')
        NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/[0-9]\{1,2\}-stable-//g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_BUILD}"
        PLATFORM_OS="HardenedBSD"
        validate_release
        ;;
    *-stable-build-latest|*-stable-BUILD-LATEST|*-STABLE-BUILD-LATEST)
        ## check for HardenedBSD(latest stable build release)
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '([0-9]{1,2})(-stable-build-latest)$' | sed 's/STABLE/stable/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
        NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/-BUILD-LATEST//g')
        NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/[0-9]\{1,2\}-stable-BUILD-//g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/installer/${NAME_BUILD}"
        PLATFORM_OS="HardenedBSD"
        validate_release
        ;;
    current-build-[0-9]*|CURRENT-BUILD-[0-9]*)
        ## check for HardenedBSD(specific current build releases)
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '(current-build)-([0-9]{1,3})' | sed 's/BUILD/build/g' | sed 's/CURRENT/current/g')
        NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/current-.*/current/g')
        NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/current-//g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_BUILD}"
        PLATFORM_OS="HardenedBSD"
        validate_release
        ;;
    current-build-latest|current-BUILD-LATEST|CURRENT-BUILD-LATEST)
        ## check for HardenedBSD(latest current build release)
        NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '(current-build-latest)' | sed 's/CURRENT/current/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
        NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/current-.*/current/g')
        NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/current-BUILD-//g')
        UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/installer/${NAME_BUILD}"
        PLATFORM_OS="HardenedBSD"
        validate_release
        ;;
    http?://*/*/*)
        BASTILLE_TEMPLATE_URL=${1}
        BASTILLE_TEMPLATE_USER=$(echo "${1}" | awk -F / '{ print $4 }')
        BASTILLE_TEMPLATE_REPO=$(echo "${1}" | awk -F / '{ print $5 }')
        bootstrap_template
        ;;
    git@*:*/*)
        BASTILLE_TEMPLATE_URL=${1}
        git_repository=$(echo "${1}" | awk -F : '{ print $2 }')
        BASTILLE_TEMPLATE_USER=$(echo "${git_repository}" | awk -F / '{ print $1 }')
        BASTILLE_TEMPLATE_REPO=$(echo "${git_repository}" | awk -F / '{ print $2 }')
        bootstrap_template
        ;;
    #adding Ubuntu Bionic as valid "RELEASE" for POC @hackacad
    ubuntu_bionic|bionic|ubuntu-bionic)
        PLATFORM_OS="Ubuntu/Linux"
        LINUX_FLAVOR="bionic"
        DIR_BOOTSTRAP="Ubuntu_1804"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    ubuntu_focal|focal|ubuntu-focal)
        PLATFORM_OS="Ubuntu/Linux"
        LINUX_FLAVOR="focal"
        DIR_BOOTSTRAP="Ubuntu_2004"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    ubuntu_jammy|jammy|ubuntu-jammy)
        PLATFORM_OS="Ubuntu/Linux"
        LINUX_FLAVOR="jammy"
        DIR_BOOTSTRAP="Ubuntu_2204"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    ubuntu_noble|noble|ubuntu-noble)
        PLATFORM_OS="Ubuntu/Linux"
        LINUX_FLAVOR="noble"
        DIR_BOOTSTRAP="Ubuntu_2404"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    debian_buster|buster|debian-buster)
        PLATFORM_OS="Debian/Linux"
        LINUX_FLAVOR="buster"
        DIR_BOOTSTRAP="Debian10"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    debian_bullseye|bullseye|debian-bullseye)
        PLATFORM_OS="Debian/Linux"
        LINUX_FLAVOR="bullseye"
        DIR_BOOTSTRAP="Debian11"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    debian_bookworm|bookworm|debian-bookworm)
        PLATFORM_OS="Debian/Linux"
        LINUX_FLAVOR="bookworm"
        DIR_BOOTSTRAP="Debian12"
        ARCH_BOOTSTRAP=${HW_MACHINE_ARCH_LINUX}
        debootstrap_release
        ;;
    *)
        usage
        ;;
esac

if [ "${PKGBASE}" -eq 0 ]; then
    case "${OPTION}" in
        update)
            bastille update "${RELEASE}"
            ;;
    esac
fi