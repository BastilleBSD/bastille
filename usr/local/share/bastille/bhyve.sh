#!/bin/sh
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Sasha Karcz <sasha@starnix.net>
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

# bhyve.sh -- shared library for Bastille bhyve VM support.
#
# A Bastille VM is a peer instance type to a jail. Every VM is described by a
# generated-but-authoritative manifest (vm.conf) and runs its bhyve(8) device
# model inside a minimal, auto-generated "supervision jail" with allow.vmm.
# The supervision jail is what makes a Bastille VM *a kind of jail* rather than
# a process standing beside jails: it gets a real JID, is visible to jls(8),
# and is constrained by rctl(8) like any other jail.
#
# This file is sourced by the VM-aware branches of create/start/stop/console/
# destroy/list. It never touches the jail code path.

# The VM's on-disk layout mirrors the per-jail directory:
#
#   ${bastille_vmdir}/<name>/
#     vm.conf          # canonical VM definition (rc.conf-style key=value)
#     supervisor.conf  # generated jail.conf for the supervision jail
#     bhyve.args       # materialized bhyve(8) argument vector (debuggable)
#     vm-run.sh        # generated supervisor entry point (loops bhyve)
#     settings.conf    # boot/priority/depend (shared convention with jails)
#     rdr.conf         # pf redirect rules (shared convention with jails)
#     console          # symlink to the nmdm console (client) side
#
# Disk images are zvols, not files, so `zfs snapshot -r` of the Bastille tree
# stays meaningful and VMs inherit the clone/rollback story jails already have:
#
#   ${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms/<name>/disk0

# The supervision jail is named "<name>" so it is a first-class peer of jails
# in jls/rctl. The bhyve vmm(4) instance shares the same name, exposed at
# /dev/vmm/<name>.

# ----------------------------------------------------------------------------
# Manifest (vm.conf) accessors
# ----------------------------------------------------------------------------

vm_config() {
    ## Path to a VM's manifest.
    local vm_name="${1}"
    echo "${bastille_vmdir}/${vm_name}/vm.conf"
}

vm_get() {
    ## Read a single value from a VM manifest.
    local vm_name="${1}"
    local key="${2}"
    sysrc -f "$(vm_config "${vm_name}")" -n "${key}" 2>/dev/null
}

vm_set() {
    ## Write a single value to a VM manifest.
    local vm_name="${1}"
    local key="${2}"
    local value="${3}"
    sysrc -f "$(vm_config "${vm_name}")" "${key}=${value}" >/dev/null
}

# ----------------------------------------------------------------------------
# nmdm / console helpers
# ----------------------------------------------------------------------------

vm_nmdm_host() {
    ## The host (bhyve) side of the null-modem console pair.
    echo "/dev/nmdm-${1}.1A"
}

vm_nmdm_client() {
    ## The client (operator) side, attached with cu(1) by `bastille console`.
    echo "/dev/nmdm-${1}.1B"
}

# NOTE: A restrictive devfs ruleset for the supervision jail is deliberately
# NOT applied in v1. With path=/ (see vm_generate_supervisor_conf) a
# mount.devfs would stack over the host's own /dev and hide host devices such
# as /dev/zfs. Isolating the VM's /dev requires a dedicated jail root, which is
# deferred; the config key bastille_vm_devfs_ruleset is reserved for that work.

# ----------------------------------------------------------------------------
# Disk (zvol) lifecycle
# ----------------------------------------------------------------------------

vm_disk_dataset() {
    ## Dataset path for a VM disk.
    local vm_name="${1}"
    local disk="${2}"
    echo "${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms/${vm_name}/${disk}"
}

vm_disk_device() {
    ## /dev path bhyve attaches for a VM disk.
    local vm_name="${1}"
    local disk="${2}"
    echo "/dev/zvol/$(vm_disk_dataset "${vm_name}" "${disk}")"
}

vm_create_disk() {
    ## Create a single zvol-backed disk. 'spec' is "name:size[,zfsprop=val,...]".
    local vm_name="${1}"
    local spec="${2}"
    local disk="$(echo "${spec}" | awk -F: '{print $1}')"
    local rest="$(echo "${spec}" | cut -s -d: -f2-)"
    local size="$(echo "${rest}" | awk -F, '{print $1}')"
    local props="$(echo "${rest}" | cut -s -d, -f2-)"
    local dataset="$(vm_disk_dataset "${vm_name}" "${disk}")"

    if [ -z "${disk}" ] || [ -z "${size}" ]; then
        error_exit "[ERROR]: Malformed DISK spec: ${spec}"
    fi

    # Assemble any per-disk zfs properties (comma-separated) into -o flags.
    # bhyve needs volmode=dev; add it as a default only if the user did not
    # already set volmode (otherwise zfs rejects the duplicate property).
    local zfs_props=""
    local has_volmode=0
    if [ -n "${props}" ]; then
        local IFS=','
        for prop in ${props}; do
            zfs_props="${zfs_props} ${prop}"
            case "${prop}" in
                volmode=*) has_volmode=1 ;;
            esac
        done
        unset IFS
    fi
    if [ "${has_volmode}" -eq 0 ]; then
        zfs_props="volmode=dev ${zfs_props}"
    fi
    local zfs_opts=""
    for prop in ${zfs_props}; do
        zfs_opts="${zfs_opts} -o ${prop}"
    done

    if zfs list "${dataset}" >/dev/null 2>&1; then
        info 2 "Disk already exists: ${dataset}"
        return 0
    fi

    info 1 "Creating disk ${disk} (${size}): ${dataset}"
    # shellcheck disable=SC2086
    if ! zfs create -V "${size}" ${zfs_opts} "${dataset}"; then
        error_exit "[ERROR]: Failed to create disk: ${dataset}"
    fi
}

# ----------------------------------------------------------------------------
# tap / bridge lifecycle
#
# bhyve's virtio-net backend opens /dev/<tap>, and renaming a tap interface
# does NOT rename its device node -- so we keep the kernel-assigned tapN name
# for bhyve and use the interface description for human legibility. The tapN
# names allocated for a running VM (one per NIC, in declaration order) are
# tracked in a runtime file so stop/destroy and the devfs ruleset can find them.
# ----------------------------------------------------------------------------

vm_taps_file() {
    echo "${bastille_vmdir}/${1}/taps"
}

vm_tap_list() {
    ## Ordered list of tap devices currently backing a VM's NICs.
    local taps_file="$(vm_taps_file "${1}")"
    if [ -f "${taps_file}" ]; then
        cat "${taps_file}"
    fi
}

vm_create_tap() {
    ## Create a tap, attach it to the named bridge, and echo its tapN name.
    ## Mirrors network.sh's `ifconfig <bridge> addm` model for jail epairs.
    local vm_name="${1}"
    local index="${2}"
    local bridge="${3}"

    if ! ifconfig -g bridge | grep -owq "${bridge}"; then
        error_exit "[ERROR]: '${bridge}' is not a bridge interface."
    fi

    local tap="$(ifconfig tap create)"
    if [ -z "${tap}" ]; then
        error_exit "[ERROR]: Failed to create tap interface for VM: ${vm_name}"
    fi
    ifconfig "${tap}" description "vm-${vm_name}-${index}: Bastille VM ${vm_name} nic${index}" >/dev/null
    ifconfig "${tap}" up >/dev/null
    ifconfig "${bridge}" addm "${tap}" >/dev/null
    echo "${tap}"
}

vm_create_taps() {
    ## Create every tap for a VM (one per NIC), recording the tapN names.
    local vm_name="${1}"
    local nics="$(vm_get "${vm_name}" nics)"
    local taps_file="$(vm_taps_file "${vm_name}")"

    : > "${taps_file}"
    local index=0
    for bridge in ${nics}; do
        vm_create_tap "${vm_name}" "${index}" "${bridge}" >> "${taps_file}"
        index=$((index + 1))
    done
}

vm_destroy_taps() {
    ## Tear down every tap recorded for a VM and clear the runtime file.
    local vm_name="${1}"
    for tap in $(vm_tap_list "${vm_name}"); do
        if ifconfig "${tap}" >/dev/null 2>&1; then
            ifconfig "${tap}" destroy >/dev/null 2>&1
        fi
    done
    rm -f "$(vm_taps_file "${vm_name}")"
}

# VNET mode: instead of a host tap on a host bridge, the supervision jail is a
# VNET jail and the guest's networking lives inside it. For each NIC we create
# an epair (host side onto the named bridge) plus a guest tap; both the
# jail-side epair and the tap are moved into the jail's own vnet at jail
# creation and bridged together inside the jail (see vm_generate_supervisor_conf).
# The host sees only the a-side of the epair, exactly like a VNET jail.

vm_epairs_file() {
    echo "${bastille_vmdir}/${1}/epairs"
}

vm_epair_list() {
    ## One "epair_a epair_b" pair per NIC, in declaration order.
    local epairs_file="$(vm_epairs_file "${1}")"
    if [ -f "${epairs_file}" ]; then
        cat "${epairs_file}"
    fi
}

vm_create_vnet() {
    ## Create the host-side interfaces for every NIC of a VNET VM. Records tap
    ## names (for the bhyve argument vector) and epair pairs (for supervisor.conf
    ## and teardown). The jail-side epair and the tap are moved into the jail's
    ## vnet by the generated supervisor.conf at jail creation.
    local vm_name="${1}"
    local nics="$(vm_get "${vm_name}" nics)"
    local taps_file="$(vm_taps_file "${vm_name}")"
    local epairs_file="$(vm_epairs_file "${vm_name}")"

    : > "${taps_file}"
    : > "${epairs_file}"
    local index=0
    for bridge in ${nics}; do
        if ! ifconfig -g bridge | grep -owq "${bridge}"; then
            error_exit "[ERROR]: '${bridge}' is not a bridge interface."
        fi
        local epair_a="$(ifconfig epair create)"
        if [ -z "${epair_a}" ]; then
            error_exit "[ERROR]: Failed to create epair for VM: ${vm_name}"
        fi
        local epair_b="${epair_a%a}b"
        ifconfig "${epair_a}" description "vm-${vm_name}-${index}: Bastille VM ${vm_name} nic${index} uplink" >/dev/null
        ifconfig "${epair_a}" up >/dev/null
        ifconfig "${bridge}" addm "${epair_a}" >/dev/null
        local tap="$(ifconfig tap create)"
        if [ -z "${tap}" ]; then
            error_exit "[ERROR]: Failed to create tap for VM: ${vm_name}"
        fi
        ifconfig "${tap}" description "vm-${vm_name}-${index}: Bastille VM ${vm_name} nic${index}" >/dev/null
        printf '%s\n' "${tap}" >> "${taps_file}"
        printf '%s %s\n' "${epair_a}" "${epair_b}" >> "${epairs_file}"
        index=$((index + 1))
    done
}

vm_destroy_vnet() {
    ## Tear down VNET interfaces. jail -r already destroys the jail's own vnet
    ## interfaces (jail-side epair, tap, in-jail bridge); this cleans up the
    ## host-side epair and any stragglers idempotently, then clears the files.
    local vm_name="${1}"
    local epairs_file="$(vm_epairs_file "${vm_name}")"
    if [ -f "${epairs_file}" ]; then
        while read -r epair_a epair_b; do
            for iface in ${epair_a} ${epair_b}; do
                if [ -n "${iface}" ] && ifconfig "${iface}" >/dev/null 2>&1; then
                    ifconfig "${iface}" destroy >/dev/null 2>&1
                fi
            done
        done < "${epairs_file}"
    fi
    for tap in $(vm_tap_list "${vm_name}"); do
        if ifconfig "${tap}" >/dev/null 2>&1; then
            ifconfig "${tap}" destroy >/dev/null 2>&1
        fi
    done
    rm -f "$(vm_epairs_file "${vm_name}")" "$(vm_taps_file "${vm_name}")"
}

# ----------------------------------------------------------------------------
# bhyve argument generation
# ----------------------------------------------------------------------------

vm_generate_args() {
    ## Materialize the bhyve(8) argument vector into bhyve.args. This file is
    ## the debuggable boundary between manifest and hypervisor: users read and
    ## diff it, and the supervisor runs exactly what it contains.
    local vm_name="${1}"
    local vmdir="${bastille_vmdir}/${vm_name}"
    local args_file="${vmdir}/bhyve.args"

    local cpu="$(vm_get "${vm_name}" cpu)"
    local memory="$(vm_get "${vm_name}" memory)"
    local bootrom="$(vm_get "${vm_name}" bootrom)"
    local disks="$(vm_get "${vm_name}" disks)"
    local nics="$(vm_get "${vm_name}" nics)"
    local iso="$(vm_get "${vm_name}" iso)"

    : "${cpu:=1}"
    : "${memory:=512M}"
    : "${bootrom:=${bastille_vm_bootrom}}"

    if [ ! -r "${bootrom}" ]; then
        warn 1 "[WARNING]: UEFI firmware not found: ${bootrom}"
        warn 1 "Install sysutils/edk2-bhyve or set 'bastille_vm_bootrom'."
    fi

    # PCI slot layout: 0 hostbridge, 31 lpc (fixed), devices from slot 3 up.
    local slot=3

    {
        printf '%s\n' "-c ${cpu}"
        printf '%s\n' "-m ${memory}"
        # -A ACPI tables, -H yield on HLT, -P exit on PAUSE, -w ignore bad MSR.
        printf '%s\n' "-AHPw"
        printf '%s\n' "-s 0,hostbridge"
        printf '%s\n' "-s 31,lpc"
        printf '%s\n' "-l bootrom,${bootrom}"
        printf '%s\n' "-l com1,$(vm_nmdm_host "${vm_name}")"

        # Disks in declaration order.
        local disk_type="${bastille_vm_disk_type:-virtio-blk}"
        for spec in ${disks}; do
            local disk="$(echo "${spec}" | awk -F: '{print $1}')"
            printf '%s\n' "-s ${slot},${disk_type},$(vm_disk_device "${vm_name}" "${disk}")"
            slot=$((slot + 1))
        done

        # NICs in declaration order, backed by the tap devices allocated at
        # start. Before the taps exist (e.g. bhyve.args written at create time)
        # a placeholder is emitted; the file is regenerated at start.
        local nic_type="${bastille_vm_nic_type:-virtio-net}"
        local nic_index=0
        local taps="$(vm_tap_list "${vm_name}")"
        for _bridge in ${nics}; do
            local backend="$(echo "${taps}" | sed -n "$((nic_index + 1))p")"
            : "${backend:=tap-pending${nic_index}}"
            printf '%s\n' "-s ${slot},${nic_type},${backend}"
            slot=$((slot + 1))
            nic_index=$((nic_index + 1))
        done

        # Installation media (first boot).
        if [ -n "${iso}" ]; then
            printf '%s\n' "-s ${slot},ahci-cd,${iso}"
            slot=$((slot + 1))
        fi

        # The vmm(4) instance name is the VM name, matching the jail name.
        printf '%s\n' "${vm_name}"
    } > "${args_file}"

    info 2 "Wrote bhyve arguments: ${args_file}"
}

# ----------------------------------------------------------------------------
# supervisor entry point + jail.conf generation
# ----------------------------------------------------------------------------

vm_generate_run_script() {
    ## Generate the supervisor entry point. bhyve(8) exits 0 to request a
    ## reboot and non-zero to power off; the loop mirrors what every hypervisor
    ## supervisor does. On final exit the vmm device is destroyed so the VM can
    ## cleanly restart later.
    local vm_name="${1}"
    local run_script="${bastille_vmdir}/${vm_name}/vm-run.sh"

    cat << EOF > "${run_script}"
#!/bin/sh
# Generated by Bastille -- do not edit. Regenerated on every 'bastille start'.
vm_name="${vm_name}"
args_file="${bastille_vmdir}/${vm_name}/bhyve.args"

while :; do
    # Destroy any prior vmm instance first. bhyve does not tear down
    # /dev/vmm/<name> on exit, so this must run before every boot -- including
    # a guest-requested reboot -- or the next bhyve would fail "already in use".
    bhyvectl --destroy --vm="\${vm_name}" >/dev/null 2>&1
    # shellcheck disable=SC2046
    bhyve \$(cat "\${args_file}")
    rc=\$?
    # 0 = guest requested reboot; anything else = power off / halt / error.
    if [ "\${rc}" -ne 0 ]; then
        break
    fi
done

bhyvectl --destroy --vm="\${vm_name}" >/dev/null 2>&1
EOF
    chmod 0700 "${run_script}"
}

vm_generate_supervisor_conf() {
    ## Generate the supervision jail.conf. The jail carries allow.vmm and an
    ## rctl memory cap derived from MEM (applied separately) so bhyve's wired
    ## guest RAM is accounted for, giving the VM a real JID that jls and rctl
    ## treat as a peer of jails.
    ##
    ## NOTE: this v1 jail uses path=/ and shares the host's /dev. It does NOT
    ## use mount.devfs + a restrictive devfs_ruleset: with path=/ that would
    ## stack a locked-down devfs over the host's own /dev and hide host devices
    ## (e.g. /dev/zfs). Proper devfs confinement -- a dedicated jail root with
    ## its own isolated /dev exposing only this VM's vmm/tap/nmdm devices -- is
    ## the intended hardening and is deferred until it can be validated on real
    ## bhyve hardware. Confinement today is allow.vmm + rctl + the jail
    ## namespace, layered on bhyve's own Capsicum sandbox.
    local vm_name="${1}"
    local supervisor_conf="${bastille_vmdir}/${vm_name}/supervisor.conf"
    local run_script="${bastille_vmdir}/${vm_name}/vm-run.sh"
    local network_type="$(vm_get "${vm_name}" network_type)"
    : "${network_type:=shared}"

    # bhyve runs a foreground loop, so daemon(8) backgrounds it -- otherwise
    # 'jail -c' would block until the guest powers off. bhyve stays confined to
    # this jail because daemon(8) runs inside it. The </dev/null and >/dev/null
    # redirections detach the daemon subtree from jail -c's stdio so
    # 'bastille start' (and the rc.d boot pipeline) return promptly instead of
    # hanging on an inherited stdout pipe; bhyve output still goes to the -o log.
    local launch="/usr/sbin/daemon -o ${bastille_logsdir}/${vm_name}_vm.log /bin/sh ${run_script} </dev/null >/dev/null 2>&1"

    if [ "${network_type}" = "vnet" ]; then
        # VNET mode: the jail owns its network stack. Move each NIC's jail-side
        # epair and tap into the vnet, then bridge them together inside the jail
        # before launching bhyve. Interface names come from the runtime files
        # written by vm_create_vnet, so they are known at render time.
        local iface_lines=""
        local bridge_lines=""
        local taps_file="$(vm_taps_file "${vm_name}")"
        local nic=0
        while read -r epair_a epair_b; do
            local tap="$(sed -n "$((nic + 1))p" "${taps_file}")"
            iface_lines="${iface_lines}  vnet.interface += ${epair_b};
  vnet.interface += ${tap};
"
            bridge_lines="${bridge_lines}  exec.start += \"ifconfig bridge${nic} create && ifconfig bridge${nic} addm ${epair_b} addm ${tap} up && ifconfig ${epair_b} up && ifconfig ${tap} up\";
"
            nic=$((nic + 1))
        done < "$(vm_epairs_file "${vm_name}")"

        cat << EOF > "${supervisor_conf}"
${vm_name} {
  # Bastille bhyve supervision jail (generated, VNET mode).
  # This is an implementation detail; edit vm.conf, not this file.
  path = /;
  host.hostname = ${vm_name};
  persist;
  allow.vmm;
  enforce_statfs = 1;
  vnet;
${iface_lines}  exec.clean;
${bridge_lines}  exec.start += "${launch}";
  exec.stop = "";
}
EOF
    else
        cat << EOF > "${supervisor_conf}"
${vm_name} {
  # Bastille bhyve supervision jail (generated, shared mode).
  # This is an implementation detail; edit vm.conf, not this file.
  path = /;
  host.hostname = ${vm_name};
  persist;
  allow.vmm;
  enforce_statfs = 1;
  exec.clean;
  exec.start = "${launch}";
  exec.stop = "";
}
EOF
    fi
}

# ----------------------------------------------------------------------------
# rctl memory accounting
# ----------------------------------------------------------------------------

vm_memory_bytes() {
    ## Convert a bhyve memory string (e.g. 8G, 512M) to bytes for rctl.
    local mem="${1}"
    local num="$(echo "${mem}" | sed -E 's/[^0-9]//g')"
    local unit="$(echo "${mem}" | sed -E 's/[0-9]//g' | tr '[:lower:]' '[:upper:]')"
    case "${unit}" in
        T) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        G) echo $((num * 1024 * 1024 * 1024)) ;;
        # A bare number is megabytes, matching bhyve's own -m interpretation.
        M|"") echo $((num * 1024 * 1024)) ;;
        K) echo $((num * 1024)) ;;
        *) echo "" ;;
    esac
}

vm_apply_rctl() {
    ## Cap the supervision jail's memory at guest RAM + overhead. bhyve wires
    ## the full guest memory, so this bounds the VM's host-side footprint.
    local vm_name="${1}"
    local memory="$(vm_get "${vm_name}" memory)"
    local bytes="$(vm_memory_bytes "${memory}")"
    if [ -z "${bytes}" ]; then
        return 0
    fi
    # Add ~256MB overhead for the device model process itself.
    local cap=$((bytes + 268435456))
    rctl -a "jail:${vm_name}:memoryuse:deny=${cap}" >/dev/null 2>&1
}

# ----------------------------------------------------------------------------
# Manifest rendering from a VM template
# ----------------------------------------------------------------------------

vm_resolve_bootrom() {
    ## Map a BOOTROM verb value to a firmware path.
    ##   uefi      -> edk2-bhyve UEFI firmware (default)
    ##   uefi-csm  -> UEFI + legacy CSM
    ##   <path>    -> used as-is
    local spec="${1}"
    local firmware_dir="$(dirname "${bastille_vm_bootrom}")"
    case "${spec}" in
        uefi|UEFI|"")
            echo "${bastille_vm_bootrom}"
            ;;
        uefi-csm|UEFI-CSM)
            echo "${firmware_dir}/BHYVE_UEFI_CSM.fd"
            ;;
        *)
            echo "${spec}"
            ;;
    esac
}

vm_fetch_iso() {
    ## Resolve an ISO verb value to a local path, fetching remote media into
    ## the Bastille cache (mirrors bootstrap's caching posture).
    local spec="${1}"
    case "${spec}" in
        http://*|https://*|ftp://*)
            local iso_cache="${bastille_cachedir}/iso"
            local iso_name="$(basename "${spec}")"
            local iso_path="${iso_cache}/${iso_name}"
            if [ ! -f "${iso_path}" ]; then
                mkdir -p "${iso_cache}"
                info 1 "Fetching ISO: ${spec}"
                if ! fetch -o "${iso_path}" "${spec}"; then
                    error_exit "[ERROR]: Failed to fetch ISO: ${spec}"
                fi
            fi
            echo "${iso_path}"
            ;;
        *)
            echo "${spec}"
            ;;
    esac
}

vm_guess_os_from_iso() {
    ## Best-effort guest OS label from an install ISO's name, shown in
    ## 'bastille list' instead of a generic "uefi-guest". The result is a
    ## single whitespace-free token (like "15.0-RELEASE" for jails) so it does
    ## not break the JSON/columnar output. Returns empty if nothing recognized.
    local iso="${1}"
    [ -n "${iso}" ] || return 0
    local base="$(basename "${iso}" | tr '[:upper:]' '[:lower:]')"
    local name=""
    case "${base}" in
        *alpine*)   name="Alpine" ;;
        *ubuntu*)   name="Ubuntu" ;;
        *debian*)   name="Debian" ;;
        *rocky*)    name="Rocky" ;;
        *alma*)     name="AlmaLinux" ;;
        *fedora*)   name="Fedora" ;;
        *centos*)   name="CentOS" ;;
        *freebsd*)  name="FreeBSD" ;;
        *arch*)     name="Arch" ;;
        *opensuse*|*suse*) name="openSUSE" ;;
        *) return 0 ;;
    esac
    # Arch is rolling; its "version" is a date, so leave it unversioned.
    if [ "${name}" = "Arch" ]; then
        echo "${name}"
        return 0
    fi
    local ver="$(echo "${base}" | grep -Eo '[0-9]+(\.[0-9]+)?' | head -1)"
    if [ -n "${ver}" ]; then
        echo "${name}-${ver}"
    else
        echo "${name}"
    fi
}

vm_create() {
    ## Render a VM template into an authoritative manifest, then create the
    ## backing zvols. Networking taps are created lazily at start time.
    local vm_name="${1}"
    local template="${2}"
    local network_type="${3:-shared}"
    local template_dir="${bastille_templatesdir}/${template}"
    local bastillefile="${template_dir}/Bastillefile"
    local vmdir="${bastille_vmdir}/${vm_name}"

    if [ ! -s "${bastillefile}" ]; then
        error_exit "[ERROR]: Template not found: ${template}"
    fi

    # Parsed manifest fields.
    local M_CPU="1"
    local M_MEM="512M"
    local M_BOOTROM="${bastille_vm_bootrom}"
    local M_DISKS=""
    local M_NICS=""
    local M_ISO=""
    local M_ADDRESS=""
    local M_OS=""
    local RDR_RULES=""
    local seen_vm=0

    # Join line continuations, drop blank/comment lines (template.sh idiom).
    local SCRIPT
    SCRIPT=$(awk '{ if (substr($0, length, 1) == "\\") { printf "%s", substr($0, 1, length-1); } else { print $0; } }' "${bastillefile}" | grep -v '^[[:blank:]]*$' | grep -v '^[[:blank:]]*#')

    local IFS='
'
    set -f
    for line in ${SCRIPT}; do
        local verb="$(echo "${line}" | awk '{print toupper($1)}')"
        local args="$(echo "${line}" | awk '{$1=""; sub(/^ */, ""); print}')"

        # The VM verb must open the file; it declares the template's brand.
        if [ "${seen_vm}" -eq 0 ] && [ "${verb}" != "VM" ]; then
            set +f
            unset IFS
            error_exit "[ERROR]: VM templates must begin with the 'VM' verb."
        fi

        case "${verb}" in
            VM)
                seen_vm=1
                ;;
            CPU)
                if ! echo "${args}" | grep -Eq '^[0-9]+$'; then
                    set +f; unset IFS
                    error_exit "[ERROR]: CPU must be an integer: ${args}"
                fi
                M_CPU="${args}"
                ;;
            MEM|MEMORY)
                M_MEM="${args}"
                ;;
            BOOTROM)
                M_BOOTROM="$(vm_resolve_bootrom "${args}")"
                ;;
            DISK)
                # "DISK disk0 40G [prop=val ...]" -> "disk0:40G[,prop=val,...]"
                local d_name="$(echo "${args}" | awk '{print $1}')"
                local d_size="$(echo "${args}" | awk '{print $2}')"
                local d_props="$(echo "${args}" | awk '{$1="";$2="";sub(/^ */,"");print}' | tr ' ' ',')"
                if [ -z "${d_name}" ] || [ -z "${d_size}" ]; then
                    set +f; unset IFS
                    error_exit "[ERROR]: DISK requires a name and size: ${args}"
                fi
                local d_spec="${d_name}:${d_size}"
                if [ -n "${d_props}" ]; then
                    d_spec="${d_spec},${d_props}"
                fi
                M_DISKS="${M_DISKS} ${d_spec}"
                ;;
            NIC)
                local n_bridge="$(echo "${args}" | awk '{print $1}')"
                : "${n_bridge:=${bastille_vm_bridge}}"
                M_NICS="${M_NICS} ${n_bridge}"
                ;;
            ISO)
                M_ISO="$(vm_fetch_iso "${args}")"
                ;;
            ADDRESS)
                M_ADDRESS="$(echo "${args}" | awk '{print $1}')"
                ;;
            OS)
                # Human label for the guest OS shown in 'bastille list'
                # (e.g. "Ubuntu 24.04"). Overrides the guess from the ISO name.
                M_OS="${args}"
                ;;
            RDR)
                RDR_RULES="${RDR_RULES}${args}
"
                ;;
            PKG|HPKG|SYSRC|CP|COPY|CMD|SERVICE|OVERLAY|MOUNT|FSTAB|RENDER)
                set +f; unset IFS
                error_exit "[ERROR]: '${verb}' is a jail verb and is not valid in a VM template."
                ;;
            *)
                set +f; unset IFS
                error_exit "[ERROR]: Unknown VM verb: ${verb}"
                ;;
        esac
    done
    set +f
    unset IFS

    # Trim leading spaces on accumulated lists.
    M_DISKS="$(echo "${M_DISKS}" | sed 's/^ *//')"
    M_NICS="$(echo "${M_NICS}" | sed 's/^ *//')"

    if [ -z "${M_DISKS}" ]; then
        error_exit "[ERROR]: A VM template must declare at least one DISK."
    fi

    # VM support requires ZFS in v1 (halves the storage code, matches where
    # serious deployments already are -- see the design doc's Open Questions).
    if ! checkyesno bastille_zfs_enable || [ -z "${bastille_zfs_zpool}" ]; then
        error_exit "[ERROR]: VM support requires ZFS (set bastille_zfs_enable=YES)."
    fi

    # Create the VM datasets first; their mountpoints materialize the instance
    # directory. Pin the parent mountpoint to bastille_vmdir (mirrors bootstrap).
    if ! zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms" >/dev/null 2>&1; then
        if ! zfs create -o mountpoint="${bastille_vmdir}" "${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms"; then
            error_exit "[ERROR]: Failed to create VM parent dataset."
        fi
    fi
    if ! zfs list "${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms/${vm_name}" >/dev/null 2>&1; then
        if ! zfs create "${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms/${vm_name}"; then
            error_exit "[ERROR]: Failed to create VM dataset: ${vm_name}"
        fi
    fi

    # Lock down the instance directory (root-only), matching bastille_prefix.
    mkdir -p "${vmdir}"
    chmod 0700 "${vmdir}"

    vm_set "${vm_name}" version "1"
    vm_set "${vm_name}" cpu "${M_CPU}"
    vm_set "${vm_name}" memory "${M_MEM}"
    vm_set "${vm_name}" bootrom "${M_BOOTROM}"
    vm_set "${vm_name}" disks "${M_DISKS}"
    vm_set "${vm_name}" nics "${M_NICS}"
    vm_set "${vm_name}" iso "${M_ISO}"
    vm_set "${vm_name}" address "${M_ADDRESS}"
    vm_set "${vm_name}" network_type "${network_type}"

    # Guest OS label for 'bastille list' (Release column). Prefer an explicit
    # OS verb, else guess from the ISO name. Collapse whitespace to a single
    # token so it never breaks the columnar/JSON output.
    if [ -z "${M_OS}" ]; then
        M_OS="$(vm_guess_os_from_iso "${M_ISO}")"
    fi
    M_OS="$(echo "${M_OS}" | tr -s ' ' '-' | sed 's/^-//;s/-$//')"
    vm_set "${vm_name}" os "${M_OS}"

    # Boot/priority settings shared with the jail convention.
    sysrc -f "${vmdir}/settings.conf" boot="${BOOT:-on}" >/dev/null
    sysrc -f "${vmdir}/settings.conf" depend="" >/dev/null
    sysrc -f "${vmdir}/settings.conf" priority="${PRIORITY:-99}" >/dev/null

    # Create backing disks.
    for spec in ${M_DISKS}; do
        vm_create_disk "${vm_name}" "${spec}"
    done

    # Persist RDR rules for later application (needs ADDRESS).
    if [ -n "${RDR_RULES}" ]; then
        if [ -z "${M_ADDRESS}" ]; then
            warn 1 "[WARNING]: RDR declared without ADDRESS; skipping redirect rules."
        else
            printf '%s' "${RDR_RULES}" > "${vmdir}/rdr.conf.pending"
            info 2 "Recorded pending RDR rules: ${vmdir}/rdr.conf.pending"
        fi
    fi

    # Materialize derived artifacts (bhyve.args, supervisor.conf, vm-run.sh).
    vm_render_artifacts "${vm_name}"

    # Console convenience symlink.
    ln -sf "$(vm_nmdm_client "${vm_name}")" "${vmdir}/console"

    info 1 "\nVM created: ${vm_name}"
    info 1 "Review the invocation at: ${vmdir}/bhyve.args"
}

# ----------------------------------------------------------------------------
# High-level lifecycle actions
# ----------------------------------------------------------------------------

vm_render_artifacts() {
    ## (Re)generate every derived artifact from the manifest. Called by create
    ## and again by start so a hand-edited vm.conf is always honored.
    local vm_name="${1}"
    vm_generate_args "${vm_name}"
    vm_generate_run_script "${vm_name}"
    vm_generate_supervisor_conf "${vm_name}"
}

vm_start() {
    local vm_name="${1}"

    if check_vm_is_running "${vm_name}"; then
        error_notify "VM is already running."
        return 1
    fi

    local network_type="$(vm_get "${vm_name}" network_type)"
    : "${network_type:=shared}"

    # Create host-side interfaces first so their names flow into the bhyve
    # argument vector (and, for VNET, the supervisor.conf), then regenerate
    # artifacts (honors manifest edits). Order matters: vm_generate_args and the
    # VNET supervisor.conf read the taps/epairs runtime files.
    if [ "${network_type}" = "vnet" ]; then
        vm_create_vnet "${vm_name}"
    else
        vm_create_taps "${vm_name}"
    fi
    vm_render_artifacts "${vm_name}"

    # Start the supervision jail; its exec.start execs the bhyve loop (and, for
    # VNET, first builds the in-jail bridge).
    if ! jail -f "${bastille_vmdir}/${vm_name}/supervisor.conf" -c "${vm_name}"; then
        error_notify "[ERROR]: Failed to start supervision jail: ${vm_name}"
        if [ "${network_type}" = "vnet" ]; then
            vm_destroy_vnet "${vm_name}"
        else
            vm_destroy_taps "${vm_name}"
        fi
        return 1
    fi

    vm_apply_rctl "${vm_name}"

    # NOTE: pf redirect (RDR) application for VMs is Phase 2. Rules declared in
    # the template are recorded to rdr.conf.pending at create time; wiring them
    # to pf (via an ADDRESS-aware rdr.sh branch) lands with the Phase 2 work.

    return 0
}

vm_stop() {
    local vm_name="${1}"
    local force="${2}"
    local timeout="${bastille_vm_shutdown_timeout:-30}"

    if check_vm_is_stopped "${vm_name}"; then
        error_notify "VM is already stopped."
        return 1
    fi

    if [ "${force}" != "1" ] && check_vm_guest_is_running "${vm_name}"; then
        # Graceful ACPI poweroff: bhyve raises a virtual power button on TERM.
        # FreeBSD signal names have no SIG prefix (pkill -TERM, not -SIGTERM).
        # Poll the guest (vmm instance), not the jail: the persistent jail
        # lingers until we remove it below, so it is not the shutdown signal.
        info 1 "Requesting graceful shutdown (timeout ${timeout}s)..."
        pkill -TERM -f "bhyve.*[ ]${vm_name}\$" >/dev/null 2>&1
        local waited=0
        while [ "${waited}" -lt "${timeout}" ]; do
            if ! check_vm_guest_is_running "${vm_name}"; then
                break
            fi
            sleep 1
            waited=$((waited + 1))
        done
    fi

    # Force poweroff if the guest is still live (or if forced up front).
    if check_vm_guest_is_running "${vm_name}"; then
        warn 1 "Forcing power off: ${vm_name}"
        bhyvectl --force-poweroff --vm="${vm_name}" >/dev/null 2>&1
    fi

    # Remove the supervision jail.
    if jls name | grep -Eq "^${vm_name}\$"; then
        jail -f "${bastille_vmdir}/${vm_name}/supervisor.conf" -r "${vm_name}" >/dev/null 2>&1
    fi

    # Destroy the vmm instance and tear down networking.
    bhyvectl --destroy --vm="${vm_name}" >/dev/null 2>&1
    if [ "$(vm_get "${vm_name}" network_type)" = "vnet" ]; then
        vm_destroy_vnet "${vm_name}"
    else
        vm_destroy_taps "${vm_name}"
    fi

    return 0
}

vm_console() {
    ## Attach to the VM serial console over nmdm(4) with cu(1). The exact
    ## analogue of `zlogin -C` for an illumos bhyve zone. Detach with ~. .
    local vm_name="${1}"
    local client="$(vm_nmdm_client "${vm_name}")"

    if ! check_vm_guest_is_running "${vm_name}"; then
        error_notify "VM guest is not running (no bhyve instance)."
        return 1
    fi
    if [ ! -e "${client}" ]; then
        error_notify "[ERROR]: Console device not found: ${client}"
        return 1
    fi
    info 1 "Attaching to ${vm_name} console (detach with ~.)"
    cu -l "${client}" -s 115200
}

vm_destroy() {
    ## Tear down the VM: stop it, destroy its disks (with force semantics
    ## matching jails) and remove its instance directory.
    local vm_name="${1}"
    local force="${2}"

    if check_vm_is_running "${vm_name}"; then
        vm_stop "${vm_name}" 1
    fi

    # Destroy zvol-backed disks.
    if checkyesno bastille_zfs_enable && [ -n "${bastille_zfs_zpool}" ]; then
        local dataset="${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms/${vm_name}"
        if zfs list "${dataset}" >/dev/null 2>&1; then
            local opts="-r"
            if [ "${force}" = "1" ]; then
                opts="-rf"
            fi
            if ! zfs destroy "${opts}" "${dataset}"; then
                error_notify "[ERROR]: VM dataset appears busy: ${dataset}"
                return 1
            fi
        fi
    fi

    # Clear pf redirect anchors, mirroring destroy.sh for jails.
    pfctl -a "rdr/${vm_name}" -Fn >/dev/null 2>&1
    pfctl -a "bastille/${vm_name}" -Fr >/dev/null 2>&1

    # Remove the instance directory. The :? guards ensure this can never
    # expand to '/' should either variable somehow be empty.
    if [ -d "${bastille_vmdir}/${vm_name}" ]; then
        rm -rf "${bastille_vmdir:?}/${vm_name:?}"
    fi

    return 0
}
