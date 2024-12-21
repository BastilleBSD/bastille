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
    error_exit "Usage: bastille edit TARGET [filename]"
}

# Handle special-case commands first.
case "$1" in
    help|-h|--help)
        usage
        ;;
esac

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

# Handle options.
FORCE=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -f|--force|force)
            FORCE="1"
            shift
            ;;
        -*)
            error_notify "Unknown Option: \"${1}\""
            usage
            ;;
        *)
            break
            ;;
    esac
done

TARGET="${1}"
if [ "$#" -eq 2 ]; then
    TARGET_FILENAME="${2}"
else 
    TARGET_FILENAME="jail.conf"
fi

bastille_root_check
set_target_single "${TARGET}"
check_target_is_running "${TARGET}" || if [ "${FORCE}" -eq 1 ]; then
    bastille start "${TARGET}"
else
    exit
fi

if [ -z "${EDITOR}" ]; then
    EDITOR=nano
fi

"${EDITOR}" "${bastille_jailsdir}/${TARGET}/${TARGET_FILENAME}"
