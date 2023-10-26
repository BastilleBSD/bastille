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
    error_exit "Usage: bastille cp [OPTION] TARGET HOST_PATH CONTAINER_PATH"
}

CPSOURCE="${1}"
CPDEST="${2}"

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
-q|--quiet)
    OPTION="${1}"
    CPSOURCE="${2}"
    CPDEST="${3}"
    ;;
esac

if [ $# -ne 2 ]; then
    usage
fi

bastille_root_check

case "${OPTION}" in
    -q|--quiet)
        OPTION="-a"
        ;;
    *)
        OPTION="-av"
        ;;
esac

for _jail in ${JAILS}; do
    info "[${_jail}]:"
    bastille_jail_path="${bastille_jailsdir}/${_jail}/root"
    cp "${OPTION}" "${CPSOURCE}" "${bastille_jail_path}/${CPDEST}"
    RETURN="$?"
    if [ "${TARGET}" = "ALL" ]; then
        # Display the return status for reference
        echo -e "Returned: ${RETURN}\n"
    else
        echo
        return "${RETURN}"
    fi
done
