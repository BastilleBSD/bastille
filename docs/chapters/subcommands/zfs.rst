zfs
===

Manage ZFS properties, create, destroy and rollback snapshots, jail and unjail
datasets (ZFS only), and check ZFS usage for targeted jail(s).

Snapshot Management
-------------------

Bastille has the ability to create, destroy, and rollback snapshots when using
ZFS. To create a snapshot, run ``bastille zfs TARGET snapshot``. This will create
a snapshot with the default ``bastille_TARGET_DATE`` naming scheme. You can also
specify a TAG to use as the naming scheme, such as ``bastille zfs TARGET snapshot mytag``.
Bastille will then create the snapshot with ``@mytag`` as the snapshot name.

Rolling back a snapshot follows the same syntax. If no TAG is supplied, Bastille
will attempt to use the most recent snapshot following the default naming scheme
above. To rollback a snapshot with a custom tag, run ``bastille zfs TARGET rollback``
or ``bastille zfs TARGET rollback mytag``.

To destroy a snaphot however, you must supply a TAG. To destroy a snapshot, run
``bastille zfs TARGET destroy mytag``.

.. code-block:: shell

  ishmael ~ # bastille zfs help
  Usage: bastille zfs [option(s)] TARGET snapshot|destroy|rollback [TAG]"
                                         df|usage"
                                         get|set KEY=VALUE"
                                         jail pool/dataset /jail/path"
                                         unjail pool/dataset"

      Options:

      -a | --auto        Auto mode. Start/stop jail(s) if required.
      -v | --verbose     Enable verbose mode.
      -x | --debug       Enable debug mode.
