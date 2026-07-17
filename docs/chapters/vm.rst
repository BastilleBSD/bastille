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
  kldload vmm nmdm if_bridge if_tap

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
- ``DISK name size [zfsprop=val ...]`` -- creates and attaches a virtio-blk
  zvol in declaration order.
- ``NIC bridge`` -- creates a persistently named tap (``vm-<name>-<n>``) and
  adds it to the named bridge (default: ``bastille_vm_bridge``).
- ``ISO url|path`` -- attaches installation media as an ahci-cd device. Remote
  URLs are fetched into the Bastille cache.
- ``ADDRESS ip`` -- records the guest address (required for ``RDR``).
- ``RDR proto host_port vm_port`` -- recorded for a future release; pf wiring
  for VMs is not yet enabled.

Jail-only verbs (``PKG``, ``SYSRC``, ``CP``, ``CMD``, ``SERVICE`` ...) are
errors in a VM template; a template is one brand.

Lifecycle
---------

.. code-block:: shell

  bastille create --vm builder sasha/forgejo-runner-vm
  bastille start builder
  bastille console builder        # serial console; detach with ~.
  bastille list                   # VMs appear with Type 'vm'
  bastille stop builder
  bastille destroy builder

``bastille list`` grows a VM row per VM with a ``Type`` column of ``vm``;
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

This is an initial implementation. Suspend/resume, live migration, cloud-init
seeding, graphical (VNC) consoles, Windows guests, and PCI passthrough are out
of scope for this release. The ``bhyve.args`` file is the debuggable boundary
between the manifest and the hypervisor: if a VM misbehaves, read and diff it.
