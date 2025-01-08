#!/bin/sh
# Copyright (c) 2018-2024, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille etcupdate [option(s)] [TARGET|bootstrap] RELEASE"
    cat << EOF
    Options:

    -d | --dry-run          Show output, but do not apply.

EOF
    exit 1
}

bootstrap_etc_release() {
    local _release="${1}"
    local _current="$(sysrc -f /usr/local/etc/bastille/bastille.conf bastille_bootstrap_archives | awk -F': ' '{print $2}')"
    if ls -A "${bastille_releasesdir}/${_release}/usr/src" 2>/dev/null; then
        sysrc -f /usr/local/etc/bastille/bastille.conf bastille_bootstrap_archives=src
        if ! bastille bootstrap "${_release}"; then
            sysrc -f /usr/local/etc/bastille/bastille.conf bastille_bootstrap_archives="${_current}"
            error_exit "Failed to bootstrap etcupdate \"${_release}\""
        else
            sysrc -f /usr/local/etc/bastille/bastille.conf bastille_bootstrap_archives="${_current}"
        fi
    fi
}

bootstrap_etc_tarball() {
    local _release="${1}"
    if [ ! -f ${bastille_cachedir}/${_release}.tbz2 ]; then
        echo "Building tarball, please wait..."
        if ! etcupdate build -d /tmp/etcupdate -s ${bastille_releasesdir}/${_release}/usr/src ${bastille_cachedir}/${_release}.tbz2; then
            error_exit "Failed to build etcupdate tarball \"${_release}.tbz2\""
        else
            info "Etcupdate bootstrap complete: \"${_release}\""
        fi
    else
        info "Etcupdate release has already been prepared for application: \"${_release}\""
        exit 0
    fi
}

update_jail_etc() {
    local _jail="${1}"
    local _release="${2}"
    if [ ! -f ${bastille_cachedir}/${_release}.tbz2 ]; then
        error_exit "Error: Please run \"bastille etcupdate bootstrap RELEASE\" first."
    fi
    if [ "${DRY_RUN}" -eq 1 ]; then
        info "[_jail]: --dry-run"
        etcupdate -n -D "${bastille_jailsdir}"/"${_jail}"/root -t ${bastille_cachedir}/${_release}.tbz2
    else
        info "[_jail]:"
        etcupdate -D "${bastille_jailsdir}"/"${_jail}"/root -t ${bastille_cachedir}/${_release}.tbz2
    fi
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -d|--dry-run)
            if [ -z "${2}" ] || [ -z "${3}" ]; then
                usage
            else
                DRY_RUN=1
                shift
            fi
            ;;
        -*)
            error_exit "Unknown option: \"${1}\""
            ;;
        bootstrap)
            if [ -z "${2}" ]; then
                usage
            else
                RELEASE="${2}"
                bootstrap_etc_release "${RELEASE}"
                bootstrap_etc_tarball "${RELEASE}"
                shift $#
            fi
            ;;
        *)
            if [ -z "${2}" ]; then
                usage
            else
                TARGET="${1}"
                RELEASE="${2}"
            fi
            if [ -z "${DRY_RUN}" ]; then
                DRY_RUN=0
            fi
            set_target_single "${TARGET}"
            update_jail_etc "${TARGET}" "${RELEASE}"
            shift "$#"
            ;;
    esac
done
