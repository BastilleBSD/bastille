restart
=======

Restart jail(s).

Bastille will only restart targeted jail(s) if they are running. Jails that
are stopped will not be started.

.. code-block:: shell

  ishmael ~ # bastille restart folsom
  [folsom]:
  folsom: removed
  [folsom]:
  folsom: created

.. code-block:: shell

  ishmael ~ # bastille restart help
  Usage: bastille start [option(s)] TARGET

      Options:

      -b | --boot                 Respect jail boot setting.
      -d | --delay VALUE          Time (seconds) to wait after starting each jail.
      -v | --verbose              Print every action on jail restart.
      -x | --debug                Enable debug mode.