ZFS Support
====================
.. image:: chapters/bastillebsd.png
  :width: 400
  :alt: Alternative text

Bastille 0.4 added initial support for ZFS. ``bastille bootstrap`` and ``bastille create`` will generate ZFS volumes based on settings found in the ``bastille.conf``. This section outlines how to enable and configure Bastille for ZFS.

Two values are required for Bastille to use ZFS. The default values in the ``bastille.conf`` are empty. Populate these two to enable ZFS.

.. code-block:: shell

  ## ZFS options
  bastille_zfs_enable=""                                  ## default: ""
  bastille_zfs_zpool=""                                   ## default: ""
  bastille_zfs_prefix="bastille"                          ## default: "${bastille_zfs_zpool}/bastille"
  bastille_prefix="/bastille"                             ## default: "/usr/local/bastille". ${bastille_zfs_prefix} gets mounted here
  bastille_zfs_options="-o compress=lz4 -o atime=off"     ## default: "-o compress=lz4 -o atime=off"

Example

.. code-block:: shell

  ishmael ~ # sysrc -f /usr/local/etc/bastille/bastille.conf bastille_zfs_enable=YES
  ishmael ~ # sysrc -f /usr/local/etc/bastille/bastille.conf bastille_zfs_zpool=ZPOOL_NAME

Replace ``ZPOOL_NAME`` with the zpool you want Bastille to use. Tip: ``zpool list`` and ``zpool status`` will help. If you get 'no pools available' you are likely not using ZFS and can safely ignore these settings.
