limits
======

rctl
----

Set resourse limits for targeted jail(s).

To add a limit, use ``bastille limits TARGET add OPTION VALUE``.

To clear the limits from the system, use ``bastille limits TARGET clear``.

To clear the limits, and remove the rctl.conf, so that limits will not be loaded
on a restart, use ``bastille limits TARGET reset``. This removes the ``rctl.conf`` file,
and removes any active limits from the system.

To remove a limit, use ``bastille limits TARGET remove OPTION``.

This file can be edited manually using ``bastille edit TARGET rctl.conf``.

Supported actions are ``add``, ``remove``, ``clear``, ``reset``, ``list``, ``show``, and
``stats``.

cpuset
------

Bastille supports limiting CPUs using ``cpuset``. To limit a jail to a specific CPU, use
``bastille limits TARGET cpu 2,3,4``` where the value (2,3,4) is a comma-separated list of CPUs on
your system. Bastille will validate the CPUs, and error if they are not available to be used.

To adjust the CPU limits, run ``bastille limits TARGET cpu 1,2,3`` again with a new set of CPU
values. This will overwrite the ``cpuset.conf`` file. This will restrict the targetted jail(s) to
the specified CPUs.

CPU limits are cleared when the jail is stopped, and loaded again on jail start, providing the CPU
values are present in ``cpuset.conf`` inside the jail directory.

Supported actions are ``add``, ``remove``, ``reset``, ``list`` and ``show``.

This file can be edited manually using ``bastille edit TARGET cpuset.conf``.

.. code-block:: shell

  ishmael ~ # bastille limits help
  Usage: bastille limits [option(s)] TARGET [add|remove|clear|reset|(list|show [active])|stats] OPTION [VALUE]
  
      Example: bastille limits TARGET add memoryuse 1G
      Example: bastille limits TARGET add cpu 0,1,2

      Options:

      -a | --auto           Auto mode. Start/stop jail(s) if required.
      -x | --debug          Enable debug mode. 