start
=====

Start jail(s).

.. code-block:: shell

  ishmael ~ # bastille start folsom
  [folsom]:
  folsom: created

.. code-block:: shell

  ishmael ~ # bastille start help
  Usage: bastille start [option(s)] TARGET

      Options:

      -b | --boot                 Respect jail boot setting.
      -d | --delay VALUE          Time (seconds) to wait after starting each jail.
      -v | --verbose              Print every action on jail start.
      -x | --debug                Enable debug mode.