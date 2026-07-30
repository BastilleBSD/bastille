#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
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

# Storage, mountpoint and fstab helpers.

set_bastille_mountpoints() {
    if checkyesno bastille_zfs_enable; then
        # We have to do this if ALTROOT is enabled/present
        local altroot="$(zpool get -Ho value altroot ${bastille_zfs_zpool})"
        # Set mountpoints to *bastille*dir*
        # shellcheck disable=SC2034
        bastille_prefix_mountpoint="${bastille_prefix}"
        # shellcheck disable=SC2034
        bastille_backupsdir_mountpoint="${bastille_backupsdir}"
        # shellcheck disable=SC2034
        bastille_cachedir_mountpoint="${bastille_cachedir}"
        # shellcheck disable=SC2034
        bastille_jailsdir_mountpoint="${bastille_jailsdir}"
        # shellcheck disable=SC2034
        bastille_releasesdir_mountpoint="${bastille_releasesdir}"
        # shellcheck disable=SC2034
        bastille_templatesdir_mountpoint="${bastille_templatesdir}"
        # shellcheck disable=SC2034
        bastille_logsdir_mountpoint="${bastille_logsdir}"
        # Add _altroot to *dir* if set
        if [ "${altroot}" != "-" ]; then
            # Set *dir* to include ALTROOT
            bastille_prefix="${altroot}${bastille_prefix}"
            bastille_backupsdir="${altroot}${bastille_backupsdir}"
            bastille_cachedir="${altroot}${bastille_cachedir}"
            bastille_jailsdir="${altroot}${bastille_jailsdir}"
            bastille_releasesdir="${altroot}${bastille_releasesdir}"
            bastille_templatesdir="${altroot}${bastille_templatesdir}"
            bastille_logsdir="${altroot}${bastille_logsdir}"
        fi
    fi
}

update_fstab() {
    local oldname="${1}"
    local newname="${2}"
    local fstab="${bastille_jailsdir}/${newname}/fstab"
    if [ -f "${fstab}" ]; then
        sed -i '' "s|${bastille_jailsdir}/${oldname}/root/|${bastille_jailsdir}/${newname}/root/|" "${fstab}"
    else
        error_notify "Error: Failed to update fstab: ${newmane}"
    fi
}
