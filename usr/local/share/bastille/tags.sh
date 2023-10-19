#!/bin/sh
#
# Copyright (c) 2018-2023, Christer Edwards <christer.edwards@gmail.com>
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
    error_notify "Usage: bastille tags TARGET add tag1[,tag2,...]"
    error_notify "       bastille tags TARGET delete tag1[,tag2,...]"
    error_notify "       bastille tags TARGET list [tag]"
    echo -e "Example: bastille tags JAILNAME add database,mysql"
    echo -e "         bastille tags JAILNAME delete mysql"
    echo -e "         bastille tags ALL list"
    echo -e "         bastille tags ALL list mysql"
    exit 1
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -lt 1 -o $# -gt 2 ]; then
    usage
fi

bastille_root_check

ACTION="${1}"
TAGS="${2}"

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

