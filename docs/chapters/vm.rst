Virtual Machines (bhyve)
========================

Bastille can manage `bhyve(8)` virtual machines as a peer instance type
alongside jails. A VM is defined by a git-trackable template, provisioned with
the existing template workflow, and driven by the same lifecycle verbs as
jails: ``create``, ``start``, ``stop``, ``console``, ``list`` and ``destroy``.

The goal is a single management plane for every workload on a FreeBSD host,
whether it runs on the host kernel (a jail) or brings its own kernel (a VM).

Requirements
------------

VM support is amd64-only and requires hardware virtualization (VT-x/EPT). On
the host:

.. code-block:: shell

  pkg install edk2-bhyve
  kldload vmm nmdm if_bridge if_tap if_epair

(``if_epair`` is only needed for VNET-mode VMs; add these to
``kld_list`` in ``/etc/rc.conf`` to load them at boot.)

VMs require ZFS. Set ``bastille_zfs_enable=YES`` and ``bastille_zfs_zpool`` in
``bastille.conf``. See the ``VM (bhyve) options`` block in the sample config
for the tunables (firmware path, default bridge, shutdown timeout, disk/NIC
device models, and the supervision-jail devfs ruleset).

The VM template
---------------

A VM template is an ordinary Bastille template whose ``Bastillefile`` opens
with the ``VM`` verb. The verbs after it configure the guest rather than a
jail:

.. code-block:: shell

  # Template: sasha/forgejo-runner-vm
  VM
  CPU 4
  MEM 8G
  BOOTROM uefi                 # uefi | uefi-csm | path to firmware
  DISK disk0 40G               # name + size; a zvol is created on create
  DISK disk1 200G volmode=dev  # extra disks; zfs props pass through
  NIC bridge0                  # a tap is created and added to bridge0
  ISO https://.../rocky-9.iso  # installation media (first boot)
  ADDRESS 10.0.0.40            # guest address (used by RDR)

Verb reference
~~~~~~~~~~~~~~

- ``VM`` -- switches the template into VM mode. Must be the first verb.
- ``CPU n`` -- virtual CPU count (``bhyve -c``).
- ``MEM size`` -- guest memory, e.g. ``8G`` (``bhyve -m``).
- ``BOOTROM spec`` -- ``uefi`` (default), ``uefi-csm``, or a firmware path.
- ``DISK name size [source=image] [zfsprop=val ...]`` creates and attaches a
  virtio-blk zvol in declaration order. With ``source=<url or path>`` Bastille
  populates the disk from a cloud/disk image at create time: a raw image is
  written with ``dd`` (no dependency), a qcow2 image is converted straight onto
  the zvol with ``qemu-img`` (``sysutils/qemu-tools``). This is how you boot a
  pre-built cloud image and let cloud-init provision it, instead of installing
  from an ISO.
- ``NIC bridge`` attaches the guest NIC to the named bridge (default:
  ``bastille_vm_bridge``). See "Networking modes" below.
- ``ISO url|path`` -- attaches installation media as an ahci-cd device. Remote
  URLs are fetched into the Bastille cache.
- ``ADDRESS ip`` -- records the guest address (required for ``RDR``).
- ``OS label`` -- guest OS label shown in the ``bastille list`` Release column
  (e.g. ``Ubuntu 24.04``). Optional; if omitted it is guessed from the ISO name
  (``alpine-virt-3.21.iso`` becomes ``Alpine-3.21``). Falls back to
  ``uefi-guest``.
- ``CLOUDINIT file`` takes a path (relative to the template directory, or
  absolute) to a cloud-init user-data file. Bastille builds a NoCloud ``CIDATA``
  seed from it (plus an auto-generated meta-data with the VM's instance-id and
  hostname) and attaches it as a virtio-blk disk. A cloud-init-enabled guest
  applies it at first boot: users, SSH keys, packages, ``runcmd``, and so on.
  Uses base ``makefs(8)``, no ports dependency. The seed is virtio-blk (not an
  optical device) so it is visible when the guest's cloud-init ``ds-identify``
  runs early in boot.
- ``NETWORK_CONFIG file`` adds a cloud-init network-config (v1 or v2) to the
  seed, so the guest gets a deterministic (for example static) address at first
  boot. cloud-init renders it to whatever the guest uses: netplan or
  systemd-networkd on Debian/Ubuntu, ifupdown (``/etc/network/interfaces``) on
  Alpine. One portability caveat: the netplan-style ``match`` selector is only
  honored by the netplan/networkd renderers. The ifupdown renderer uses the
  ``ethernets`` key as the literal interface name, so for those guests name the
  device directly (``eth0``) instead of a logical name plus ``match``. For
  example, ``ethernets: {eth0: {addresses: [...]}}`` works everywhere, whereas
  ``ethernets: {primary: {match: {name: "e*"}, ...}}`` only works on
  netplan/networkd guests.
- ``RDR proto host_port vm_port`` -- recorded for a future release; pf wiring
  for VMs is not yet enabled.

Jail-only verbs (``PKG``, ``SYSRC``, ``CP``, ``CMD``, ``SERVICE`` ...) are
errors in a VM template; a template is one brand.

Networking modes
~~~~~~~~~~~~~~~~

A VM's networking has two modes, chosen at create time the way jails choose
theirs:

- **shared** (default): the guest's tap is a member of the named host bridge,
  the pattern vm-bhyve uses. Simple, and the guest address is configured inside
  the guest.
- **VNET** (``bastille create --vm -V``): the supervision jail becomes a VNET
  jail, and the guest's tap lives inside the jail's own network stack, uplinked
  to the host bridge through an epair. The host sees only the a-side of the
  epair, so the VM's networking is fully contained in its jail, exactly like a
  VNET jail. This is the mode that makes "a VM is a jail" complete.

Lifecycle
---------

.. code-block:: shell

  bastille create --vm builder sasha/forgejo-runner-vm
  bastille start builder
  bastille console builder        # serial console; detach with ~.
  bastille list                   # VMs appear with Type 'vm'
  bastille clone builder ci-1 10.0.0.41   # near-instant golden-image clone
  bastille stop builder
  bastille destroy builder

Cloning is a ``zfs clone`` of the VM's zvols plus a manifest rewrite, so it is
near-instant and space-efficient: provision one base VM, then clone it per
worker. The clone shares unwritten blocks with the source (copy-on-write), so
the source cannot be destroyed while clones of it exist, which is the correct
golden-image behavior. By default the clone is an identical twin: the optional
third argument sets the clone's ``ADDRESS`` metadata, but the guest's in-VM
network config is copied as-is, so a plain clone should be reconfigured inside
the clone to avoid an address conflict with the source.

``--reseed`` makes the clone a distinct instance instead. It rebuilds the
cloud-init seed with a fresh ``instance-id``, so cloud-init treats the clone as
a new instance and re-runs its per-instance provisioning at first boot: it
applies the new address (``bastille clone --reseed src new 10.0.0.42``), sets
the hostname (``--hostname NAME``, default the clone name), re-applies users and
SSH keys, and regenerates the guest's SSH host keys. A new ``--reseed`` address
is refused if it is already in use, and both the ``network-config`` and the
``ADDRESS`` metadata are updated together so they cannot diverge. This is the
"stamp N distinct instances from one golden image at copy-on-write speed"
workflow. (Note: ``/etc/machine-id`` is still inherited from the source; a
future ``--clean`` will reset it.)

``bastille list`` grows a VM row per VM with a ``Type`` column of ``vm``. For a
VM the ``Release`` column shows the guest's Linux distribution and version (the
``OS`` label, or the value guessed from the ISO/image name), not a FreeBSD
release, so jails and VMs read uniformly in one listing:

.. code-block:: none

   JID  Name      State  Type  IP Address     Release       Tags
   3    nebula    Up     thin  192.168.1.56   15.0-RELEASE  -
   7    debian12  Up     vm    192.168.1.229  Debian-12     -
   8    alpine1   Up     vm    192.168.1.240  Alpine-3.21   -

(columns trimmed for brevity). A VM with no ``OS`` label and no guessable image
name falls back to ``uefi-guest`` (or ``uefi-csm`` for a CSM/BIOS guest).
``bastille list vms`` shows only VMs.

How it works
------------

Each VM's ``bhyve`` process runs inside a minimal, auto-generated
*supervision jail* with ``allow.vmm``. This gives the VM a real jail ID -- so
``jls`` and ``rctl`` treat it as a peer of jails -- while layering jail
confinement (namespace + rctl limits) on top of bhyve's Capsicum sandbox.

.. note::

   The v1 supervision jail uses ``path=/`` and shares the host's ``/dev``. A
   restrictive per-VM devfs ruleset that exposes only the VM's own vmm/tap/nmdm
   devices is the intended additional hardening, but it requires giving the
   jail its own root so its ``/dev`` is isolated from the host's -- deferred to
   a follow-up. The ``bastille_vm_devfs_ruleset`` config key is reserved for it.

The instance layout mirrors a jail's:

.. code-block:: text

  ${bastille_vmdir}/<name>/
    vm.conf          # canonical VM definition (edit this)
    supervisor.conf  # generated supervision jail.conf
    bhyve.args       # materialized bhyve(8) argument vector (read/diff this)
    vm-run.sh        # generated supervisor entry point
    settings.conf    # boot/priority (shared convention with jails)
    console          # symlink to the nmdm console

Disks are zvols under ``${bastille_zfs_zpool}/${bastille_zfs_prefix}/vms/<name>``
so ``zfs snapshot -r`` of the Bastille tree stays meaningful and VMs inherit
the clone/rollback story jails already enjoy.

Status
------

This is an initial implementation. Supported: the full create/start/stop/
console/list/destroy/clone lifecycle, **shared and VNET networking** (see
"Networking modes"), and **cloud-init seeding** (``CLOUDINIT`` user-data,
``NETWORK_CONFIG``, ``DISK source=`` cloud-image import, and ``clone --reseed``;
see the "Verb reference"). Suspend/resume, live migration, graphical (VNC)
consoles, Windows guests, and PCI passthrough are out of scope for this release.
The ``bhyve.args`` file is the debuggable boundary between the manifest and the
hypervisor: if a VM misbehaves, read and diff it.
