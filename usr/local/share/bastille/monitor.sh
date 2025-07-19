#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2018-2025, Christer Edwards <christer.edwards@gmail.com>
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

usage() {
    error_notify "Usage: bastille monitor [option(s)] TARGET [add|delete|list] [service1 service2]"
    cat << EOF

    Options:

    -x | --debug      Enable debug mode.
    -e | --enable     Enable (install) bastille-monitor cronjob. Configurable in bastille.conf.
    -d | --disable    Disable (uninstall) bastille-monitor cronjob.
    -s | --status     Return monitor status (Enabled or Disabled).

EOF
    exit 1
}

LOGFILE="/var/log/bastille/monitor.log"

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
        ;;
        -x|--debug)
            enable_debug
            shift
        ;;
        -e|--enable)
            if [ ! -f "${bastille_monitor_cron_path}" ]; then
                mkdir -p /usr/local/etc/cron.d
                echo "${bastille_monitor_cron}" >> "${bastille_monitor_cron_path}"
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Added cron entry at ${bastille_monitor_cron_path}" >> "${LOGFILE}"
                echo "Cron entry enabled."
	    else
                echo "Cron entry already enabled."
	    fi
            shift
            exit 0
        ;;
        -d|--disable)
            if [ -f "${bastille_monitor_cron_path}" ]; then
                rm -f "${bastille_monitor_cron_path}"
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Removed cron entry at ${bastille_monitor_cron_path}" >> "${LOGFILE}"
                echo "Cron entry disabled."
	    else
                echo "Cron entry already disabled."
            fi
            shift
            exit 0
        ;;
        -s|--status)
            if [ -f "${bastille_monitor_cron_path}" ]; then
                echo "Bastille Monitor is Enabled."
                exit 0
            else
                echo "Bastille Monitor is Disabled."
                exit 1
            fi
            shift
        ;;
        -*)
            error_exit "[ERROR]: Unknown Option: \"${1}\""
        ;;
        *)
            break
        ;;
    esac
done

if [ $# -gt 3 ]; then
    usage
fi

TARGET="${1}"
ACTION="${2}"
SERVICE="${3}"
SERVICE_FAILED=0

bastille_root_check
set_target "${TARGET}"

for _jail in ${JAILS}; do

    bastille_jail_monitor="${bastille_jailsdir}/${_jail}/monitor"

    ## skip if no monitor file
    if [ $? -eq 1 ] && [ ! -f "${bastille_jail_monitor}" ]; then
        continue
    fi

    ## iterate service(s) and check service status; restart on failure
    if [ $# -eq 1 ] && [ -z "${ACTION}" ] && [ -f "${bastille_jail_monitor}" ]; then
        for _service in $(xargs < "${bastille_jail_monitor}"); do
            ## check service status
            if ! bastille service "${_jail}" "${_service}" status; then
                echo "$(date '+%Y-%m-%d %H:%M:%S'): ${_service} service not running in ${_jail}. Restarting..." | tee -a "$LOGFILE"

                ## attempt to restart the service if needed; update logs if unable
                if ! bastille service "${_jail}" "${_service}" restart; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Failed to restart ${_service} service in ${_jail}." | tee -a "$LOGFILE"
                    SERVICE_FAILED=1
                fi
            fi
        done
    fi

    if [ -n "${ACTION}" ]; then
        case ${ACTION} in
            add)
                for _service in $(echo "${SERVICE}" | tr , ' '); do
                    echo "${_service}" >> "${bastille_jail_monitor}"
                    tmpfile="$(mktemp)"
                    sort "${bastille_jail_monitor}" | uniq > "${tmpfile}"
                    mv "${tmpfile}" "${bastille_jail_monitor}"
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Added monitor for ${_service} on ${_jail}" >> "${LOGFILE}"
                done
            ;;
            del*)
                for _service in $(echo "${SERVICE}" | tr , ' '); do
                    [ ! -f "${bastille_jail_monitor}" ] && break # skip if no monitor file
                    tmpfile="$(mktemp)"
                    grep -Ev "^${_service}\$" "${bastille_jail_monitor}" > "${tmpfile}"
                    mv "${tmpfile}" "${bastille_jail_monitor}"
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Removed monitor for ${_service} on ${_jail}" >> "${LOGFILE}"
                    # delete monitor file if empty
                    [ ! -s "${bastille_jail_monitor}" ] && rm "${bastille_jail_monitor}"
                done
            ;;
            list)
                if [ -n "${SERVICE}" ]; then
                    if echo "${SERVICE}" | grep ','; then
                        usage # Only one service per query
                    fi
                    [ ! -f "${bastille_jail_monitor}" ] && continue # skip if there is no monitor file
                    if grep -qE "^${SERVICE}\$" "${bastille_jail_monitor}"; then
                        #echo "${_jail}"
                        continue
                    fi
                else
                    if [ -f "${bastille_jail_monitor}" ]; then
                        echo -n "${_jail}: "
                        xargs < "${bastille_jail_monitor}"
                    fi
                fi
            ;;
            *)
                usage
            ;;
        esac
    fi

    bastille_running_jobs "${bastille_process_limit}"


done

# Final ping to healthcheck URL
if [ "$SERVICE_FAILED" -eq 0 ]; then
    if [ -n "${bastille_monitor_healthchecks}" ]; then
        curl -fsS --retry 3 "${bastille_monitor_healthchecks}" > /dev/null 2>&1
    else
        curl -fsS --retry 3 "${bastille_monitor_healthchecks}/fail" > /dev/null 2>&1
    fi
fi

wait
