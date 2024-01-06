#!/bin/sh
#
# Copyright (c) 2018-2023, Rodrigo Nascimento Hernandez <rodrigomdev@gmail.com>
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
        # Update /etc folder while keeping user changes
        error_notify "Usage: bastille etcupdate [option(s)(optional)] [jailname] [oldrelease] [newrelease]"

        cat << EOF
        Options:

        -D | --dryrun   -- Do a dry run. Output actions to stdout but without making changes.
        -Q | --quiet    -- Do not output actions to stdout

EOF
        exit 1
}


executeconditional() {
    if [ $DRY_RUN -eq "0" ]; then
        eval "$@"
    fi
}

C1_C6_conditions() {
    filelistjail=$(find "${jail_etc}" -mindepth 1 -type f)
    for jailfile in ${filelistjail}
    do
        filepart=$(echo "${jailfile}" | awk -F 'etc/' '{print $NF}')
        newbasefile="${new_basedir}/etc/${filepart}"
        currentbasefile="${current_basedir}/etc/${filepart}"

        if [ ! -f "${currentbasefile}" ]; then
            if [ ! -f "${newbasefile}" ]; then
                C1=$((C1+1))
                C1ct="$C1ct${jailfile}\n"
            else
                C2=$((C2+1))
                C2ct="$C2ct${jailfile}\n"
            fi
        fi

        if [ -f "${currentbasefile}" ]; then
            diffr=$(diff -u "${jailfile}" "${currentbasefile}")
            if [ -z "${diffr}" ]; then
                if [ ! -f "${newbasefile}" ]; then
                    C3=$((C3+1))
                    C3ct="$C3ct${jailfile}\n"
                    cmd="rm -rf ${jailfile}"
                    executeconditional "$cmd"
                else
                    C4=$((C4+1))
                    C4ct="$C4ct${jailfile}\n"
                    cmd="cp -p ${newbasefile} ${jailfile}"
                    executeconditional "$cmd"
                    # Copy keeping permissions
                fi
            else
                diffs="${diffs}${diffr}"
                diffs="${diffs}\n==========================================================================================================\n\n"
                if [ -f "${newbasefile}" ]; then
                    C5=$((C5+1))
                    C5ct="$C5ct${jailfile}\n"
                else
                    C6=$((C6+1))
                    C6ct="$C6ct${jailfile}\n"
                fi
            fi
        fi
    done
}

# Creates missing directories from UPGRADEVERSION in the jail preserving original permissions
C7_conditions() {
dirlistrelease=$(find "${new_basedir}/etc" -mindepth 1 -type d)
    for dirpath in ${dirlistrelease}
    do
        dirpathnf=$(echo "${dirpath}" | awk -F '/etc' '{print $NF}')
        jailpath="${bastille_jail_base}/root/etc${dirpathnf}"
        if [ ! -d "${jailpath}" ]; then
            C7=$((C7+1))
            cmd="mkdir ${jailpath}"
            executeconditional "$cmd"
            dirperm=$(stat -f "%Mp%Lp" "${dirpath}")
            cmd="chmod ${dirperm} ${jailpath}"
            executeconditional "$cmd"
            C7ct="$C7ct${jailpath}\n"
        fi
    done
}

# Copy missing files from UPGRADEVERSION to the jail preserving original permissions
C8_conditions() {
filelistrelease=$(find "${new_basedir}/etc" -mindepth 1 -type f)
    for sourcefile in ${filelistrelease}
    do
        dirpathnf=$(echo "${sourcefile}" | awk -F '/etc' '{print $NF}')
        jailfile="${bastille_jail_base}/root/etc${dirpathnf}"
        if [ ! -f "${jailfile}" ]; then
            C8=$((C8+1))
            cmd="cp -p ${sourcefile} ${jailfile}"
            executeconditional "$cmd"
            C8ct="$C8ct${jailfile}\n"
        fi
    done
}

formatoutput() {
    output="SUMMARY:\n"
    txtvar=""
    txtname=""
    for x in 1 2 3 4 5 6 7 8; do
        eval txtvar="\$"C$x
        eval txtname="\$"C$x"txt"
        output="$output${txtname} = ${txtvar}\n"
    done

    output="${output}\nDETAILS:\n"

    for x in 1 2 3 4 5 6 7 8; do
        eval txtvar="\$"C$x"ct"
        eval txtname="\$"C$x"txt"
        output="${output}${txtname}\n${txtvar}"
        output="${output}==========================================================================================================\n\n"
    done

    output="${output}\nDIFF for files of conditions C5 & C6:\n"
    output="${output}${diffs}"

    printf '%b\n' "${output}"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
        usage
        ;;
esac

bastille_root_check

# Handle and parse options
DRY_RUN="0"
QUIET="0"
while [ $# -gt 0 ]; do
        case "${1}" in
                -D|--dryrun)
                        DRY_RUN="1"
                        shift
                        ;;
                -Q|--quiet)
                        QUIET="1"
                        shift
                        ;;
                -*|--*)
                        error_notify "Unknown Option."
                        usage
                        ;;
                *)
                        break
                        ;;
        esac
done

TARGET="${1}"
COMPAREVERSION="${2}"
UPGRADEVERSION="${3}"
bastille_jail_base="${bastille_jailsdir}/${TARGET}"

if [ $# -gt 3 ] || [ $# -lt 3 ]; then
        usage
fi

if [ "$(/usr/sbin/jls name | awk "/^${TARGET}$/")" ]; then
            error_notify "Jail running."
            error_exit "See 'bastille stop ${TARGET}'."
fi

if [ ! -d "${bastille_jail_base}" ]; then
        error_exit "Jail not found."
fi

## check for required releases
if [ ! -d "${bastille_releasesdir}/${COMPAREVERSION}" ] || [ ! -d "${bastille_releasesdir}/${UPGRADEVERSION}" ]; then
        error_exit "Releases must be bootstrapped first; see 'bastille bootstrap'."
fi

jail_root="${bastille_jail_base}/root"
jail_etc="${jail_root}/etc"
new_basedir="${bastille_releasesdir}/${UPGRADEVERSION}"
current_basedir="${bastille_releasesdir}/${COMPAREVERSION}"

    C1=0
    C1txt="Condition C1:\nJail's ./etc files that doesn't exist in \
${COMPAREVERSION} and doesn't exist in ${UPGRADEVERSION} Action: keep current files"
    C2=0
    C2txt="Condition C2:\nJail's ./etc files that doesn't exist in \
${COMPAREVERSION} but exist in ${UPGRADEVERSION} Action: keep current files"
    C3=0
    C3txt="Condition C3:\nJail's ./etc files that weren't modified when compared to \
${COMPAREVERSION} but doesn't exist in ${UPGRADEVERSION} Action: delete current files"
    C4=0
    C4txt="Condition C4:\nJail's ./etc files that weren't modified when compared to \
${COMPAREVERSION} and exist in ${UPGRADEVERSION} Action: update/copy the newer files"
    C5=0
    C5txt="Condition C5:\nJail's ./etc files that were modified when compared to \
${COMPAREVERSION} and exist in ${UPGRADEVERSION} Action: keep the current files"
    C6=0
    C6txt="Condition C6:\nJail's ./etc files that were modified when compared to \
${COMPAREVERSION} and doesn't exist in ${UPGRADEVERSION} Action: keep the current files"
    C7=0
    C7txt="Condition C7:\nCreate directories (with permissions) that exist in \
${UPGRADEVERSION} ./etc but doesn't exist in the jail"
    C8=0
    C8txt="Condition C8:\nCopy files (with permissions) that exist in \
${UPGRADEVERSION} ./etc but doesn't exist in the jail"
diffs=""

C1_C6_conditions
C7_conditions
C8_conditions
if [ $QUIET -eq "0" ]; then
    formatoutput
fi
