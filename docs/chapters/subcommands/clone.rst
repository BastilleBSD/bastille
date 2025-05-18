clone
=====

Clone/duplicate an existing jail to a new jail.

.. code-block:: shell

  ishmael ~ # bastille clone help
  Usage: bastille clone [option(s)] TARGET NEW_NAME IP

      Options:

      -a | --auto           Auto mode. Start/stop jail(s) if required. Cannot be used with [-l|--live].
      -l | --live           Clone a running jail (ZFS only). Cannot be used with [-a|--auto].
      -x | --debug          Enable debug mode.