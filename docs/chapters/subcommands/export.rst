export
======

Exporting a container creates an archive or image that can be sent to a
different machine to be imported later. These exported archives can be used as
container backups.

.. code-block:: shell

  ishmael ~ # bastille export azkaban

The export sub-command supports both UFS and ZFS storage. ZFS based containers
will use ZFS snapshots. UFS based containers will use ``txz`` archives and they
can be exported only when the jail is not running.

.. code-block:: shell

  Usage:  bastille export [option(s)] TARGET PATH

Available options are:

.. code-block:: shell

  ishmael ~ # bastille export help
  Usage: bastille export [option(s)] TARGET [PATH]

      Options:

      -a | --auto        Auto mode. Start/stop jail(s) if required.
      -l | --live        Export a running jail (ZFS only).
           --gz          Export to a '.gz' compressed image (ZFS only).
           --xz          Export to a '.xz' compressed image (ZFS only).
           --zst         Export to a '.zst' compressed image (ZFS only).
           --raw         Export to an uncompressed RAW image (ZFS only).
           --tgz         Export to a '.tgz' compressed archive.
           --txz         Export to a '.txz' compressed archive.
           --tzst        Export to a '.tzst' compressed archive.
      -v | --verbose     Enable verbose mode (ZFS only).
      -x | --debug       Enable debug mode.

      Note: If no export option specified, the container should be redirected to standard output.
