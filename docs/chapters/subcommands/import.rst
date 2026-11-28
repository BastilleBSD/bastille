import
======

.. code-block:: shell

  ishmael ~ # bastille import /path/to/archive.file

The import sub-command supports both UFS and ZFS storage. ZFS based containers
will use ZFS snapshots. UFS based containers will use ``txz`` archives.

To import to a specified release, specify it as the last argument.

.. code-block:: shell

  ishmael ~ # bastille import help
  Usage: bastille import [option(s)] FILE [RELEASE]

      Options:

      -f | --force          Force an archive import without validating checksum.
      -M | --mac TYPE       Specify a MAC address type when importing foreign jails (VNET only).
      -v | --verbose        Enable verbose mode (ZFS only).

      Tip: If no option specified, container should be imported from standard input.