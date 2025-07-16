zfs
===

Manage ZFS properties, ceate and destroy snapshots, and check ZFS usage for
targeted jail(s).

.. code-block:: shell

  ishmael ~ # bastille zfs help
  Usage: bastille zfs [option(s)] TARGET destroy|rollback|snapshot TAG"
                                         df|usage"
                                         get|set key=value"
                                         jail pool/dataset /jail/path"
                                         unjail pool/dataset"

      Options:

      -a | --auto             Auto mode. Start/stop jail(s) if required.
      -v | --verbose          Enable verbose mode.
      -x | --debug            Enable debug mode.