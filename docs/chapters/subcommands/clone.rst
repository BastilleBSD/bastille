clone
=====

To clone a container and make a duplicate, use the ``bastille clone``
sub-command..

.. code-block:: shell

  ishmael ~ # bastille clone azkaban rikers ip
  [azkaban]:

Syntax requires a name for the new container and an IP address assignment.

.. code-block:: shell

  ishmael ~ # bastille clone help
  Usage: bastille clone [option(s)] TARGET NEW_NAME IP_ADDRESS
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required. Cannot be used with [-l|--live].
    -l | --live           Clone a running jail. ZFS only. Jail must be running. Cannot be used with [-a|--auto].
    -x | --debug          Enable debug mode.
