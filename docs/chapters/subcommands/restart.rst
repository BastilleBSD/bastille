restart
=======

Restart jail(s).

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
    -d | --delay VALUE          Time (seconds) to wait between starting jails(s).
    -v | --verbose              Print every action on jail start.
    -x | --debug                Enable debug mode.
