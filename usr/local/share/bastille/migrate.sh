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
    error_notify "Usage: bastille migrate [option(s)] TARGET USER@HOST[:PORT]"
    cat << EOF

    Examples:

    bastille migrate attica migrate@192.168.10.100
    bastille migrate attica migrate@192.168.1.10:20022
    bastille migrate --keyfile id_rsa attica migrate@192.168.1.10

    Options:

    -a | --auto         Auto mode. Start/stop jail(s) if required.
    -b | --backup       Retain archives on remote system.
    -d | --destroy      Destroy local jail after migration.
       | --doas         Use 'doas' instead of 'sudo'.
    -k | --keyfile      Specify an alternative private keyfile name. Must be in '~/.ssh'
    -l | --live         Migrate a running jail (ZFS only).
    -p | --password     Use password based authentication.
    -x | --debug        Enable debug mode.

EOF
    exit 1
}

# Handle options.
AUTO=0
LIVE=0
OPT_BACKUP=0
OPT_DESTROY=0
OPT_KEYFILE=""
OPT_PASSWORD=0
OPT_SU="sudo"
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -a|--auto)
            AUTO=1
            shift
            ;;
        -b|--backup)
            OPT_BACKUP=1
            shift
            ;;
        -d|--destroy)
            OPT_DESTROY=1
            shift
            ;;
        --doas)
            OPT_SU="doas"
            shift
            ;;
        -k|--keyfile)
            OPT_KEYFILE="${2}"
            shift 2
            ;;
        -l|--live)
            LIVE=1
            shift
            ;;
        -p|--password)
            OPT_PASSWORD=1
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
                    b) OPT_BACKUP=1 ;;
                    d) OPT_DESTROY=1 ;;
                    l) LIVE=1 ;;
                    p) OPT_PASSWORD=1 ;;
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

# Validate options
if [ "${LIVE}" -eq 1 ]; then
    if ! checkyesno bastille_zfs_enable; then
        error_exit "[ERROR]: [-l|--live] can only be used with ZFS systems."
    fi
fi

if [ "$#" -ne 2 ]; then
    usage
fi

TARGET="${1}"
USER="$(echo ${2} | awk -F"@" '{print $1}')"
HOST="$(echo ${2} | awk -F"@" '{print $2}')"
if echo "${HOST}" | grep -q ":"; then
    PORT="$(echo ${HOST} | awk -F":" '{print $2}')"
    HOST="$(echo ${HOST} | awk -F":" '{print $1}')"
else
    PORT=22
fi

bastille_root_check
set_target "${TARGET}"

validate_host_status() {

    local _user="${1}"
    local _host="${2}"
    local _port="${3}"

    info "\nChecking remote host status..."

    # Host uptime
    if ! nc -w 1 -z ${_host} ${_port} >/dev/null 2>/dev/null; then
        error_exit "[ERROR]: Host appears to be down"
    fi

    # Host SSH check
    if [ "${OPT_PASSWORD}" -eq 1 ]; then
        if ! ${_sshpass_cmd} ssh -p ${_port} ${_user}@${_host} exit >/dev/null 2>/dev/null; then
            error_notify "[ERROR]: Could not establish ssh connection to host."
            error_notify "Please make sure the remote host supports password based authentication"
            error_exit "and you are using the correct password for user: '${_user}'"
        fi
    elif ! ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} exit >/dev/null 2>/dev/null; then
        error_notify "[ERROR]: Could not establish ssh connection to host."
        error_notify "Please make sure user '${_user}' has password-less access"
        error_exit "or use '-p|--password' for password based authentication."
    fi

    echo "Host check successful."
}

migrate_cleanup() {

    local _jail="${1}"
    local _user="${2}"
    local _host="${3}"
    local _port="${4}"

    # Backup archives on remote system
    if [ "${OPT_BACKUP}" -eq 1 ]; then

        _remote_bastille_backupsdir="$(${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} sysrc -f /usr/local/etc/bastille/bastille.conf -n bastille_backupsdir)"

        ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} cp "${_remote_bastille_migratedir}/*" "${_remote_bastille_backupsdir}"
    fi

    # Remove archive files from local and remote system
    ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} rm -fr "${_remote_bastille_migratedir}" 2>/dev/null
    rm -fr ${_local_bastille_migratedir} 2>/dev/null
}

migrate_create_export() {

    local _jail="${1}"
    local _user="${2}"
    local _host="${3}"
    local _port="${4}"

    info "\nPreparing jail for migration..."

    # Ensure /tmp/bastille-migrate has 777 perms
    chmod 777 ${_local_bastille_migratedir}
    ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} chmod 777 ${_remote_bastille_migratedir}

    # --xz for ZFS, otherwise --txz
    if checkyesno bastille_zfs_enable; then
        bastille export --xz ${_jail} ${_local_bastille_migratedir}
    else
        bastille export --txz ${_jail} ${_local_bastille_migratedir}
    fi
}

migrate_jail() {

    local _jail="${1}"
    local _user="${2}"
    local _host="${3}"
    local _port="${4}"

    _local_bastille_migratedir="$(mktemp -d /tmp/bastille-migrate-${_jail})"
    _remote_bastille_zfs_enable="$(${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} sysrc -f /usr/local/etc/bastille/bastille.conf -n bastille_zfs_enable)"
    _remote_bastille_jailsdir="$(${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} sysrc -f /usr/local/etc/bastille/bastille.conf -n bastille_jailsdir)"
    _remote_bastille_migratedir="$(${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} mktemp -d /tmp/bastille-migrate-${_jail})"
    _remote_jail_list="$(${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} bastille list jails)"

    if [ -z "${_local_bastille_migratedir}" ] || [ -z "${_remote_bastille_migratedir}" ]; then
        migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
        error_notify "[ERROR]: Could not create /tmp/bastille-migrate."
        error_continue "Ensure it doesn't exist locally or remotely."
    fi

    # Verify jail does not exist remotely
    if echo "${_remote_jail_list}" | grep -Eoqw "${_jail}"; then
        migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
        error_exit "[ERROR]: Jail already exists on remote system: ${_jail}"
    fi

    # Verify ZFS on both systems
    if checkyesno bastille_zfs_enable; then
        if ! checkyesno _remote_bastille_zfs_enable; then
            error_notify "[ERROR]: ZFS is enabled locally, but not remotely."
            error_exit "Enable ZFS remotely to continue."
        else

            migrate_create_export "${_jail}" "${_user}" "${_host}" "${_port}"

            info "\nAttempting to migrate jail to remote system..."

            _file="$(find "${_local_bastille_migratedir}" -maxdepth 1 -type f | grep -Eo "${_jail}_.*\.xz$" | head -n1)"
            _file_sha256="$(echo ${_file} | sed 's/\..*/.sha256/')"

            # Send sha256
            if ! ${_sshpass_cmd} scp -P ${_port} ${_opt_ssh_key} ${_local_bastille_migratedir}/${_file_sha256} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
                error_exit "[ERROR]: Failed to send jail to remote system."
            fi

            # Send jail export
            if ! ${_sshpass_cmd} scp -P ${_port} ${_opt_ssh_key} ${_local_bastille_migratedir}/${_file} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
                error_exit "[ERROR]: Failed to send jail to remote system."
            fi
        fi
    else
        if checkyesno _remote_bastille_zfs_enable; then
            error_notify "[ERROR]: ZFS is enabled remotely, but not locally."
            error_exit "Enable ZFS locally to continue."
        else

            info "\nAttempting to migrate jail to remote system..."

            migrate_create_export "${_jail}" "${_user}" "${_host}" "${_port}"

            _file="$(find "${_local_bastille_migratedir}" -maxdepth 1 -type f | grep -Eo "${_jail}_.*\.txz$" | head -n1)"
            _file_sha256="$(echo ${_file} | sed 's/\..*/.sha256/')"

            # Send sha256
            if ! ${_sshpass_cmd} scp -P ${_port} ${_opt_ssh_key} ${_local_bastille_migratedir}/${_file_sha256} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
                error_exit "[ERROR]: Failed to migrate jail to remote system."
            fi

            # Send jail export
            if ! ${_sshpass_cmd} scp -P ${_port} ${_opt_ssh_key} ${_local_bastille_migratedir}/${_file} ${_user}@${_host}:${_remote_bastille_migratedir}; then
                migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
                error_exit "[ERROR]: Failed to migrate jail to remote system."
            fi
        fi
    fi

    # Import the jail remotely
    if ! ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} bastille import ${_remote_bastille_migratedir}/${_file}; then
        migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"
        error_exit "[ERROR]: Failed to import jail on remote system."
    fi

    # Destroy old jail if OPT_DESTROY=1
    if [ "${OPT_DESTROY}" -eq 1 ]; then
        bastille destroy -afy "${_jail}"
    fi

    # Remove archives
    migrate_cleanup "${_jail}" "${_user}" "${_host}" "${_port}"

    # Reconcile LIVE and AUTO, ensure only one side is running
    if [ "${AUTO}" -eq 1 ] && [ "${LIVE}" -eq 0 ]; then
        ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} bastille start "${_jail}"
    elif [ "${AUTO}" -eq 1 ] && [ "${LIVE}" -eq 1 ]; then
        bastille stop "${_jail}"
        ${_sshpass_cmd} ssh -p ${_port} ${_opt_ssh_key} ${_user}@${_host} ${OPT_SU} bastille start "${_jail}"
    fi
}

# Determine if user wants to authenticate via password
if [ "${OPT_PASSWORD}" -eq 1 ]; then
    if ! which sshpass >/dev/null 2>/dev/null; then
        error_exit "[ERROR]: Please install 'sshpass' to use password based authentication."
    else
        warn "[WARNING]: Password based authentication can be insecure."
        printf "Please enter your password: "
        # We disable terminal output for the password
        stty -echo
        read _password
        stty echo
        printf "\n"
        _sshpass_cmd="sshpass -p ${_password}"
    fi
else
    _sshpass_cmd=
fi

# Get user we want to migrate as
# We need this to pass the ssh keys properly
if [ "${OPT_PASSWORD}" -eq 1 ]; then
    _opt_ssh_key=
else

    _migrate_user_home="$(getent passwd ${USER} | cut -d: -f6)"

    # Validate custom keyfile
    if [ -n "${OPT_KEYFILE}" ]; then
        if ! [ -f "${_migrate_user_home}/.ssh/${OPT_KEYFILE}" ]; then
            error_exit "[ERROR]: Keyfile not found: ${_migrate_user_home}/.ssh/${OPT_KEYFILE}"
        else
            _migrate_user_ssh_key="${_migrate_user_home}/.ssh/${OPT_KEYFILE}"
        fi
    else
        _migrate_user_ssh_key="find ${_migrate_user_home}/.ssh -maxdepth 1 -type f ! -name '*.pub' | grep -Eos 'id_.*'"
    fi

    _opt_ssh_key="-i ${_migrate_user_ssh_key}"

    # Exit if no keys found
    if [ -z "${_migrate_user_home}" ] || [ -z "${_migrate_user_ssh_key}" ]; then
        error_exit "[ERROR]: Could not find keys for user: ${USER}"
    # Exit if multiple keys
    elif [ "$(echo "${_migrate_user_ssh_key}" | wc -l)" -ne 1 ]; then
        error_notify "[ERROR]: Multiple ssh keys found:\n${_migrate_user_ssh_key}"
        error_exit "Please use -k|--keyfile to specify one."
    fi
fi

# Validate host uptime
validate_host_status "${USER}" "${HOST}" "${PORT}"

for _jail in ${JAILS}; do

    # Validate jail state
    if [ "${LIVE}" -eq 1 ]; then
        if ! check_target_is_running "${_jail}"; then
            error_exit "[ERROR]: [-l|--live] can only be used with a running jail."
        fi
    elif ! check_target_is_stopped "${_jail}"; then
        if [ "${AUTO}" -eq 1 ]; then
            bastille stop "${_jail}"
        else
            info "\n[${_jail}]:"
            error_notify "[ERROR]: Jail is running."
            error_exit "Use [-a|--auto] to auto-stop the jail, or [-l|--live] (ZFS only) to migrate a running jail."
        fi
    fi

    info "\nAttempting to migrate '${_jail}' to '${HOST}'..."

    migrate_jail "${_jail}" "${USER}" "${HOST}" "${PORT}"

    info "\nSuccessfully migrated '${_jail}' to '${HOST}'.\n"

done
echo
