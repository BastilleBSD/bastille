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
    -d | --delay VALUE          Time to wait between stopping each jail.
    -v | --verbose              Print every action on jail stop.
    -x | --debug                Enable debug mode.
