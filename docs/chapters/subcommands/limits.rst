limits
======

Set resourse limits for targeted jail(s).

To clear the limits from the system, use `bastille limits TARGET clear'

To clear the limits, and remove the rctl.conf, use `bastille limits TARGET reset`

.. code-block:: shell

  ishmael ~ # bastille limits help

  Usage: bastille limits [option(s)] TARGET [OPTION VALUE|clear|reset]"
  Example: bastille limits TARGET memoryuse 1G"
  
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode. 
