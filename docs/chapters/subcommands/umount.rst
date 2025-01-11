======
umount
======

To unmount storage from a container use `bastille umount`.

.. code-block:: shell

  ishmael ~ # bastille umount azkaban /media/foo
  [azkaban]:
  Unmounted: /usr/local/bastille/jails/jail4/root/media/foo
  ishmael ~ # bastille umount azkaban /mnt/etc/rc.conf
  [azkaban]:
  Unmounted: /usr/local/bastille/jails/jail4/root/mnt/etc/rc.conf

Syntax requires only the jail path to unmount.

.. code-block:: shell

  Usage: bastille umount TARGET JAIL_PATH

If the directory you are unmounting has spaces, make sure to escape them with a backslash \, and enclose the mount point in quotes "".

.. code-block:: shell

  ishmael ~ # bastille umount azkaban "/media/foo\ with\ spaces"
  [azkaban]:
  Unmounted: /usr/local/bastille/jails/jail4/root/media/foo with spaces
