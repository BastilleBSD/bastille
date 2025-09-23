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
    error_notify "Usage: bastille verify [option(s)] RELEASE|TEMPLATE"
    cat << EOF

    Options:

    -x | --debug          Enable debug mode.

EOF
    exit 1
}

verify_release() {

    if [ -f "/bin/midnightbsd-version" ]; then
        error_exit "[ERROR]: Not yet supported on MidnightBSD."
    fi

    if freebsd-version | grep -qi HBSD; then
        error_exit "[ERROR]: Not yet supported on HardenedBSD."
    fi

    if [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
        freebsd-update -b "${bastille_releasesdir}/${RELEASE}" --currently-running "${RELEASE}" IDS
    else
        error_exit "[ERROR]: ${RELEASE} not found. See 'bastille bootstrap'."
    fi
}

handle_template_include() {

    case ${TEMPLATE_INCLUDE} in
        http?://*/*/*)
            bastille bootstrap "${TEMPLATE_INCLUDE}"
        ;;
        */*)
            BASTILLE_TEMPLATE_USER=$(echo "${TEMPLATE_INCLUDE}" | awk -F / '{ print $1 }')
            BASTILLE_TEMPLATE_REPO=$(echo "${TEMPLATE_INCLUDE}" | awk -F / '{ print $2 }')
            bastille verify "${BASTILLE_TEMPLATE_USER}/${BASTILLE_TEMPLATE_REPO}"
        ;;
        *)
            error_exit "[ERROR]: Template INCLUDE content not recognized."
    ;;
    esac
}

verify_template() {

    _template_path=${bastille_templatesdir}/${BASTILLE_TEMPLATE}
    _hook_validate=0

    for _hook in TARGET INCLUDE PRE OVERLAY FSTAB PF PKG SYSRC SERVICE CMD Bastillefile; do
        _path=${_template_path}/${_hook}
        if [ -s "${_path}" ]; then
            _hook_validate=$((_hook_validate+1))
            info "\nDetected ${_hook} hook."

            ## line count must match newline count
            # shellcheck disable=SC2046
            # shellcheck disable=SC3003
            if [ $(wc -l "${_path}" | awk '{print $1}') -ne "$(tr -d -c '\n' < "${_path}" | wc -c)" ]; then
                info "[${_hook}]:"
                error_notify "[ERROR]: ${BASTILLE_TEMPLATE}:${_hook} [failed]."
                error_notify "Line numbers don't match line breaks."
                error_exit "Template validation failed."
            ## if INCLUDE; recursive verify
            elif [ "${_hook}" = 'INCLUDE' ]; then
                info "[${_hook}]:"
                cat "${_path}"
                while read _include; do
                    info "[${_hook}]:[${_include}]:"
                    TEMPLATE_INCLUDE="${_include}"
                    handle_template_include
                done < "${_path}"

            ## if tree; tree -a bastille_template/_dir
            elif [ "${_hook}" = 'OVERLAY' ]; then
                info "[${_hook}]:"
                cat "${_path}"
                while read _dir; do
                    info "[${_hook}]:[${_dir}]:"
                        if [ -x "/usr/local/bin/tree" ]; then
                            /usr/local/bin/tree -a "${_template_path}/${_dir}"
                        else
                           find "${_template_path}/${_dir}" -print | sed -e 's;[^/]*/;|___;g;s;___|; |;g'
                        fi
                done < "${_path}"
            elif [ "${_hook}" = 'Bastillefile' ]; then
                info "[${_hook}]:"
                cat "${_path}"
                while read _line; do
                    _cmd=$(echo "${_line}" | awk '{print tolower($1);}')
                    ## if include; recursive verify
                    if [ "${_cmd}" = 'include' ]; then
                        TEMPLATE_INCLUDE=$(echo "${_line}" | awk '{print $2;}')
                        handle_template_include
                    fi
                done < "${_path}"
            else
                info "[${_hook}]:"
                cat "${_path}"
            fi
        fi
    done

    # Remove bad templates
    if [ "${_hook_validate}" -lt 1 ]; then
        rm -rf "${_template_path}"
        error_notify "[ERROR]: No valid template hooks found."
        error_exit "Template discarded."
    fi

    ## if validated; ready to use
    if [ "${_hook_validate}" -gt 0 ]; then
        info "\nTemplate ready to use."
    fi
}

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            error_exit "[ERROR]: Unknown Option: \"${1}\""
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 1 ]; then
    usage
fi

bastille_root_check

case "${1}" in
    *-RELEASE|*-release|*-RC[1-9]|*-rc[1-9])
        RELEASE="${1}"
        verify_release
        ;;
    *-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
        RELEASE="${1}"
        verify_release
        ;;
    http?*)
        bastille_usage
        ;;
    */*)
        BASTILLE_TEMPLATE="${1}"
        verify_template
        ;;
    *)
        usage
        ;;
esac

echo
