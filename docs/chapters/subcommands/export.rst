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
  Usage: bastille export [option(s)] TARGET PATH
    Options:

         --gz               Export a ZFS jail using GZIP(.gz) compressed image.
    -r | --raw              Export a ZFS jail to an uncompressed RAW image.
    -s | --safe             Safely stop and start a ZFS jail before the exporting process.
         --tgz              Export a jail using simple .tgz compressed archive instead.
         --txz              Export a jail using simple .txz compressed archive instead.
    -v | --verbose          Be more verbose during the ZFS send operation.
         --xz               Export a ZFS jail using XZ(.xz) compressed image.

  Note: If no export option specified, the container should be redirected to standard output.
