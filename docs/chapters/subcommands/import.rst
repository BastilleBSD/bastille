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
      -M | --static-mac     Use a static/persistent MAC address (VNET only) when importing foreign jails.
      -v | --verbose        Enable verbose mode (ZFS only).
      -x | --debug          Enable debug mode.

      Tip: If no option specified, container should be imported from standard input.