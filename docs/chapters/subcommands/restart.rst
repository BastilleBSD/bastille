restart
=======

Restart jail(s).

Bastille will attempt to stop, then start the targetted jail(s). If a jail is not running, Bastille
will still start it. To avoid this, run the restart command with ``-i|--ignore`` to skip any
stopped jail(s).

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

      -b | --boot            Respect jail boot setting.
      -d | --delay VALUE     Time (seconds) to wait after starting each jail.
      -i | --ignore          Ignore stopped jails (do not start if stopped).
      -v | --verbose         Print every action on jail restart.
      -x | --debug           Enable debug mode.