migrate
=======

The ``migrate`` sub-command allows migrating the  targeted jail(s) to
another remote system. See the chapter on Migration.

This sub-command supports multiple targets.

.. code-block:: shell

  ishmael ~ # bastille migrate help
  Usage: bastille migrate [option(s)] TARGET USER HOST

    Options:

    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -d | --destroy          Destroy local jail after migration.
    -x | --debug            Enable debug mode.
