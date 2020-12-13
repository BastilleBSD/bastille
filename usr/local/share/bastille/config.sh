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

usage() {
    error_exit "Usage: bastille config TARGET get|set propertyName [newValue]"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -eq 1 ] || [ $# -gt 3 ]; then
    usage
fi

ACTION=$1
shift

case $ACTION in
    get)
        if [ $# -ne 1 ]; then
            error_notify 'Too many parameters for a "get" operation.'
            usage
        fi
        ;;
    set) ;;
    *) error_exit 'Only get and set are supported.' ;;
esac

PROPERTY=$1
shift
VALUE="$@"

for _jail in ${JAILS}; do
    FILE="${bastille_jailsdir}/${_jail}/jail.conf"
    if [ ! -f "${FILE}" ]; then
        error_notify "jail.conf does not exist for jail: ${_jail}"
        continue
    fi

    ESCAPED_PROPERTY=$(echo "${PROPERTY}" | sed 's/\./\\\./g')
    MATCH_LINE=$(grep "^[[:blank:]]*${ESCAPED_PROPERTY}[[:blank:]=;]" "${FILE}" 2>/dev/null)
    MATCH_FOUND=$?

    if [ "${ACTION}" = 'get' ]; then
        if [ $MATCH_FOUND -ne 0 ]; then
            warn "not set"
        elif ! echo "${MATCH_LINE}" | grep '=' > /dev/null 2>&1; then
            echo "enabled"
        else
            VALUE=$(echo "${MATCH_LINE}" | sed -E 's/.+= *(.+) *;$/\1/' 2>/dev/null)
            if [ $? -ne 0 ]; then
                error_notify "Failed to get value."
            else
                echo "${VALUE}"
            fi
        fi
    else # Setting the value. -- cwells
        if [ -n "${VALUE}" ]; then
            VALUE=$(echo "${VALUE}" | sed 's/\//\\\//g')
            if echo "${VALUE}" | grep ' ' > /dev/null 2>&1; then # Contains a space, so wrap in quotes. -- cwells
                VALUE="'${VALUE}'"
            fi
            LINE="  ${PROPERTY} = ${VALUE};"
        else
            LINE="  ${PROPERTY};"
        fi

        if [ $MATCH_FOUND -ne 0 ]; then # No match, so insert the property at the end. -- cwells
            echo "$(awk -v line="${LINE}" '$0 == "}" { print line; } 1 { print $0; }' "${FILE}")" > "${FILE}"
        else # Replace the existing value. -- cwells
            sed -i '' -E "s/ *${ESCAPED_PROPERTY}[ =;].*/${LINE}/" "${FILE}"
        fi
    fi
done

# Only display this message once at the end (not for every jail). -- cwells
if [ "${ACTION}" = 'set' ]; then
    info "A restart is required for the changes to be applied. See 'bastille restart ${TARGET}'."
fi

exit 0
