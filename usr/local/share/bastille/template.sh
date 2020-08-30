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

. /usr/local/share/bastille/common.sh
. /usr/local/etc/bastille/bastille.conf

bastille_usage() {
    error_exit "Usage: bastille template TARGET project/template"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    bastille_usage
    ;;
esac

if [ $# -ne 1 ]; then
    bastille_usage
fi

TEMPLATE="${1}"

case ${TEMPLATE} in
    http?://github.com/*/*|http?://gitlab.com/*/*)
        TEMPLATE_DIR=$(echo "${TEMPLATE}" | awk -F / '{ print $4 "/" $5 }')
        if [ ! -d "${bastille_templatesdir}/${TEMPLATE_DIR}" ]; then
            echo -e "${COLOR_GREEN}Bootstrapping ${TEMPLATE}...${COLOR_RESET}"
            if ! bastille bootstrap "${TEMPLATE}"; then
                error_exit "Failed to bootstrap template: ${TEMPLATE}"
            fi
        fi
        TEMPLATE="${TEMPLATE_DIR}"
        ;;
    */*)
        if [ ! -d "${bastille_templatesdir}/${TEMPLATE}" ]; then
            error_exit "${TEMPLATE} not found."
        fi
        ;;
    *)
        error_exit "Template name/URL not recognized."
esac

if [ -z "${JAILS}" ]; then
    error_exit "Container ${TARGET} is not running."
fi

if [ -z "${HOOKS}" ]; then
    HOOKS='LIMITS INCLUDE PRE FSTAB PF PKG OVERLAY CONFIG SYSRC SERVICE CMD'
fi

## global variables
bastille_template=${bastille_templatesdir}/${TEMPLATE}
for _jail in ${JAILS}; do
    ## jail-specific variables.
    bastille_jail_path=$(jls -j "${_jail}" path)

    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Applying template: ${TEMPLATE}...${COLOR_RESET}"

    ## TARGET
    if [ -s "${bastille_template}/TARGET" ]; then
        if grep -qw "${_jail}" "${bastille_template}/TARGET"; then
            echo -e "${COLOR_GREEN}TARGET: !${_jail}.${COLOR_RESET}"
            echo
            continue
        fi
    if ! grep -Eq "(^|\b)(${_jail}|ALL)($|\b)" "${bastille_template}/TARGET"; then
            echo -e "${COLOR_GREEN}TARGET: ?${_jail}.${COLOR_RESET}"
            echo
            continue
        fi
    fi

    if [ -s "${bastille_template}/Bastillefile" ]; then
        # Ignore blank lines and comments. -- cwells
        SCRIPT=$(grep -v '^\s*$' "${bastille_template}/Bastillefile" | grep -v '^\s*#')
        # Use a newline as the separator. -- cwells
        IFS='
'
        set -f
        for _line in ${SCRIPT}; do
            _cmd=$(echo "${_line}" | awk '{print tolower($1);}')
            _args=$(echo "${_line}" | awk '{$1=""; sub(/^ */, ""); print;}')

            # Apply overrides for commands/aliases and arguments. -- cwells
            case $_cmd in
                cmd)
                    # Allow redirection within the jail. -- cwells
                    _args="sh -c '${_args}'"
                    ;;
                overlay)
                    _cmd='cp'
                    _args="${bastille_template}/${_args} /"
                    ;;
                cp|copy)
                    # Convert relative "from" path into absolute path inside the template directory. -- cwells
                    if [ "${_args%${_args#?}}" != '/' ]; then
                        _args="${bastille_template}/${_args}"
                    fi
                    ;;
                fstab|mount)
                    _cmd='mount' ;;
                include)
                    _cmd='template' ;;
                pkg)
                    _args="install -y ${_args}" ;;
            esac

            if ! eval "bastille ${_cmd} ${_jail} ${_args}"; then
                set +f
                unset IFS
                error_exit "Failed to execute command: ${_cmd}"
            fi
        done
        set +f
        unset IFS
    fi

    for _hook in ${HOOKS}; do
        if [ -s "${bastille_template}/${_hook}" ]; then
        	# Default command is the lowercase hook name and default args are the line from the file. -- cwells
        	_cmd=$(echo "${_hook}" | awk '{print tolower($1);}')
            _args_template='${_line}'

            # Override default command/args for some hooks. -- cwells
            case ${_hook} in
                CONFIG)
                    echo -e "${COLOR_YELLOW}CONFIG deprecated; rename to OVERLAY.${COLOR_RESET}"
                    _args_template='${bastille_template}/${_line} /'
                    _cmd='cp' ;;
                FSTAB)
                    _cmd='mount' ;;
                INCLUDE)
                    _cmd='template' ;;
                OVERLAY)
                    _args_template='${bastille_template}/${_line} /'
                    _cmd='cp' ;;
                PF)
                    echo -e "${COLOR_GREEN}NOT YET IMPLEMENTED.${COLOR_RESET}"
                    continue ;;
                PRE)
                    _cmd='cmd' ;;
            esac

            echo -e "${COLOR_GREEN}[${_jail}]:${_hook} -- START${COLOR_RESET}"
            if [ "${_hook}" = 'CMD' ] || [ "${_hook}" = 'PRE' ]; then
                bastille cmd "${_jail}" /bin/sh < "${bastille_template}/${_hook}" || exit 1
            elif [ "${_hook}" = 'PKG' ]; then
                bastille pkg "${_jail}" install -y $(cat "${bastille_template}/PKG") || exit 1
                bastille pkg "${_jail}" audit -F
            else
                while read _line; do
                	if [ -z "${_line}" ]; then
                	    continue
                	fi
                    eval "_args=\"${_args_template}\""
                    bastille "${_cmd}" "${_jail}" ${_args} || exit 1
                done < "${bastille_template}/${_hook}"
            fi
            echo -e "${COLOR_GREEN}[${_jail}]:${_hook} -- END${COLOR_RESET}"
            echo
        fi
    done

    echo -e "${COLOR_GREEN}Template complete.${COLOR_RESET}"
    echo
done
