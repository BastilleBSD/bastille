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

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille zfs TARGET [set|get|snap] [key=value|date]'${COLOR_RESET}"
    exit 1
}

zfs_snapshot() {
for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
    zfs snapshot -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"@"${TAG}"
    echo
done
}

zfs_set_value() {
for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
    zfs "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
    echo
done
}

zfs_get_value() {
for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
    zfs get "${ATTRIBUTE}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
    echo
done
}

zfs_disk_usage() {
for _jail in ${JAILS}; do
    echo -e "${COLOR_GREEN}[${_jail}]:${COLOR_RESET}"
    zfs list -t all -o name,used,avail,refer,mountpoint,compress,ratio -r "${bastille_zfs_zpool}/${bastille_zfs_prefix}/jails/${_jail}"
    echo
done
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

## check ZFS enabled
if [ ! "${bastille_zfs_enable}" = "YES" ]; then
    echo -e "${COLOR_RED}ZFS not enabled.${COLOR_RESET}"
    exit 1
fi

## check zpool defined
if [ -z "${bastille_zfs_zpool}" ]; then
    echo -e "${COLOR_RED}ZFS zpool not defined.${COLOR_RESET}"
    exit 1
fi

if [ $# -lt 2 ]; then
    usage
fi

TARGET="${1}"

if [ "${TARGET}" = 'ALL' ]; then
    JAILS=$(jls name)
fi

if [ "${TARGET}" != 'ALL' ]; then
    JAILS=$(jls name | awk "/^${TARGET}$/")
fi

case "$2" in
set)
    ATTRIBUTE=$3
    JAILS=${JAILS}
    zfs_set_value
    ;;
get)
    ATTRIBUTE=$3
    JAILS=${JAILS}
    zfs_get_value
    ;;
snap|snapshot)
    TAG=$3
    JAILS=${JAILS}
    zfs_snapshot
    ;;
df|usage)
    zfs_disk_usage
    ;;
esac
