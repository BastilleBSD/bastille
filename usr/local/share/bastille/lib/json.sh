#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2026, Christer Edwards <christer.edwards@gmail.com>
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


# JSON output helpers. These are no-ops unless '-j|--json' set BASTILLE_JSON=1.
# Values are emitted as JSON strings; xo(1) handles quoting/escaping. The schema
# is {"bastille":{"type":"<entity>","<entity>":[ {record}, ... ]}}, following the
# libxo convention of naming the array after the entity being reported (like
# jls -> "jail", ps -> "process"). The sibling "type" field lets a generic
# consumer branch without sniffing keys: read .bastille.type, then index
# .bastille[.type]. <entity> is "jail" for jail-scoped commands, "release" or
# "template" for others

# For the "jail" entity, json_record always leads each record with its jid (a
# native number when the jail is running, null when it is not).
json_open() {
    # json_open <entity>  ->  opens {"bastille":{"type":"<entity>","<entity>":[
    [ "${BASTILLE_JSON}" -eq 1 ] || return 0
    BASTILLE_JSON_P=""
    [ "${BASTILLE_JSON_PRETTY}" -eq 1 ] && BASTILLE_JSON_P="--pretty"
    BASTILLE_JSON_ENTITY="${1}"
    BASTILLE_JSON_FIRST=1
    BASTILLE_JSON_OPEN=1
    BASTILLE_JSON_DONE=0
    xo ${BASTILLE_JSON_P} --json --top-wrap --open bastille
    xo ${BASTILLE_JSON_P} --json --depth 2 "{:type}" "${BASTILLE_JSON_ENTITY}"
    xo ${BASTILLE_JSON_P} --json --not-first --depth 2 --open-list "${BASTILLE_JSON_ENTITY}"
}

json_record() {
    # json_record <field> <value> [<field> <value> ...]  ->  one array element
    [ "${BASTILLE_JSON}" -eq 1 ] || return 0
    local nf fmt pairs i field_nf jname jidval jind seen kept
    if [ "${BASTILLE_JSON_FIRST}" -eq 1 ]; then nf=""; else nf="--not-first"; fi
    xo ${BASTILLE_JSON_P} --json ${nf} --depth 3 --open-instance "${BASTILLE_JSON_ENTITY}"

    field_nf=""
    # For jail records, emit the jid first (native number, or null when the jail
    # is not running).
    if [ "${BASTILLE_JSON_ENTITY}" = "jail" ]; then
        jname=""
        pairs=$(( $# / 2 ))
        i=0
        while [ "${i}" -lt "${pairs}" ]; do
            # First name only — later duplicates (e.g. config get name) are
            # dropped, so jid must match the value that will actually be emitted.
            [ "${1}" = "name" ] && [ -z "${jname}" ] && jname="${2}"
            set -- "$@" "${1}" "${2}"
            shift 2
            i=$(( i + 1 ))
        done
        jidval="$(jls -j "${jname}" jid 2>/dev/null || :)"
        if [ -n "${jidval}" ]; then
            xo ${BASTILLE_JSON_P} --json --depth 4 "{:jid/%d}" "${jidval}"
        else
            # xo(1) cannot emit a JSON null, so print the literal for the no-jid
            # case. --open-instance already emitted the newline; fields live at
            # depth 4 -> 8 leading spaces in pretty mode.
            if [ "${BASTILLE_JSON_PRETTY}" -eq 1 ]; then
                jind=$(( 4 * 2 ))
                printf '%*s"jid": null' "${jind}" ''
            else
                printf '"jid":null'
            fi
        fi
        field_nf="--not-first"
    fi

    # Build the format string from the field names and rotate the values to the
    # front of the positional parameters so they can be passed to a single xo(1)
    # call (values may contain spaces, so they must stay as separate arguments).
    # Duplicate field names are dropped, keeping the first — this guards against a
    # queried property colliding with a reserved field (e.g. 'config get name' or
    # 'get jid', where the property key would repeat the identity/jid field).
    fmt=""
    kept=0
    seen=" "
    [ "${BASTILLE_JSON_ENTITY}" = "jail" ] && seen=" jid "
    pairs=$(( $# / 2 ))
    i=0
    while [ "${i}" -lt "${pairs}" ]; do
        case "${seen}" in
            *" ${1} "*)
                shift 2
                ;;
            *)
                seen="${seen}${1} "
                fmt="${fmt}{:${1}}"
                set -- "$@" "${2}"
                shift 2
                kept=$(( kept + 1 ))
                ;;
        esac
        i=$(( i + 1 ))
    done
    if [ "${kept}" -gt 0 ]; then
        xo ${BASTILLE_JSON_P} --json ${field_nf} --depth 4 "${fmt}" "$@"
    fi
    xo ${BASTILLE_JSON_P} --json --depth 3 --close-instance "${BASTILLE_JSON_ENTITY}"
    BASTILLE_JSON_FIRST=0
}

json_error() {
    # json_error <message>
    #
    # Request-level failures must be machine-readable: APIs parse stdout
    # and ignore stderr. Keep one schema — a sibling .bastille.error
    # object — not libxo's standalone {"error":...} document, which would
    # force clients to handle two shapes. The object is never an array so
    # it cannot collide with an entity list keyed "error".
    [ "${BASTILLE_JSON:-0}" -eq 1 ] || return 0
    [ "${BASTILLE_JSON_DONE:-0}" -eq 1 ] && return 0
    BASTILLE_JSON_P=""
    [ "${BASTILLE_JSON_PRETTY:-0}" -eq 1 ] && BASTILLE_JSON_P="--pretty"
    if [ "${BASTILLE_JSON_OPEN:-0}" -eq 1 ]; then
        # Document already open: close the entity list (empty or
        # partial) and attach error as a sibling so any records already
        # emitted stay in the array.
        xo ${BASTILLE_JSON_P} --json --not-first --depth 2 --close-list "${BASTILLE_JSON_ENTITY}"
    else
        # Nothing opened yet. type=error and skip the list — a list
        # keyed "error" would collide with the error object.
        xo ${BASTILLE_JSON_P} --json --top-wrap --open bastille
        xo ${BASTILLE_JSON_P} --json --depth 2 "{:type}" error
    fi
    xo ${BASTILLE_JSON_P} --json --not-first --depth 2 --open error
    xo ${BASTILLE_JSON_P} --json --depth 3 "{:message}" "${1}"
    xo ${BASTILLE_JSON_P} --json --depth 2 --close error
    xo ${BASTILLE_JSON_P} --json --top-wrap --close bastille
    BASTILLE_JSON_DONE=1
    BASTILLE_JSON_OPEN=0
}

json_close() {
    # json_close  ->  closes ]}}
    [ "${BASTILLE_JSON}" -eq 1 ] || return 0
    # json_error already closed the document so the envelope is valid
    # before we exit 1; do not emit a second closer.
    [ "${BASTILLE_JSON_DONE:-0}" -eq 1 ] && return 0
    xo ${BASTILLE_JSON_P} --json --not-first --depth 2 --close-list "${BASTILLE_JSON_ENTITY}"
    xo ${BASTILLE_JSON_P} --json --top-wrap --close bastille
    BASTILLE_JSON_DONE=1
    BASTILLE_JSON_OPEN=0
}
