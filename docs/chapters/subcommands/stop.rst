stop
====

Stop jail(s).

.. code-block:: shell

  ishmael ~ # bastille stop folsom
  [folsom]:
  folsom: removed

.. code-block:: shell

  ishmael ~ # bastille stop help
  Usage: bastille stop [option(s)] TARGET
    Options:

    -b | --boot                 Respect jail boot setting.
    -d | --delay VALUE          Time (seconds) to wait after stopping jail(s).
    -v | --verbose              Print every action on jail stop.
    -x | --debug                Enable debug mode.
