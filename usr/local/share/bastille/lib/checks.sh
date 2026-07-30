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

# Guard and predicate helpers.

bastille_root_check() {
    if [ "$(id -u)" -ne 0 ]; then
        ## permission denied
        error_notify "Bastille: Permission Denied"
        error_exit "root / sudo / doas required"
    fi
}

check_target_exists() {
    local target="${1}"
    local jail_list="$(bastille list jails)"
    if ! echo "${jail_list}" | grep -Eq "^${target}$"; then
        return 1
    else
        return 0
    fi
}

check_target_is_running() {
    local target="${1}"
    if ! jls name | grep -Eq "^${target}$"; then
        return 1
    else
        return 0
    fi
}

check_target_is_stopped() {
    local target="${1}"
    if jls name | grep -Eq "^${target}$"; then
        return 1
    else
        return 0
    fi
}

checkyesno() {
    ## copied from /etc/rc.subr -- cedwards (20231125)
    ## issue #368 (lowercase values should be parsed)
    ## now used for all bastille_zfs_enable=YES|NO tests
    ## example: if checkyesno bastille_zfs_enable; then ...
    ## returns 0 for enabled; returns 1 for disabled
    eval value=\$${1}
    case $value in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
        return 0
        ;;
    [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
        return 1
        ;;
    *)
        warn 1 "\$${1} is not set properly - see rc.conf(5)."
        return 1
        ;;
    esac
}

# Validate a release name (used when converting a jail/thick release). Rejects
# names beginning with (-|_) or containing anything outside [a-zA-Z0-9-_].
# Exits non-zero on an invalid name.
validate_release_name() {

    local name=${1}
    local sanity="$(echo "${name}" | tr -c -d 'a-zA-Z0-9-_')"

    if [ -n "$(echo "${sanity}" | awk "/^[-_].*$/" )" ]; then
        error_exit "[ERROR]: Release names may not begin with (-|_) characters!"
    elif [ "${name}" != "${sanity}" ]; then
        error_exit "[ERROR]: Release names may not contain special characters!"
    fi

}

# Validate a comma-separated CPU list against the host's available CPUs.
# Returns non-zero (without exiting) on the first unavailable CPU so the caller
# can 'continue'.
validate_cpus() {

    local cpus="${1}"

    for cpu in $(echo ${cpus} | sed 's/,/ /g'); do
        if ! cpuset -l ${cpu} 2>/dev/null; then
            error_notify "[ERROR]: CPU is not available: ${cpu}"
            return 1
        fi
    done

}
