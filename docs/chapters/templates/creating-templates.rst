Creating Templates
==================

Templates should be created and placed inside the templates directory in the
``project/template`` format. Alternatively you can run the ``bastille template``
command from a relative path, making sure it is still in the above ``project/template``
format.

Place any uppercase template hook into ``project/template/Bastillefile`` in any
order to automate jail setup as needed.

Any files included in the ``project/template`` directory can be copied into the jail
using the ``CP`` hook. For example, if I have ``project/template/usr/local/etc/custom.conf``
I can use the following template to copy the entire contents of ``usr`` into my jail.
Bastille will not overwrite ``/usr`` inside the jail. It only copies the files in.

.. code-block:: shell

  CP usr /

See `Bastille Templates`_ for examples to get started on writing your own templates.

Using Ports in Templates
------------------------

Sometimes when creating a template, we need special options for a package, or
a newer version than pkg offers. The solution for such
cases, or a case like ``minecraft-server`` which has NO compiled option, is to use
ports. A working example of this is the ``minecraft-server`` template in the
template repo.  The main lines needed to use this is first to mount the ports
directory, then compile the port.  Below is an example of the ``minecraft-server``
template where this was used.

.. code-block:: shell

  ARG MINECRAFT_MEMX="1024M"
  ARG MINECRAFT_MEMS="1024M"
  ARG MINECRAFT_ARGS=""
  CONFIG set enforce_statfs=1;
  CONFIG set allow.mount.fdescfs;
  CONFIG set allow.mount.procfs;
  RESTART
  PKG dialog4ports tmux openjdk17
  MOUNT /usr/ports usr/ports nullfs ro 0 0
  CP etc /
  CP var /
  CMD make -C /usr/ports/games/minecraft-server install clean
  CP usr /
  SYSRC minecraft_enable=YES
  SYSRC minecraft_memx=${MINECRAFT_MEMX}
  SYSRC minecraft_mems=${MINECRAFT_MEMS}
  SYSRC minecraft_args=${MINECRAFT_ARGS}
  SERVICE minecraft restart
  RDR tcp 25565 25565

The ``MOUNT`` line mounts the ports directory, then the ``CMD`` make line makes the
port. This can be modified to use any port in the ports tree.