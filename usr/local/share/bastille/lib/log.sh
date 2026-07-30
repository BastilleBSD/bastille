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

# Output, color and debug helpers.

# Default to empty color codes; enable_color() overrides these with the real
# escape sequences when output is a color-capable tty.
COLOR_RED=
COLOR_GREEN=
COLOR_YELLOW=
COLOR_RESET=

enable_color() {
    . /usr/local/share/bastille/colors.pre.sh
}

enable_debug() {
    local debug="${1}"
    warn 1 "***DEBUG MODE***"
    if [ "${debug}" -eq 1 ]; then
        set -x
        BASTILLE_DEBUG="-x"
    elif [ "${debug}" -eq 2 ]; then
        set -x
        export BASTILLE_DEBUG="-x"
    fi
}

# Error messages/functions
error_notify() {
    if [ "${BASTILLE_QUIET}" -ne 1 ]; then
        printf "%b\n" "${COLOR_RED}$*${COLOR_RESET}" >&2
    fi
}

error_continue() {
    error_notify "$@"
    # shellcheck disable=SC2104
    continue
}

error_exit() {
    error_notify "$@"
    exit 1
}

info() {
    level="${1}"
    shift 1
    # Level 3 should always be printed. See config subcommand
    if [ "${level}" -eq 3 ]; then
        printf "%b\n" "$*"
    elif [ "${BASTILLE_QUIET}" -ne 1 ] && [ "${level}" -ne 3 ]; then
        if [ "${level}" -eq 1 ]; then
            printf "%b\n" "${COLOR_GREEN}$*${COLOR_RESET}"
        elif [ "${level}" -eq 2 ]; then
            printf "%b\n" "$*"
        fi
    fi
}


warn() {
    level="${1}"
    shift 1
    # Level 3 should always be printed. See config subcommand
    if [ "${level}" -eq 3 ]; then
        printf "%b\n" "${COLOR_YELLOW}$*${COLOR_RESET}"
    elif [ "${BASTILLE_QUIET}" -ne 1 ] && [ "${level}" -ne 3 ]; then
        if [ "${level}" -eq 1 ]; then
            printf "%b\n" "${COLOR_YELLOW}$*${COLOR_RESET}"
        elif [ "${level}" -eq 2 ]; then
            printf "%b\n" "$*"
        fi
    fi
}
