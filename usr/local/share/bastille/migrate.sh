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

. /usr/local/share/bastille/common.sh

usage() {
    error_notify "Usage: bastille migrate [option(s)] TARGET HOST [USER]"
    cat << EOF
	
    Options:

    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -d | --destroy          Destroy local jail after migration.
    -x | --debug            Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
OPT_DESTROY=0
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -d|--destroy)
            OPT_DESTROY=1
            shift
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            for _opt in $(echo ${1} | sed 's/-//g' | fold -w1); do
                case ${_opt} in
                    a) AUTO=1 ;;
                    d) OPT_DESTROY=1 ;;
                    x) enable_debug ;;
                    *) error_exit "[ERROR]: Unknown Option: \"${1}\"" ;; 
                esac
            done
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 3 ]; then
    usage
fi

TARGET="${1}"
HOST="${2}"
USER="${3}"

bastille_root_check
set_target "${TARGET}"

validate_host_status() {

    local _host="${1}"
    local _user="${2}"
    
    info "\nChecking remote host status..."

    # Host uptime
    if ! ping -c 1 ${_host} >/dev/null 2>/dev/null; then
        error_exit "[ERROR]: Host appears to be down"
    fi

    # Host SSH check
    if ! ssh ${_user}@${_host} exit >/dev/null 2>/dev/null; then
        error_notify "[ERROR]: Could not establish ssh connection to host."
        error_exit "Please make sure user '${_user}' has password-less access."
    fi

    echo "Host check successful."
}

migrate_cleanup() {

    local _jail"${1}"

    # Remove archive files from local and remote system
    ssh ${_user}@${_host} sudo rm -f "${_remote_bastille_migratedir}/${_jail}_*.*"
    rm -f "${bastille_migratedir}/${_jail}_*.*"
}

migrate_create_export() {

    local _jail="${1}"

    info "\nPreparing jail for migration..."

    # Ensure migrate directory is in place
    ## ${bastille_migratedir}
    if [ ! -d "${bastille_migratedir}" ]; then
        if checkyesno bastille_zfs_enable; then
            if [ -n "${bastille_zfs_zpool}" ]; then
                zfs create ${bastille_zfs_options} -o mountpoint="${bastille_migratedir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/migrate"
            fi
        else
            mkdir -p "${bastille_migratedir}"
        fi
        chmod 0750 "${bastille_migratedir}"
    fi

    # --xz for ZFS, otherwise --txz
    if checkyesno bastille_zfs_enable; then
        bastille export --xz ${_jail} ${bastille_migratedir}
    else
        bastille export --txz ${_jail} ${_bastille_migratedir}
    fi
}

migrate_jail() {

    local _jail="${1}"
    local _host="${2}"
    local _user="${3}"

    local _remote_bastille_zfs_enable="$(ssh ${_user}@${_host} sysrc -f /usr/local/etc/bastille/bastille.conf -n bastille_zfs_enable)"
    local _remote_bastille_jailsdir="$(ssh ${_user}@${_host} sysrc -f /usr/local/etc/bastille/bastille.conf -n bastille_jailsdir)"
    local _remote_bastille_migratedir="$(ssh ${_user}@${_host} sysrc -f /usr/local/etc/bastille/bastille.conf -n bastille_migratedir)"
    local _remote_jail_list="$(ssh ${_user}@${_host} bastille list jails)"

    # Verify jail does not exist remotely
    if echo ${_remote_jail_list} | grep -Eoq "^${TARGET}$"; then
        migrate_cleanup "${_jail}"
        error_exit "[ERROR]: Jail already exists on remote system: ${TARGET}"
    fi

    # Verify ZFS on both systems
    if checkyesno bastille_zfs_enable; then
        if ! checkyesno _remote_bastille_zfs_enable; then
            migrate_cleanup "${_jail}"
            error_notify "[ERROR]: ZFS is enabled locally, but not remotely."
            error_exit "Enable ZFS remotely to continue."
        else

            info "\nAttempting to migrate jail to remote system..."

            local _file="$(find "${bastille_migratedir}" -maxdepth 1 -type f | grep -Eo "${_jail}_.*\.xz$" | head -n1)"
            local _file_sha256="$(find "${bastille_migratedir}" -maxdepth 1 -type f | grep -Eo "${_jail}_.*\.sha256$" | head -n1)"

            # Send sha256
            if ! scp ${bastille_migratedir}/${_file_sha256} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}"
                error_exit "[ERROR]: Failed to send jail to remote system."
            fi

            # Send jail export
            if ! scp ${bastille_migratedir}/${_file} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}"
                error_exit "[ERROR]: Failed to send jail to remote system."
            fi
        fi
    else
        if checkyesno _remote_bastille_zfs_enable; then
            migrate_cleanup "${_jail}"
            error_notify "[ERROR]: ZFS is enabled remotely, but not locally."
            error_exit "Enable ZFS locally to continue."
        else

            info "\nAttempting to migrate jail to remote system..."

            local _file="$(find "${bastille_migratedir}" -maxdepth 1 -type f | grep -Eo "${_jail}_.*\.txz$" | head -n1)"
            local _file_sha256="$(find "${bastille_migratedir}" -maxdepth 1 -type f | grep -Eo "${_jail}_.*\.sha256$" | head -n1)"

            # Send sha256
            if ! scp ${bastille_migratedir}/${_file_sha256} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}"
                error_exit "[ERROR]: Failed to migrate jail to remote system."
            fi

            # Send jail export
            if ! scp ${bastille_migratedir}/${_file} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}"
                error_exit "[ERROR]: Failed to migrate jail to remote system."
            fi
        fi
    fi

    # Import the jail remotely
    if ! ssh ${_user}@${_host} sudo bastille import ${_remote_bastille_migratedir}/${_file}; then
        migrate_cleanup "${_jail}"
        error_exit "[ERROR]: Failed to import jail on remote system."
    fi

    # Destroy old jail if FORCE=1
    if [ "${OPT_DESTROY}" -eq 1 ]; then
        bastille destroy -af "${_jail}"
    fi

    migrate_cleanup "${_jail}"
}

# Validate host uptime
validate_host_status "${HOST}" "${USER}"

for _jail in ${JAILS}; do

    (

    # Validate jail state
    check_target_is_stopped "${_jail}" || if [ "${AUTO}" -eq 1 ]; then
        bastille stop "${_jail}"
    else
        info "\n[${_jail}]:"
        error_notify "Jail is running."
        error_continue "Use [-a|--auto] to auto-stop the jail."
    fi

    info "\nAttempting to migrate '${_jail}' to '${HOST}'..."

    migrate_create_export "${_jail}"
    
    migrate_jail "${_jail}" "${HOST}" "${USER}"

    info "\nSuccessfully migrated '${_jail}' to '${HOST}'.\n"

    ) &

    bastille_running_jobs "${bastille_process_limit}"

done
wait
