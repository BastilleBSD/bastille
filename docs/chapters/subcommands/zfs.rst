zfs
===

Manage ZFS properties, ceate and destroy snapshots, and check ZFS usage for
targeted jail(s).

.. code-block:: shell

  ishmael ~ # bastille zfs help
  Usage: bastille zfs [option(s)] TARGET [destroy_snap|(df|usage)|get|set|(snap|snapshot)] [key=value|date]
                                         [jail pool/dataset /jail/path]
                                         [unjail pool/dataset]

      Options:

      -x | --debug          Enable debug mode.