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
  Added: /media/bar /usr/local/bastille/jails/azkaban/root/media/foo

Notice the format can be /media/foo or simply media/bar. The leading slash is optional.

Syntax follows standard `/etc/fstab` format:

.. code-block:: shell

  Usage: bastille mount TARGET HOST_PATH JAIL_PATH [filesystem_type options dump pass_number]
