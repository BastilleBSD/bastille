migrate
=======

The ``migrate`` sub-command allows migrating the targeted jail(s) to
another remote system. See the chapter on Migration.

This sub-command supports multiple targets.

Syntax for the remote system is ``user@host``. You can also specify a non-default
port by supplying it as in ``user@host:port``.

.. code-block:: shell

  ishmael ~ # bastille migrate help
  Usage: bastille migrate [option(s)] TARGET USER@HOST[:PORT]

      Examples:

      bastille migrate attica migrate@192.168.10.100
      bastille migrate attica migrate@192.168.1.10:20022
      bastille migrate --keyfile id_rsa attica migrate@192.168.1.10

      Options:

      -a | --auto         Auto mode. Start/stop jail(s) if required.
      -b | --backup       Retain archives on remote system.
      -d | --destroy      Destroy local jail after migration.
         | --doas         Use 'doas' instead of 'sudo'.
      -k | --keyfile      Specify an alternative private keyfile name. Must be in '~/.ssh'
      -l | --live         Migrate a running jail (ZFS only).
      -p | --password     Use password based authentication.
      -x | --debug        Enable debug mode.