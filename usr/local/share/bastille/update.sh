#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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
    error_exit "Usage: bastille update [release|container|template] | [force]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 2 ] || [ $# -lt 1 ]; then
    usage
fi

bastille_root_check

TARGET="${1}"
OPTION="${2}"

# Handle options
case "${OPTION}" in
    -f|--force)
        OPTION="-F"
        ;;
    *)
        OPTION=
        ;;
esac

# Check for unsupported actions
if [ "${TARGET}" = "ALL" ]; then
    error_exit "Batch upgrade is unsupported."
fi

if [ -f "/bin/midnightbsd-version" ]; then
    echo -e "${COLOR_RED}Not yet supported on MidnightBSD.${COLOR_RESET}"
    exit 1
fi

if freebsd-version | grep -qi HBSD; then
    error_exit "Not yet supported on HardenedBSD."
fi

# Check for alternate/unsupported archs
arch_check() {
    if echo "${TARGET}" | grep -w "[0-9]\{1,2\}\.[0-9]\-RELEASE\-i386"; then
        ARCH_I386="1"
    fi
}

jail_check() {
    # Check if the jail is thick and is running
    if [ ! "$(/usr/sbin/jls name | awk "/^${TARGET}$/")" ]; then
        error_exit "[${TARGET}]: Not started. See 'bastille start ${TARGET}'."
    else
        if grep -qw "${bastille_jailsdir}/${TARGET}/root/.bastille" "${bastille_jailsdir}/${TARGET}/fstab"; then
            error_exit "${TARGET} is not a thick container."
        fi
    fi
}

jail_update() {
    # Update a thick container
    if [ -d "${bastille_jailsdir}/${TARGET}" ]; then
        jail_check    
        CURRENT_VERSION=$(/usr/sbin/jexec -l "${TARGET}" freebsd-version 2>/dev/null)
        if [ -z "${CURRENT_VERSION}" ]; then
            error_exit "Can't determine '${TARGET}' version."
        else
            env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_jailsdir}/${TARGET}/root" \
            fetch install --currently-running "${CURRENT_VERSION}"
        fi
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap'."
    fi
}

release_update() {
    # Update a release base(affects child containers)
    if [ -d "${bastille_releasesdir}/${TARGET}" ]; then
        TARGET_TRIM="${TARGET}"
        if [ -n "${ARCH_I386}" ]; then
            TARGET_TRIM=$(echo "${TARGET}" | sed 's/-i386//')
        fi

        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_releasesdir}/${TARGET}" \
        fetch --currently-running "${TARGET_TRIM}"
        env PAGER="/bin/cat" freebsd-update ${OPTION} --not-running-from-cron -b "${bastille_releasesdir}/${TARGET}" \
        install --currently-running "${TARGET_TRIM}"
    else
        error_exit "${TARGET} not found. See 'bastille bootstrap'."
    fi
}

template_update() {
    # Update a template
    _template_path=${bastille_templatesdir}/${BASTILLE_TEMPLATE}
    if [ -d $_template_path ]; then
        info "[${BASTILLE_TEMPLATE}]:"
        git -C $_template_path pull ||\
            error_notify "${BASTILLE_TEMPLATE} update unsuccessful."    

        bastille verify "${BASTILLE_TEMPLATE}"
    else 
        error_exit "${BASTILLE_TEMPLATE} not found. See 'bastille bootstrap'."
    fi
}

templates_update() {
    # Update all templates
    _updated_templates=0
    if [ -d  ${bastille_templatesdir} ]; then
        for _template_path in $(ls -d ${bastille_templatesdir}/*/*); do
            if [ -d $_template_path/.git ]; then
                BASTILLE_TEMPLATE=$(echo "$_template_path" | awk -F / '{ print $(NF-1) "/" $NF }')
                template_update

                _updated_templates=$((_updated_templates+1))
            fi
        done
    fi

    if [ "$_updated_templates" -ne "0" ]; then
        info "$_updated_templates templates updated."
    else 
        error_exit "no templates found. See 'bastille bootstrap'."
    fi
}

# Check what we should update
if [ "${TARGET}" = 'TEMPLATES' ]; then
    templates_update
elif echo "${TARGET}" | grep -Eq '^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$'; then
    BASTILLE_TEMPLATE="${TARGET}"
    template_update
elif echo "${TARGET}" | grep -q "[0-9]\{2\}.[0-9]-RELEASE"; then
    arch_check
    release_update
else
    jail_update
fi
