upgrade
=======

The ``upgrade`` command targets a thick or thin jail. Thin jails will be updated by changing the
release mount point that it is based on. Thick jails will be upgraded normally.

.. code-block:: shell

  ishmael ~ # bastille upgrade help
  Usage: bastille upgrade [option(s)] TARGET [NEWRELEASE|install]
    Options:

    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -f | --force            Force upgrade a jail.
    -x | --debug            Enable debug mode.
