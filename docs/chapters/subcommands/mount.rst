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

Syntax follows standard `/etc/fstab` format:

.. code-block:: shell

  Usage: bastille mount TARGET HOST_PATH JAIL_PATH [filesystem_type options dump pass_number]
