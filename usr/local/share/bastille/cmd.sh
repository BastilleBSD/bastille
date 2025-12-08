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
    error_notify "Usage: bastille cmd [option(s)] TARGET COMMAND"
    cat << EOF

    Options:

    -a | --auto      Auto mode. Start/stop jail(s) if required.
    -x | --debug     Enable debug mode.

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

if [ "$#" -eq 0 ]; then
    usage
fi

bastille_root_check

TARGET="${1}"
shift 1
ERRORS=0

set_target "${TARGET}"

for _jail in ${JAILS}; do

    # Validate jail state
    check_target_is_running "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille start "${_jail}"
    else
        info "\n[${_jail}]:"
        error_notify "Jail is not running."
        error_continue "Use [-a|--auto] to auto-start the jail."
    fi

    info "\n[${_jail}]:"

    # Allow executing commands on linux jails
    if grep -qw "linsysfs" "${bastille_jailsdir}/${_jail}/fstab"; then
        jexec -l -u root "${_jail}" "$@"
    else
        jexec -l -U root "${_jail}" "$@"
    fi

    if [ "$?" -ne 0 ]; then
        ERRORS=$((ERRORS + 1))
    fi

done

if [ "${ERRORS}" -ne 0 ]; then
    error_exit "[ERROR]: Command failed on ${ERRORS} jails."
fi