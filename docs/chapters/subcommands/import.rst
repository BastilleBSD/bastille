import
======

Import a container backup image or archive.

.. code-block:: shell

  ishmael ~ # bastille import /path/to/archive.file

The import sub-command supports both UFS and ZFS storage. ZFS based containers
will use ZFS snapshots. UFS based containers will use `txz` archives.

To import to a specified release, specify it as the last argument.

.. code-block:: shell

  Usage: bastille import [option(s)] file [RELEASE]
