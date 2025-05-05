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
    error_notify "Usage: bastille pkg [option(s)] TARGET COMMAND args"
    cat << EOF

    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -H | --host           Use the hosts 'pkg' instead of the jails.
    -y | --yes            Assume always yes for pkg command. Do not prompt.
    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
AUTO_YES=0
USE_HOST_PKG=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -H|--host)
            USE_HOST_PKG=1
            shift
            ;;
        -y|--yes)
            AUTO_YES=1
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
                    H) USE_HOST_PKG=1 ;;
                    y) AUTO_YES=1 ;;
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

if [ $# -lt 2 ]; then
    usage
fi

TARGET="${1}"
shift
        
bastille_root_check
set_target "${TARGET}"

pkg_run_command() {

    # Validate jail state
    check_target_is_running "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    else
        info "\n[${_jail}]:"
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi

    info "\n[${_jail}]:"

    bastille_jail_path="${bastille_jailsdir}/${_jail}/root"

    if [ -f "/usr/sbin/mport" ]; then
        if ! jexec -l -U root "${_jail}" /usr/sbin/mport "$@"; then
            errors=1
        fi
    elif [ -f "${bastille_jail_path}/usr/bin/apt" ]; then
        if ! jexec -l "${_jail}" /usr/bin/apt "$@"; then
            errors=1
        fi
    elif [ "${USE_HOST_PKG}" -eq 1 ]; then
        if [ "${AUTO_YES}" -eq 1 ]; then
            _jail_cmd="env ASSUME_ALWAYS_YES=yes /usr/sbin/pkg -j ${_jail} $@"
        else
            _jail_cmd="/usr/sbin/pkg -j ${_jail} $@"
        fi
        if ! ${_jail_cmd}; then
            errors=1
        fi
    else
        if [ "${AUTO_YES}" -eq 1 ]; then
            _jail_cmd="jexec -l -U root ${_jail} env ASSUME_ALWAYS_YES=yes /usr/sbin/pkg $@"
        else
            _jail_cmd="jexec -l -U root ${_jail} /usr/sbin/pkg $@"
        fi
        if ! ${_jail_cmd}; then
            errors=1
        fi
    fi
}

errors=0

for _jail in ${JAILS}; do

    if [ "${AUTO_YES}" -eq 1 ]; then

        (

        pkg_run_command "$@"

        ) &

    else

        (

        pkg_run_command "$@"

        )

    fi

    bastille_running_jobs "${bastille_process_limit}"
	
done
wait

if [ $errors -ne 0 ]; then
    error_exit "[ERROR]: Failed to apply on some jails, please check logs"
else
    echo
fi
