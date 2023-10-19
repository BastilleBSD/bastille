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
    error_exit "Usage: bastille config TARGET get|set propertyName [newValue]"
}

# we need jail(8) to parse the config file so it can expand variables etc
print_jail_conf() {

    # we need to pass a literal \n to jail to get each parameter on its own
    # line
    jail -f "$1" -e '
'
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

bastille_root_check

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

    if [ "${ACTION}" = 'get' ]; then
        _output=$(
            print_jail_conf "${FILE}" | awk -F= -v property="${PROPERTY}" '
                $1 == property {
                    # note that we have found the property
                    found = 1;
                    # check if there is a value for this property
                    if (NF == 2) {
                        # remove any quotes surrounding the string
                        sub(/^"/, "", $2);
                        sub(/"$/, "", $2);
                        print $2;
                    } else {
                        # no value, just the property name
                        print "enabled";
                    }
                    exit 0;
                }
                END {
                    # if we have not found anything we need to print a special
                    # string
                    if (! found) {
                        print("not set");
                        #  let the caller know that this is a warn condition
                        exit(120);
                    }
                }'
            )
        # check if our output is a warning or regular
        if [ $? -eq 120 ]; then
            warn "${_output}"
        else
            echo "${_output}"
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

        # add the value to the config file, replacing any existing value or, if
        # there is none, at the end
        #
        # awk doesn't have "inplace" editing so we use a temp file
        _tmpfile=$(mktemp) || error_exit "unable to set because mktemp failed"
        cp "${FILE}" "${_tmpfile}" && \
        awk -F= -v line="${LINE}" -v property="${PROPERTY}" '
            BEGIN {
                # build RE as string as we can not expand vars in RE literals
                prop_re = "^[[:space:]]*" property "[[:space:]]*$";
            }
            $1 ~ prop_re && !found {
                # we already have an entry in the config for this property so
                # we need to substitute our line here rather than keep the
                # existing line
                print(line);
                # note we have already found the property
                found = 1;
                # move onto the next line
                next;
            }
            $1 == "}" {
                # reached the end of the stanza so if we have not already
                # added our line we need to do so now
                if (! found) {
                    print(line);
                }
            }
            {
                # print each uninteresting line unchanged
                print;
            }
        ' "${_tmpfile}" > "${FILE}"
        rm "${_tmpfile}"
    fi
done

# Only display this message once at the end (not for every jail). -- cwells
if [ "${ACTION}" = 'set' ]; then
    info "A restart is required for the changes to be applied. See 'bastille restart ${TARGET}'."
fi

exit 0
