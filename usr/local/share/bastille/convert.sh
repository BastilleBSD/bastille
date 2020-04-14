#!/bin/sh
#
# Copyright (c) 2018-2020, Christer Edwards <christer.edwards@gmail.com>
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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille convert TARGET.${COLOR_RESET}"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    usage
fi

TARGET="${1}"
shift

error_notify()
{
    # Notify message on error and exit
    echo -e "$*" >&2
    exit 1
}

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
        error_notify "${COLOR_RED}Release must be bootstrapped first, See 'bastille bootstrap'.${COLOR_RESET}"
    fi
}

revert_convert() {
    # Revert the conversion on first cp error
    echo -e "${COLOR_RED}A problem has occurred while copying the files, reverting changes...${COLOR_RESET}"
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
    error_notify "${COLOR_GREEN}Changes for '${TARGET}' has been reverted.${COLOR_RESET}"
}

start_convert() {
    # Attempt container conversion and handle some errors
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        echo -e "${COLOR_GREEN}Converting '${TARGET}' into a thickjail, this may take a while...${COLOR_RESET}"

        # Set some variables
        RELEASE=$(grep -owE '([1-9]{2,2})\.[0-9](-RELEASE|-RC[1-2])|([0-9]{1,2}-stable-build-[0-9]{1,3})|(current-build)-([0-9]{1,3})|(current-BUILD-LATEST)|([0-9]{1,2}-stable-BUILD-LATEST)|(current-BUILD-LATEST)' "${bastille_jailsdir}/${TARGET}/fstab")
        FSTABMOD=$(grep -w "${bastille_releasesdir}/${RELEASE} ${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab")
        SYMLINKS="bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/ports usr/sbin usr/share usr/src"

        if [ -n "${RELEASE}" ]; then
            cd "${bastille_jailsdir}/${TARGET}/root"

            # Work with the symlinks
            convert_symlinks

            # Comment the line containing .bastille and rename mountpoint
            sed -i '' -E "s|${FSTABMOD}|# Converted from thin to thick container on $(date)|g" "${bastille_jailsdir}/${TARGET}/fstab"
            mv "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/root/.bastille.old"

            echo -e "${COLOR_GREEN}Conversion of '${TARGET}' completed successfully!${COLOR_RESET}"
            exit 0
        else
            error_notify "${COLOR_RED}Can't determine release version, See 'bastille bootstrap'.${COLOR_RESET}"
        fi
    else
        error_notify "${COLOR_RED}${TARGET} not found. See 'bastille create'.${COLOR_RESET}"
    fi
}

# Check if container is running
if [ -n "$(jls name | awk "/^${TARGET}$/")" ]; then
    error_notify "${COLOR_RED}${TARGET} is running, See 'bastille stop'.${COLOR_RESET}"
fi

# Check if is a thin container
if [ ! -d "${bastille_jailsdir}/${TARGET}/root/.bastille" ]; then
    error_notify "${COLOR_RED}${TARGET} is not a thin container.${COLOR_RESET}"
elif ! grep -qw ".bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
    error_notify "${COLOR_RED}${TARGET} is not a thin container.${COLOR_RESET}"
fi

# Make sure the user agree with the conversion
# Be interactive here since this cannot be easily undone
while :; do
    echo -e "${COLOR_RED}Warning: container conversion from thin to thick can't be undone!${COLOR_RESET}"
    read -p "Do you really wish to convert '${TARGET}' into a thick container? [y/N]:" yn
    case ${yn} in
    [Yy]) start_convert;;
    [Nn]) exit 0;;
    esac
done
