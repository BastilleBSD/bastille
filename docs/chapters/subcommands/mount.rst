=====
mount
=====

To mount storage within the container use `bastille mount`.

.. code-block:: shell

  ishmael ~ # bastille mount azkaban /storage/foo media/foo nullfs ro 0 0
  [azkaban]:
  Added: /media/foo /usr/local/bastille/jails/azkaban/root/media/foo
  ishmael ~ # bastille mount azkaban /storage/bar /media/bar nullfs ro 0 0
  [azkaban]:
  Added: /media/bar /usr/local/bastille/jails/azkaban/root/media/bar

Notice the JAIL_PATH format can be /media/foo or simply media/bar. The leading slash / is optional. The HOST_PATH howerver, must be the full path including the leading slash /.

It is also possible to mount individual files into a jail as seen below.
Bastille will not mount if a file is already present at the specified mount point.
If you do not specify a file name, bastille will mount the file underneath the specified directory as seen in the second example below.

.. code-block:: shell

  ishmael ~ # bastille mount azkaban /etc/rc.conf /mnt/etc/rc.conf nullfs ro 0 0
  [azkaban]:
  Added: /etc/rc.conf /usr/local/bastille/jails/azkaban/root/mnt/etc/rc.conf
  ishmael ~ # bastille mount azkaban /etc/rc.conf /media/bar nullfs ro 0 0
  [azkaban]:
  Added: /etc/rc.conf usr/local/bastille/jails/azkaban/root/media/bar/rc.conf

It is also possible (but not recommended) to have spaces in the directories that are mounted.
It is necessary to escape each space with a backslash \ and enclose the mount point in quotes "" as seen below.
It is possible to do the same for the jail path, but again, not recommemded.

.. code-block:: shell

  ishmael ~ # bastille mount azkaban "/storage/my\ directory\ with\ spaces" /media/foo nullfs ro 0 0
  [azkaban]:
  Added: /storage/my\040directory\040with\040spaces /usr/local/bastille/jails/azkaban/root/media/foo

Syntax follows standard `/etc/fstab` format:

.. code-block:: shell

  Usage: bastille mount TARGET HOST_PATH JAIL_PATH [filesystem_type options dump pass_number]
