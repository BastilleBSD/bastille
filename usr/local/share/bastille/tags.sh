#!/bin/sh
#
# Copyright (c) 2018-2024, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
# Ressource limits added by Lars Engels github.com/bsdlme
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
    error_notify "Usage: bastille tags TARGET [add|delete|list] [tag1,tag2]
    cat << EOF
    Options:

    -x | --debug          Enable debug mode.

EOF
    exit 1
}

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
	-h|--help|help)
	    usage
	    ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            error_exit "Unknown Option: \"${1}\"" ;; 
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

TARGET="${1}"
ACTION="${2}"
TAGS="${3}"

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do
    bastille_jail_tags="${bastille_jailsdir}/${_jail}/tags"
    case ${ACTION} in
        add)
        for _tag in $(echo ${TAGS} | tr , ' '); do
            echo ${_tag} >> "${bastille_jail_tags}"
            tmpfile="$(mktemp)"
            sort "${bastille_jail_tags}" | uniq > "${tmpfile}"
            mv "${tmpfile}" "${bastille_jail_tags}"
        done
        ;;
        del*)
        for _tag in $(echo ${TAGS} | tr , ' '); do
            [ ! -f "${bastille_jail_tags}" ] && break # skip if no tags file
            tmpfile="$(mktemp)"
            grep -Ev "^${_tag}\$" "${bastille_jail_tags}" > "${tmpfile}"
            mv "${tmpfile}" "${bastille_jail_tags}"
            # delete tags file if empty
            [ ! -s "${bastille_jail_tags}" ] && rm "${bastille_jail_tags}"
        done
        ;;
        list)
        if [ -n "${TAGS}" ]; then
            [ -n "$(echo ${TAGS} | grep ,)" ] && usage # Only one tag per query
            [ ! -f "${bastille_jail_tags}" ] && continue # skip if there is no tags file
            grep -qE "^${TAGS}\$" "${bastille_jail_tags}"
            if [ $? -eq 0 ]; then
              echo "${_jail}"
              continue
            fi
        else
            if [ -f "${bastille_jail_tags}" ]; then
                echo -n "${_jail}: "
                xargs < "${bastille_jail_tags}"
            fi
        fi
        ;;
        *)
        usage
        ;;
    esac
done