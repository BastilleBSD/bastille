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
    error_notify "Usage: bastille convert [option(s)] TARGET"

    cat << EOF
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
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
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
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

if [ "$#" -ne 1 ]; then
    usage
fi

TARGET="${1}"

bastille_root_check
set_target_single "${TARGET}"
check_target_is_stopped "${TARGET}" || if [ "${AUTO}" -eq 1 ]; then
    bastille stop "${TARGET}"
else   
    error_notify "Jail is running."
    error_exit "Use [-a|--auto] to auto-stop the jail."
fi

convert_symlinks() {
    # Work with the symlinks, revert on first cp error
    if [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
        # Retrieve old symlinks temporarily
        for _link in ${SYMLINKS}; do
            if [ -L "${_link}" ]; then
                mv "${_link}" "${_link}.old"
            fi
        done

        # Copy new files to destination jail
        info "Copying required base files to container..."
        for _link in ${SYMLINKS}; do
            if [ ! -d "${_link}" ]; then
                if [ -d "${bastille_releasesdir}/${RELEASE}/${_link}" ]; then
                    cp -a "${bastille_releasesdir}/${RELEASE}/${_link}" "${bastille_jailsdir}/${TARGET}/root/${_link}"
                fi
                if [ "$?" -ne 0 ]; then
                    revert_convert
                fi
            fi
        done

        # Remove the old symlinks on success
        for _link in ${SYMLINKS}; do
            if [ -L "${_link}.old" ]; then
                rm -r "${_link}.old"
            fi
        done
    else
        error_exit "Release must be bootstrapped first. See 'bastille bootstrap'."
    fi
}

revert_convert() {
    # Revert the conversion on first cp error
    error_notify "A problem has occurred while copying the files. Reverting changes..."
    for _link in ${SYMLINKS}; do
        if [ -d "${_link}" ]; then
            chflags -R noschg "${bastille_jailsdir}/${TARGET}/root/${_link}"
            rm -rf "${bastille_jailsdir}/${TARGET}/root/${_link}"
        fi
    done

    # Restore previous symlinks
    for _link in ${SYMLINKS}; do
        if [ -L "${_link}.old" ]; then
            mv "${_link}.old" "${_link}"
        fi
    done
    error_exit "Changes for '${TARGET}' has been reverted."
}

start_convert() {
    # Attempt container conversion and handle some errors
    DATE=$(date)
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        info "Converting '${TARGET}' into a thickjail. This may take a while..."

        # Set some variables
        RELEASE=$(grep -w "${bastille_releasesdir}/.* ${bastille_jailsdir}/${TARGET}/root/.bastille" ${bastille_jailsdir}/${TARGET}/fstab | sed "s|${bastille_releasesdir}/||;s| .*||")
        FSTABMOD=$(grep -w "${bastille_releasesdir}/${RELEASE} ${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab")
        SYMLINKS="bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/ports usr/sbin usr/share usr/src"
        HASPORTS=$(grep -w ${bastille_releasesdir}/${RELEASE}/usr/ports ${bastille_jailsdir}/${TARGET}/fstab)

        if [ -n "${RELEASE}" ]; then
            cd "${bastille_jailsdir}/${TARGET}/root" || error_exit "Failed to change directory to ${bastille_jailsdir}/${TARGET}/root"

            # Work with the symlinks
            convert_symlinks

            # Comment the line containing .bastille and rename mountpoint
            sed -i '' -E "s|${FSTABMOD}|# Converted from thin to thick container on ${DATE}|g" "${bastille_jailsdir}/${TARGET}/fstab"
            if [ -n "${HASPORTS}" ]; then
                sed -i '' -E "s|${HASPORTS}|# Ports copied from base to container on ${DATE}|g" "${bastille_jailsdir}/${TARGET}/fstab"
                info "Copying ports to container..."
                cp -a "${bastille_releasesdir}/${RELEASE}/usr/ports" "${bastille_jailsdir}/${TARGET}/root/usr"
            fi
            mv "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/root/.bastille.old"

            info "Conversion of '${TARGET}' completed successfully!"
            exit 0
        else
            error_exit "Can't determine release version. See 'bastille bootstrap'."
        fi
    else
        error_exit "${TARGET} not found. See 'bastille create'."
    fi
}

# Check if is a thin container
if [ ! -d "${bastille_jailsdir}/${TARGET}/root/.bastille" ]; then
    error_exit "${TARGET} is not a thin container."
elif ! grep -qw ".bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
    error_exit "${TARGET} is not a thin container."
fi

# Make sure the user agree with the conversion
# Be interactive here since this cannot be easily undone
while :; do
    error_notify "Warning: container conversion from thin to thick can't be undone!"
    # shellcheck disable=SC2162
    # shellcheck disable=SC3045
    read -p "Do you really wish to convert '${TARGET}' into a thick container? [y/N]:" yn
    case ${yn} in
    [Yy]) start_convert;;
    [Nn]) exit 0;;
    esac
done
