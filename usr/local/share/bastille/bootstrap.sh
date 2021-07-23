#!/bin/sh
#
# Copyright (c) 2018-2021, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille bootstrap [release|template] [update|arch]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

#Validate if ZFS is enabled in rc.conf and bastille.conf.
if [ "$(sysrc -n zfs_enable)" = "YES" ] && [ ! "${bastille_zfs_enable}" = "YES" ]; then
    warn "ZFS is enabled in rc.conf but not bastille.conf. Do you want to continue? (N|y)"
    read answer
    case $answer in
        no|No|n|N|"")
            error_exit "ERROR: Missing ZFS parameters. See bastille_zfs_enable."
            ;;
        yes|Yes|y|Y) ;;
    esac
fi

# Validate ZFS parameters.
if [ "${bastille_zfs_enable}" = "YES" ]; then
    ## check for the ZFS pool and bastille prefix
    if [ -z "${bastille_zfs_zpool}" ]; then
        error_exit "ERROR: Missing ZFS parameters. See bastille_zfs_zpool."
    elif [ -z "${bastille_zfs_prefix}" ]; then
        error_exit "ERROR: Missing ZFS parameters. See bastille_zfs_prefix."
    elif ! zfs list "${bastille_zfs_zpool}" > /dev/null 2>&1; then
        error_exit "ERROR: ${bastille_zfs_zpool} is not a ZFS pool."
    fi

    ## check for the ZFS dataset prefix if already exist
    if [ -d "/${bastille_zfs_zpool}/${bastille_zfs_prefix}" ]; then
        if ! zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}" > /dev/null 2>&1; then
            error_exit "ERROR: ${bastille_zfs_zpool}/${bastille_zfs_prefix} is not a ZFS dataset."
        fi
    fi
fi

validate_release_url() {
    ## check upstream url, else warn user
    if [ -n "${NAME_VERIFY}" ]; then
        RELEASE="${NAME_VERIFY}"
        if ! fetch -qo /dev/null "${UPSTREAM_URL}/MANIFEST" 2>/dev/null; then
            error_exit "Unable to fetch MANIFEST. See 'bootstrap urls'."
        fi
        info "Bootstrapping ${PLATFORM_OS} distfiles..."

        # Alternate RELEASE/ARCH fetch support
        if [ "${OPTION}" = "--i386" ] || [ "${OPTION}" = "--32bit" ]; then
            ARCH="i386"
            RELEASE="${RELEASE}-${ARCH}"
        fi

        bootstrap_directories
        bootstrap_release
    else
        usage
    fi
}

bootstrap_directories() {
    ## ensure required directories are in place

    ## ${bastille_prefix}
    if [ ! -d "${bastille_prefix}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ];then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_prefix}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}"
                chmod 0750 "${bastille_prefix}"
            fi
        else
            mkdir -p "${bastille_prefix}"
            chmod 0750 "${bastille_prefix}"
        fi
    fi

    ## ${bastille_backupsdir}
    if [ ! -d "${bastille_backupsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ];then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_backupsdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/backups"
                chmod 0750 "${bastille_backupsdir}"
            fi
        else
            mkdir -p "${bastille_backupsdir}"
            chmod 0750 "${bastille_backupsdir}"
        fi
    fi

    ## ${bastille_cachedir}
    if [ ! -d "${bastille_cachedir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_cachedir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache"
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_cachedir}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}"
            fi
        else
            mkdir -p "${bastille_cachedir}/${RELEASE}"
        fi
    ## create subsequent cache/XX.X-RELEASE datasets
    elif [ ! -d "${bastille_cachedir}/${RELEASE}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_cachedir}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/cache/${RELEASE}"
            fi
        else
            mkdir -p "${bastille_cachedir}/${RELEASE}"
        fi
    fi

    ## ${bastille_jailsdir}
    if [ ! -d "${bastille_jailsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_jailsdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails"
            fi
        else
            mkdir -p "${bastille_jailsdir}"
        fi
    fi

    ## ${bastille_logsdir}
    if [ ! -d "${bastille_logsdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_logsdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/logs"
            fi
        else
            mkdir -p "${bastille_logsdir}"
        fi
    fi

    ## ${bastille_templatesdir}
    if [ ! -d "${bastille_templatesdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_templatesdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/templates"
            fi
        else
            mkdir -p "${bastille_templatesdir}"
        fi
    fi

    ## ${bastille_releasesdir}
    if [ ! -d "${bastille_releasesdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_releasesdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases"
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_releasesdir}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"
            fi
        else
            mkdir -p "${bastille_releasesdir}/${RELEASE}"
        fi

    ## create subsequent releases/XX.X-RELEASE datasets
    elif [ ! -d "${bastille_releasesdir}/${RELEASE}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_releasesdir}/${RELEASE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/releases/${RELEASE}"
            fi
       else
           mkdir -p "${bastille_releasesdir}/${RELEASE}"
       fi
    fi
}

bootstrap_release() {
    ## if release exists quit, else bootstrap additional distfiles
    if [ -f "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" ]; then
        ## check distfiles list and skip existing cached files
        bastille_bootstrap_archives=$(echo "${bastille_bootstrap_archives}" | sed "s/base//")
        bastille_cached_files=$(ls "${bastille_cachedir}/${RELEASE}" | grep -v "MANIFEST" | tr -d ".txz")
        for distfile in ${bastille_cached_files}; do
            bastille_bootstrap_archives=$(echo "${bastille_bootstrap_archives}" | sed "s/${distfile}//")
        done

        ## check if release already bootstrapped, else continue bootstrapping
        if [ -z "${bastille_bootstrap_archives}" ]; then
            error_notify "Bootstrap appears complete."
        else
            info "Bootstrapping additional distfiles..."
        fi
    fi

    for _archive in ${bastille_bootstrap_archives}; do
        ## check if the dist files already exists then extract
        FETCH_VALIDATION="0"
        if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
            info "Extracting ${PLATFORM_OS} ${RELEASE} ${_archive}.txz."
            if /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"; then
                ## silence motd at container login
                touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
                touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"
            else
                error_exit "Failed to extract ${_archive}.txz."
            fi
        else
            ## get the manifest for dist files checksum validation
            if [ ! -f "${bastille_cachedir}/${RELEASE}/MANIFEST" ]; then
                fetch "${UPSTREAM_URL}/MANIFEST" -o "${bastille_cachedir}/${RELEASE}/MANIFEST" || FETCH_VALIDATION="1"
            fi

            if [ "${FETCH_VALIDATION}" -ne "0" ]; then
                ## perform cleanup only for stale/empty directories on failure
                if [ "${bastille_zfs_enable}" = "YES" ]; then
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
                    error_exit "Bootstrap failed."
                fi

                ## fetch for missing dist files
                if [ ! -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    if ! fetch "${UPSTREAM_URL}/${_archive}.txz" -o "${bastille_cachedir}/${RELEASE}/${_archive}.txz"; then
                        ## alert only if unable to fetch additional dist files
                        error_notify "Failed to fetch ${_archive}.txz."
                    fi
                fi

                ## compare checksums on the fetched dist files
                if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    SHA256_DIST=$(grep -w "${_archive}.txz" "${bastille_cachedir}/${RELEASE}/MANIFEST" | awk '{print $2}')
                    SHA256_FILE=$(sha256 -q "${bastille_cachedir}/${RELEASE}/${_archive}.txz")
                    if [ "${SHA256_FILE}" != "${SHA256_DIST}" ]; then
                        rm "${bastille_cachedir}/${RELEASE}/${_archive}.txz"
                        error_exit "Failed validation for ${_archive}.txz. Please retry bootstrap!"
                    else
                        info "Validated checksum for ${RELEASE}: ${_archive}.txz"
                        info "MANIFEST: ${SHA256_DIST}"
                        info "DOWNLOAD: ${SHA256_FILE}"
                    fi
                fi

                ## extract the fetched dist files
                if [ -f "${bastille_cachedir}/${RELEASE}/${_archive}.txz" ]; then
                    info "Extracting ${PLATFORM_OS} ${RELEASE} ${_archive}.txz."
                    if /usr/bin/tar -C "${bastille_releasesdir}/${RELEASE}" -xf "${bastille_cachedir}/${RELEASE}/${_archive}.txz"; then
                        ## silence motd at container login
                        touch "${bastille_releasesdir}/${RELEASE}/root/.hushlogin"
                        touch "${bastille_releasesdir}/${RELEASE}/usr/share/skel/dot.hushlogin"
                    else
                        error_exit "Failed to extract ${_archive}.txz."
                    fi
                fi
        fi
    done
    echo

    info "Bootstrap successful."
    info "See 'bastille --help' for available commands."
    echo
}

bootstrap_template() {

    ## ${bastille_templatesdir}
    if [ ! -d "${bastille_templatesdir}" ]; then
        if [ "${bastille_zfs_enable}" = "YES" ]; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_templatesdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/templates"
            fi
        else
            mkdir -p "${bastille_templatesdir}"
        fi
        ln -s "${bastille_sharedir}/templates/default" "${bastille_templatesdir}/default"
    fi

    ## define basic variables
    _url=${BASTILLE_TEMPLATE_URL}
    _user=${BASTILLE_TEMPLATE_USER}
    _repo=${BASTILLE_TEMPLATE_REPO}
    _template=${bastille_templatesdir}/${_user}/${_repo}

    ## support for non-git
    if ! which -s git; then
        error_notify "Git not found."
        error_exit "Not yet implemented."
    else
        if [ ! -d "${_template}/.git" ]; then
            git clone "${_url}" "${_template}" ||\
                error_notify "Clone unsuccessful."
        elif [ -d "${_template}/.git" ]; then
            git -C "${_template}" pull ||\
                error_notify "Template update unsuccessful."
        fi
    fi

    bastille verify "${_user}/${_repo}"
}

check_linux_prerequisites() {
    #check and install OS dependencies @hackacad
    if [ ! "$(sysrc -f /boot/loader.conf -n linprocfs_load)" = "YES" ] && [ ! "$(sysrc -f /boot/loader.conf -n linsysfs_load)" = "YES" ] && [ ! "$(sysrc -f /boot/loader.conf -n tmpfs_load)" = "YES" ]; then
        warn "linprocfs_load, linsysfs_load, tmpfs_load not enabled in /boot/loader.conf or linux_enable not active. Should I do that for you?  (N|y)"
        read  answer
        case $answer in
            [Nn][Oo]|[Nn]|"")
                error_exit "Exiting."
                ;;
            [Yy][Ee][Ss]|[Yy])
                info "Loading modules"
                kldload linux linux64 linprocfs linsysfs tmpfs
                info "Persisting modules"
                sysrc linux_enable=YES
                sysrc -f /boot/loader.conf linprocfs_load=YES
                sysrc -f /boot/loader.conf linsysfs_load=YES
                sysrc -f /boot/loader.conf tmpfs_load=YES
                ;;
        esac
    fi
}

ensure_debootstrap() {
    if ! which -s debootstrap; then
        warn "Debootstrap not found. Should it be installed? (N|y)"
        read  answer
        case $answer in
            [Nn][Oo]|[Nn]|"")
                error_exit "Exiting. You need to install debootstap before boostrapping a Linux jail."
                ;;
            [Yy][Ee][Ss]|[Yy])
                pkg install -y debootstrap
                ;;
        esac
    fi
}

HW_MACHINE=$(sysctl hw.machine | awk '{ print $2 }')
HW_MACHINE_ARCH=$(sysctl hw.machine_arch | awk '{ print $2 }')
RELEASE="${1}"
OPTION="${2}"

# Alternate RELEASE/ARCH fetch support(experimental)
if [ -n "${OPTION}" ] && [ "${OPTION}" != "${HW_MACHINE}" ] && [ "${OPTION}" != "update" ]; then
    # Supported architectures
    if [ "${OPTION}" = "--i386" ] || [ "${OPTION}" = "--32bit" ]; then
        HW_MACHINE="i386"
        HW_MACHINE_ARCH="i386"
    else
        error_exit "Unsupported architecture."
    fi
fi

## Filter sane release names
case "${1}" in
2.[0-9]*)
    ## check for MidnightBSD releases name
    NAME_VERIFY=$(echo "${RELEASE}")
    UPSTREAM_URL="${bastille_url_midnightbsd}${HW_MACHINE_ARCH}/${NAME_VERIFY}"
    PLATFORM_OS="MidnightBSD"
    validate_release_url
    ;;
*-CURRENT|*-current)
    ## check for FreeBSD releases name
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-CURRENT)$' | tr '[:lower:]' '[:upper:]')
    UPSTREAM_URL=$(echo "${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}" | sed 's/releases/snapshots/')
    PLATFORM_OS="FreeBSD"
    validate_release_url
    ;;
*-RELEASE|*-release|*-RC1|*-rc1|*-RC2|*-rc2|*-RC3|*-rc3|*-RC4|*-rc4|*-RC5|*-rc5|*-BETA1|*-BETA2|*-BETA3|*-BETA4|*-BETA5)
    ## check for FreeBSD releases name
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-5]|-BETA[1-5])$' | tr '[:lower:]' '[:upper:]')
    UPSTREAM_URL="${bastille_url_freebsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_VERIFY}"
    PLATFORM_OS="FreeBSD"
    validate_release_url
    ;;
*-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
    ## check for HardenedBSD releases name(previous infrastructure, keep for reference)
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '^([1-9]{2,2})(-stable-last)$' | sed 's/STABLE/stable/g' | sed 's/last/LAST/g')
    UPSTREAM_URL="${bastille_url_hardenedbsd}${HW_MACHINE}/${HW_MACHINE_ARCH}/hardenedbsd-${NAME_VERIFY}"
    PLATFORM_OS="HardenedBSD"
    validate_release_url
    ;;
*-stable-build-[0-9]*|*-STABLE-BUILD-[0-9]*)
    ## check for HardenedBSD(specific stable build releases)
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '([0-9]{1,2})(-stable-build)-([0-9]{1,3})$' | sed 's/BUILD/build/g' | sed 's/STABLE/stable/g')
    NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/-build-[0-9]\{1,3\}//g')
    NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/[0-9]\{1,2\}-stable-//g')
    UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_BUILD}"
    PLATFORM_OS="HardenedBSD"
    validate_release_url
    ;;
*-stable-build-latest|*-stable-BUILD-LATEST|*-STABLE-BUILD-LATEST)
    ## check for HardenedBSD(latest stable build release)
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '([0-9]{1,2})(-stable-build-latest)$' | sed 's/STABLE/stable/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
    NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/-BUILD-LATEST//g')
    NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/[0-9]\{1,2\}-stable-//g')
    UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_BUILD}"
    PLATFORM_OS="HardenedBSD"
    validate_release_url
    ;;
current-build-[0-9]*|CURRENT-BUILD-[0-9]*)
    ## check for HardenedBSD(specific current build releases)
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '(current-build)-([0-9]{1,3})' | sed 's/BUILD/build/g' | sed 's/CURRENT/current/g')
    NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/current-.*/current/g')
    NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/current-//g')
    UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_BUILD}"
    PLATFORM_OS="HardenedBSD"
    validate_release_url
    ;;
current-build-latest|current-BUILD-LATEST|CURRENT-BUILD-LATEST)
    ## check for HardenedBSD(latest current build release)
    NAME_VERIFY=$(echo "${RELEASE}" | grep -iwE '(current-build-latest)' | sed 's/CURRENT/current/g' | sed 's/build/BUILD/g' | sed 's/latest/LATEST/g')
    NAME_RELEASE=$(echo "${NAME_VERIFY}" | sed 's/current-.*/current/g')
    NAME_BUILD=$(echo "${NAME_VERIFY}" | sed 's/current-//g')
    UPSTREAM_URL="${bastille_url_hardenedbsd}${NAME_RELEASE}/${HW_MACHINE}/${HW_MACHINE_ARCH}/${NAME_BUILD}"
    PLATFORM_OS="HardenedBSD"
    validate_release_url
    ;;
http?://*/*/*)
    BASTILLE_TEMPLATE_URL=${1}
    BASTILLE_TEMPLATE_USER=$(echo "${1}" | awk -F / '{ print $4 }')
    BASTILLE_TEMPLATE_REPO=$(echo "${1}" | awk -F / '{ print $5 }')
    bootstrap_template
    ;;
#adding Ubuntu Bionic as valid "RELEASE" for POC @hackacad
ubuntu_bionic|bionic|ubuntu-bionic)
    check_linux_prerequisites
    ensure_debootstrap
    debootstrap --foreign --arch=amd64 --no-check-gpg bionic "${bastille_releasesdir}"/Ubuntu_1804
    echo "APT::Cache-Start 251658240;" > "${bastille_releasesdir}"/Ubuntu_1804/etc/apt/apt.conf.d/00aptitude
    ;;
ubuntu_focal|focal|ubuntu-focal)
    check_linux_prerequisites
    ensure_debootstrap
    debootstrap --foreign --arch=amd64 --no-check-gpg focal "${bastille_releasesdir}"/Ubuntu_2004
    ;;
debian_stretch|stretch|debian-stretch)
    check_linux_prerequisites
    ensure_debootstrap
    debootstrap --foreign --arch=amd64 --no-check-gpg stretch "${bastille_releasesdir}"/Debian9
    echo "Increasing APT::Cache-Start"
    echo "APT::Cache-Start 251658240;" > "${bastille_releasesdir}"/Debian9/etc/apt/apt.conf.d/00aptitude
    ;;
*)
    usage
    ;;
esac



case "${OPTION}" in
update)
    bastille update "${RELEASE}"
    ;;
esac
