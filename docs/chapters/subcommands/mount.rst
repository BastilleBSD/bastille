=====
mount
=====

To mount storage within the container use `bastille mount`.

.. code-block:: shell

  ishmael ~ # bastille mount azkaban /storage/foo /media/foo nullfs ro 0 0
  [azkaban]:

Syntax follows standard `/etc/fstab` format:

.. code-block:: shell

  Usage: bastille mount TARGET host_path container_path [filesystem_type options dump pass_number]
