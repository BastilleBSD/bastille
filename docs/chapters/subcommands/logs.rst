logs
====

The ``bastillle logs`` subcommand will show either console logs, or oci container logs.

There is also the option to view live logs.

By default, only the tail end of the logs are shown. Use ``-f|--full`` to view the
entire file.

.. code-block:: shell


  ishmael ~ # bastille logs help
  Usage: bastille logs [option(s)] TARGET oci|console"

      Options:

      -f | --full     Show full logs.
      -l | --live     Show live logs.
