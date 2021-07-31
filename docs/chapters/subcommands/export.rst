======
export
======

Exporting a container creates an archive or image that can be sent to a
different machine to be imported later. These exported archives can be used as
container backups.

.. code-block:: shell

  ishmael ~ # bastille export azkaban

The export sub-command supports both UFS and ZFS storage. ZFS based containers
will use ZFS snapshots. UFS based containers will use `txz` archives and they
can be exported only when the jail is not running.

.. code-block:: shell

  Usage: bastille export TARGET
