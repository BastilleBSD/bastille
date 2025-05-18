sysrc
=====

The ``sysrc`` sub-command allows for safely editing system configuration files.
In jail terms, this allows us to toggle on/off services and options at startup.

.. code-block:: shell

  ishmael ~ # bastille sysrc nginx nginx_enable="YES"
  [nginx]:
  nginx_enable: NO -> YES

See ``man sysrc(8)`` for more info.

.. code-block:: shell

  ishmael ~ # bastille sysrc help
  Usage: bastille sysrc [option(s)] TARGET ARGS

      Options:

      -a | --auto           Auto mode. Start/stop jail(s) if required.
      -x | --debug          Enable debug mode.