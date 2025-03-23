limits
======

Set resourse limits for targeted jail(s).

To add a limit, use `bastille limits TARGET add OPTION VALUE`

To clear the limits from the system, use `bastille limits TARGET clear`

To clear the limits, and remove the rctl.conf, use `bastille limits TARGET reset`

To remove a limit, use `bastille limits TARGET remove OPTION`

.. code-block:: shell

  ishmael ~ # bastille limits help

  Usage: bastille limits [option(s)] TARGET [add OPTION VALUE|remove OPTION|clear|reset|[list|show] (active)|stats]
  Example: bastille limits TARGET memoryuse 1G"
  
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode. 
