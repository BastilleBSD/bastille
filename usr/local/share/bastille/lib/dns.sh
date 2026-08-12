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

bastille_dns_add_entry() {

    local type="${1}"
    local jail="${2}"
    local ip="${3}"
    local bastille_dns_network_ip="$(echo "${bastille_dns_network}" | cut -d/ -f1)"
    local bastille_dns_network_subnet="$(echo "${bastille_dns_network}" | cut -d/ -f2)"

    # Validate DNS interface
    if ifconfig "${bastille_dns_interface}" >/dev/null 2>/dev/null; then
        error_notify "[ERROR]: DNS interface has not been configured."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate DNS ip
    if ifconfig "${bastille_dns_interface}" | grep -Eoq "inet: ${bastille_dns_network_ip} "; then
        error_notify "[ERROR]: DNS interface has not been configured."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate top leve domain
    if [ -z "${bastille_dns_domain}" ]; then
        bastille_dns_domain="bastille"
    fi
    # Set unbound cmd
    if ! command -v unbound-control >/dev/null 2>&1; then
        local dns_cmd="unbound-control"
    elif ! command -v local-unbound-control >/dev/null 2>&1; then
        local dns_cmd="local-unbound-control"
    else
        error_notify "[ERROR]: No valid DNS resolver found."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate unbound enabled
    if ! ${dns_cmd} status >/dev/null 2>&1; then
        error_notify "[ERROR]: DNS resolver is not enabled."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate unbound zone exists
    if ! ${dns_cmd} list_local_zones | grep -qE "^${bastille_dns_domain}. static$"; then
        ${dns_cmd} local_zone "${unbound_zone}" static >/dev/null 2>&1
    fi
    if [ "${type}" = "ipv4" ]; then
        type="A"
    elif [ "${type}" = "ipv6" ]; then
        type="AAAA"
    fi
    # Execute
    ${dns_cmd} "local_data" "${name}.${bastille_dns_domain}." "${type} ${ip}" >/dev/null 2>&1
}

bastille_dns_remove_entry() {

    local type="${1}"
    local jail="${2}"
    local ip="${3}"
    local bastille_dns_network_ip="$(echo "${bastille_dns_network}" | cut -d/ -f1)"
    local bastille_dns_network_subnet="$(echo "${bastille_dns_network}" | cut -d/ -f2)"

    # Validate DNS interface
    if ifconfig "${bastille_dns_interface}" >/dev/null 2>/dev/null; then
        error_notify "[ERROR]: DNS interface has not been configured."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate DNS ip
    if ifconfig "${bastille_dns_interface}" | grep -Eoq "inet: ${bastille_dns_network_ip} "; then
        error_notify "[ERROR]: DNS interface has not been configured."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate top leve domain
    if [ -z "${bastille_dns_domain}" ]; then
        bastille_dns_domain="bastille"
    fi
    # Set unbound cmd
    if ! command -v unbound-control >/dev/null 2>&1; then
        local dns_cmd="unbound-control"
    elif ! command -v local-unbound-control >/dev/null 2>&1; then
        local dns_cmd="local-unbound-control"
    else
        error_notify "[ERROR]: No valid DNS resolver found."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate unbound enabled
    if ! ${dns_cmd} status >/dev/null 2>&1; then
        error_notify "[ERROR]: DNS resolver is not enabled."
        error_continue "See 'bastille setup dns'."
    fi
    # Validate unbound zone exists
    if ! ${dns_cmd} list_local_zones | grep -qE "^${bastille_dns_domain}. static$"; then
        ${dns_cmd} local_zone "${unbound_zone}" static >/dev/null 2>&1
    fi
    if [ "${type}" = "ipv4" ]; then
        type="A"
    elif [ "${type}" = "ipv6" ]; then
        type="AAAA"
    fi
    # Execute
    ${dns_cmd} "local_data_remove" "${name}.${bastille_dns_domain}." "${type} ${ip}" >/dev/null 2>&1
}