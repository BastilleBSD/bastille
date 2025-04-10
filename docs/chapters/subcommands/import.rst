import
======

Import a container backup image or archive.

.. code-block:: shell

  ishmael ~ # bastille import /path/to/archive.file

The import sub-command supports both UFS and ZFS storage. ZFS based containers
will use ZFS snapshots. UFS based containers will use ``txz`` archives.

To import to a specified release, specify it as the last argument.

.. code-block:: shell

  ishmael ~ # bastille import help
  Usage: bastille import [option(s)] FILE [RELEASE]
    Options:

    -f | --force               Force an archive import regardless if the checksum file does not match or missing.
    -M | --static-mac          Generate static MAC for jail when importing foreign jails like iocage.
    -v | --verbose             Be more verbose during the ZFS receive operation.
    -x | --debug               Enable debug mode.

  Tip: If no option specified, container should be imported from standard input.