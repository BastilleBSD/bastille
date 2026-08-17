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

. /usr/local/share/bastille/common.sh

usage() {
    error_notify "Usage: bastille plugin [option(s)] PLUGIN ARGS"
    exit 1
}

# Handle options
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -*)
            error_exit "[ERROR]: Unknown Option: \"${1}\""
            ;;
        *)
            break
            ;;
    esac
done

# Verify parameter count
if [ "$#" -lt 1 ]; then
    usage
fi

PLUGIN="${1}"
PLUGIN_CMD="${2}"

bastille_root_check

bootstrap_plugin() {

    local plugin_url="${1}"
    local plugin_name="$(basename "${plugin_url}" | sed 's/.git//')"

	   if echo "${plugin_url}" | grep -q "github.com"; then
	       local repo="$(echo "${plugin_url}" | awk -F"github.com/" '{print $2}' | sed 's/.git//')"
		      local manifest_url="https://raw.githubusercontent.com/${repo}/main/plugin.conf"
	   else
        error_exit "[ERROR]: Only supports github at this time."
    fi
	   # Check for manifest file
	   local manifest="$(mktemp)"
	   if ! fetch -o "${manifest}" "${manifest_url}"; then
        warn 1 "[WARNING]: No 'plugin.conf' found. Using repo name as plugin name."
		      local name="${plugin_name}"
	   else
        local name="$(sysrc -f "${manifest}" -n name 2>/dev/null)"
        local min_version="$(sysrc -f "${manifest}" -n min_version 2>/dev/null)"
		      local depends_kmods="$(sysrc -f "${manifest}" -n depends_kmods 2>/dev/null)"
        local depends_pkgs="$(sysrc -f "${manifest}" -n depends_pkgs 2>/dev/null)"
        # Validate plugin version against Bastille version
        if [ "$(echo "${min_version}" | sed 's/\.//g')" -gt "$(bastille version | sed 's/\.//g')" ]; then
            error_exit "[ERROR]: Bastille version is lower than the plugins required version."
        fi
    fi
	   rm "${manifest}"
    # Validate git command
    if ! which -s git; then
        error_exit "[ERROR]: Git not found."
    fi
	   # Validate method: fresh install or update
    if [ -d "${bastille_sharedir}/plugins/${name}" ]; then
        if ! git -C "${bastille_sharedir}/plugins/${name}" pull; then
            error_exit "[ERROR]: Failed to update plugin."
        fi
    else
        # Clone plugin repo
        if ! git clone "${plugin_url}" "${bastille_sharedir}/plugins/${name}"; then
            error_exit "[ERROR]: Failed to bootstrap plugin."
        else
            info 1 "Plugin bootstrapped. Use 'bastille -p|--plugin PLUGIN...' to run."
        fi
        # Load required plugin modules
	      	for kmod in ${depends_kmods}; do 
	           info 1 "\nLoading module: ${kmod}"
	    	      kldload -v "${kmod}" 2>/dev/null
	    	      info 1 "\nPersisting module: ${kmod}"
		          sysrc -f /boot/loader.conf ${kmod}_load=YES 2>/dev/null
	       done
	       # Install required plugin pkgs
	       for pkg in ${depends_pkgs}; do 
	           info 1 "\nInstalling package: ${pkg}"
		          pkg install -y ${pkg}
	       done
        info 1 "Plugin bootstrapped. Use 'bastille -p|--plugin PLUGIN...' to run."
	   fi
}

check_plugin_exists() {
    plugin="${1}"
    local plugin="${1}"

    if [ ! -d "${bastille_sharedir}/plugins/${plugin}" ]; then
        error_exit "[ERROR]: Plugin not found: ${plugin}"
    fi
}

case "${PLUGIN}" in
    http?://*/*/*)
        bootstrap_plugin "${PLUGIN}"
        exit 0
        ;;
    *)
        check_plugin_exists "${PLUGIN}"
        ;;
esac

# shellcheck disable=SC2154
SCRIPTPATH="${bastille_sharedir}/plugins/${PLUGIN}/${PLUGIN_CMD}.sh"

if [ -f "${SCRIPTPATH}" ]; then
    : "${UMASK:=022}"
    umask "${UMASK}"
    : "${SH:=sh}"
    exec ${SH} ${BASTILLE_DEBUG} "${SCRIPTPATH}" "$@"
else
    error_exit "[ERROR]: Plugin command not found: ${SCRIPTPATH}"
fi
