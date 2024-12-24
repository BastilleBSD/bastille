#!/bin/sh
#
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
    error_exit "Usage: bastille cmd TARGET command"

    cat << EOF
    Options:

    -f | --force -- Start the jail if it is stopped.

EOF
    exit 1
}

# Handle options.
FORCE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
	-h|--help|help)
	    usage
	    ;;
	-f|--force)
	    FORCE=1
	    shift
	    ;;
        -*)
            error_exit "Unknown option: \"${1}\""
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    usage
fi

bastille_root_check

TARGET="${1}"
shift 1
COUNT=0
RETURN=0

set_target "${TARGET}"

for _jail in ${JAILS}; do
    # If target is stopped or not found, continue...
    check_target_is_running "${_jail}" || if [ "${FORCE}" -eq 1 ]; then
        bastille start "${_jail}"
    else
        continue
    fi
    
    COUNT=$(($COUNT+1))
    info "[${_jail}]:"
    if grep -qw "linsysfs" "${bastille_jailsdir}/${_jail}/fstab"; then
        # Allow executing commands on Linux jails.
        jexec -l -u root "${_jail}" "$@"
        echo "$@"
    else
        jexec -l -U root "${_jail}" "$@"
        echo "$@"
    fi
    ERROR_CODE=$?
    if [ "${ERROR_CODE}" -ne 0 ]; then
        warn "[${_jail}]: ${ERROR_CODE}"
    fi
    if [ "$COUNT" -eq 1 ]; then
        RETURN=${ERROR_CODE}
    else 
        RETURN=$(($RETURN+$ERROR_CODE))
    fi
done

# Check when a command is executed in all running jails. (bastille cmd ALL ...)
if [ "${COUNT}" -gt 1 ] && [ "${RETURN}" -gt 0 ]; then
    RETURN=1
fi

return "${RETURN}"
