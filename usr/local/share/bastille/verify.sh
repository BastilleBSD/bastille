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

bastille_usage() {
    echo -e "${COLOR_RED}Usage: bastille verify [release|template].${COLOR_RESET}"
    exit 1
}

verify_release() {
    if freebsd-version | grep -qi HBSD; then
        echo -e "${COLOR_RED}Not yet supported on HardenedBSD.${COLOR_RESET}"
        exit 1
    fi

    if [ -d "${bastille_releasesdir}/${RELEASE}" ]; then
        freebsd-update -b "${bastille_releasesdir}/${RELEASE}" --currently-running "${RELEASE}" IDS
    else
        echo -e "${COLOR_RED}${RELEASE} not found. See bootstrap.${COLOR_RESET}"
        exit 1
    fi
}

verify_template() {
    _template_path=${bastille_templatesdir}/${BASTILLE_TEMPLATE}
    _hook_validate=0

    for _hook in TARGET INCLUDE PRE OVERLAY FSTAB PF PKG SYSRC SERVICE CMD; do
        _path=${_template_path}/${_hook}
        if [ -s "${_path}" ]; then
            _hook_validate=$((_hook_validate+1))
            echo -e "${COLOR_GREEN}Detected ${_hook} hook.${COLOR_RESET}"

            ## line count must match newline count
            if [ $(wc -l "${_path}" | awk '{print $1}') -ne $(grep -c $'\n' "${_path}") ]; then
                echo -e "${COLOR_GREEN}[${_hook}]:${COLOR_RESET}"
                echo -e "${COLOR_RED}${BASTILLE_TEMPLATE}:${_hook} [failed].${COLOR_RESET}"
                echo -e "${COLOR_RED}Line numbers don't match line breaks.${COLOR_RESET}"
                echo
                echo -e "${COLOR_RED}Template validation failed.${COLOR_RESET}"
                exit 1

            ## if INCLUDE; recursive verify
            elif [ ${_hook} = 'INCLUDE' ]; then
                echo -e "${COLOR_GREEN}[${_hook}]:${COLOR_RESET}"
                cat "${_path}"
                echo
                while read _include; do
                    echo -e "${COLOR_GREEN}[${_hook}]:[${_include}]:${COLOR_RESET}"

                    case ${_include} in
                        http?://github.com/*/*|http?://gitlab.com/*/*)
                            bastille bootstrap "${_include}"
                        ;;
                        */*)
                            BASTILLE_TEMPLATE_USER=$(echo "${_include}" | awk -F / '{ print $1 }')
                            BASTILLE_TEMPLATE_REPO=$(echo "${_include}" | awk -F / '{ print $2 }')
                            bastille verify "${BASTILLE_TEMPLATE_USER}/${BASTILLE_TEMPLATE_REPO}"
                        ;;
                        *)
                            echo -e "${COLOR_RED}Template INCLUDE content not recognized.${COLOR_RESET}"
                            exit 1
                    ;;
                    esac
                done < "${_path}"

            ## if tree; tree -a bastille_template/_dir
            elif [ ${_hook} = 'OVERLAY' ]; then
                echo -e "${COLOR_GREEN}[${_hook}]:${COLOR_RESET}"
                cat "${_path}"
                echo
                while read _dir; do
                    echo -e "${COLOR_GREEN}[${_hook}]:[${_dir}]:${COLOR_RESET}"
                        if [ -x /usr/local/bin/tree ]; then
                            /usr/local/bin/tree -a "${_template_path}/${_dir}"
                        else
                           find "${_template_path}/${_dir}" -print | sed -e 's;[^/]*/;|___;g;s;___|; |;g'
                        fi
                    echo
                done < "${_path}"
            else
                echo -e "${COLOR_GREEN}[${_hook}]:${COLOR_RESET}"
                cat "${_path}"
                echo
            fi
        fi
    done

    ## remove bad templates
    if [ ${_hook_validate} -lt 1 ]; then
        echo -e "${COLOR_RED}No valid template hooks found.${COLOR_RESET}"
        echo -e "${COLOR_RED}Template discarded.${COLOR_RESET}"
        rm -rf "${bastille_template}"
        exit 1
    fi

    ## if validated; ready to use
    if [ ${_hook_validate} -gt 0 ]; then
        echo -e "${COLOR_GREEN}Template ready to use.${COLOR_RESET}"
    fi
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    bastille_usage
    ;;
esac

if [ $# -gt 1 ] || [ $# -lt 1 ]; then
    bastille_usage
fi

case "$1" in
*-RELEASE|*-release|*-RC1|*-rc1|*-RC2|*-rc2)
    RELEASE=$1
    verify_release
    ;;
*-stable-LAST|*-STABLE-last|*-stable-last|*-STABLE-LAST)
    RELEASE=$1
    verify_release
    ;;
http?*)
    bastille_usage
    ;;
*/*)
    BASTILLE_TEMPLATE=$1
    verify_template
    ;;
*)
    bastille_usage
    ;;
esac
