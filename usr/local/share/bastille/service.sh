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
    error_exit "Usage: bastille service [options(s)] TARGET SERVICE_NAME ACTION"
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

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    usage
fi

TARGET="${1}"
shift

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do
    check_target_is_running "${_jail}" || if [ "${FORCE}" -eq 1 ]; then
	    bastille start "${_jail}"
	else
	    continue
    fi
    info "[${_jail}]:"
    jexec -l "${_jail}" /usr/sbin/service "$@"
done
