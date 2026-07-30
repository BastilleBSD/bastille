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

# 'config' subcommand helpers.

# List of all supported jail.conf property names. Exits non-zero on an
# unsupported property.
validate_property() {

    local property="${1}"

    case "${property}" in
        jid|name|path|interface|ip_hostname) ;;
        ip4.addr|ip4.saddrsel|ip4|ip6.addr|ip6.saddrsel|ip6) ;;
        vnet|vnet.interface) ;;
        novnet) ;;
        host.hostname|host.domainname|host.hostuuid|host.hostid|host) ;;
        securelevel|devfs_ruleset|children.max|children.cur|enforce_statfs|persist|cpuset.id|parent) ;;
        nopersist) ;;
        osrelease|osreldate|meta|env) ;;
        allow.set_hostname|allow.sysvipc|allow.raw_sockets|allow.chflags) ;;
        allow.noset_hostname|allow.nosysvipc|allow.noraw_sockets|allow.nochflags) ;;
        allow.mount|allow.mount.devfs|allow.quotas|allow.read_msgbuf) ;;
        allow.nomount|allow.nomount.devfs|allow.noquotas|allow.noread_msgbuf) ;;
        allow.socket_af|allow.mlock|allow.nfsd|allow.reserved_ports) ;;
        allow.nosocket_af|allow.nomlock|allow.nonfsd|allow.noreserved_ports) ;;
        allow.unprivileged_parent_tampering|allow.unprivileged_proc_debug) ;;
        allow.nounprivileged_parent_tampering|allow.nounprivileged_proc_debug) ;;
        allow.suser|allow.extattr|allow.adjtime|allow.settime|allow.routing|allow.setaudit) ;;
        allow.nosuser|allow.noextattr|allow.noadjtime|allow.nosettime|allow.norouting|allow.nosetaudit) ;;
        allow.mount.fdescfs|allow.mount.fusefs|allow.mount.nullfs|allow.mount.procfs|allow.mount.linprocfs) ;;
        allow.nomount.fdescfs|allow.nomount.fusefs|allow.nomount.nullfs|allow.nomount.procfs|allow.nomount.linprocfs) ;;
        allow.mount.linsysfs|allow.mount.tmpfs|allow.mount.zfs|allow.vmm) ;;
        allow.nomount.linsysfs|allow.nomount.tmpfs|allow.nomount.zfs|allow.novmm) ;;
        linux|linux.osname|linux.osrelease|linux.oss_version) ;;
        sysvmsg|sysvsem|sysvshm|zfs.mount_snapshot) ;;
        exec.prepare|exec.prestart|exec.created|exec.start|command|exec.poststart) ;;
        exec.prestop|exec.stop|exec.poststop|exec.release|exec.clean) ;;
        exec.jail_user|exec.system_jail_user|exec.system_user|exec.timeout) ;;
        exec.consolelog|exec.fib|stop.timeout) ;;
        zfs.dataset|mount|mount.fstab|mount.devfs|mount.fdescfs|mount.procfs) ;;
        dying|allow.dying);;
        *) error_exit "[ERROR]: Unsupported property: ${property}" ;;
    esac
}

# If the property argument uses the "name=value" shorthand, split it into the
# PROPERTY and VALUE globals. A no-op when there is no '=' sign so a plain
# property name (with its VALUE supplied separately) is left untouched.
# Capture the raw argument first so deriving VALUE never reads the already
# reassigned PROPERTY.
config_split_property() {
    local raw_property="${1}"
    if echo "${raw_property}" | grep -q '='; then
        # PROPERTY/VALUE are consumed by the config subcommand (config.sh).
        # shellcheck disable=SC2034
        PROPERTY="$(echo ${raw_property} | awk -F"=" '{print $1}')"
        # shellcheck disable=SC2034
        VALUE="$(echo ${raw_property} | awk -F"=" '{print $2}')"
    fi
}

# Read the output of print_jail_conf on stdin and print the value of the named
# property. Prints "enabled" for a valueless (boolean) property, and "not set"
# with exit code 120 when the property is absent so the caller can warn.
config_get_value() {
    local property="${1}"
    # we need jail(8) to parse the config file so it can expand variables etc
    awk -F= -v property="${property}" '
        $1 == property {
            # note that we have found the property
            found = 1;
            # check if there is a value for this property
            if (NF == 2) {
                # remove any quotes surrounding the string
                sub(/^"/, "", $2);
                sub(/"$/, "", $2);
                print $2;
            } else {
                # no value, just the property name
                print "enabled";
            }
            exit 0;
        }
        END {
            # if we have not found anything we need to print a special string
            if (! found) {
                print("not set");
                #  let the caller know that this is a warn condition
                exit(120);
            }
        }'
}

# Read a jail.conf on stdin and print it back with the given property line
# substituted in place, or appended before the closing brace if it was absent.
config_set_line() {
    local property="${1}"
    local line="${2}"
    awk -F= -v line="${line}" -v property="${property}" '
        BEGIN {
            # build RE as string as we can not expand vars in RE literals
            prop_re = "^[[:space:]]*" property "[[:space:]]*;?$";
        }
        $1 ~ prop_re && !found {
            # we already have an entry in the config for this property so we
            # need to substitute our line here rather than keep the existing one
            print(line);
            # note we have already found the property
            found = 1;
            # move onto the next line
            next;
        }
        $1 == "}" {
            # reached the end of the stanza so if we have not already added our
            # line we need to do so now
            if (! found) {
                print(line);
            }
        }
        {
            # print each uninteresting line unchanged
            print;
        }'
}
