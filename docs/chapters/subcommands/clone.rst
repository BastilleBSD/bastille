clone
=====

Clone/duplicate an existing jail to a new jail.

Limitations
-----------

* When cloning a vnet jail with multiple interfaces,
  the default interface will be assigned the IP given
  in the command. The rest of the interfaces will have
  their network info set to ``ifconfig_inet=""``. This
  is to avoid conflicts between the old and new jails.

.. code-block:: shell

  ishmael ~ # bastille clone help
  Usage: bastille clone [option(s)] TARGET NEW_NAME IP

      Options:

      -a | --auto           Auto mode. Start/stop jail(s) if required. Cannot be used with [-l|--live].
      -l | --live           Clone a running jail (ZFS only). Cannot be used with [-a|--auto].
      -x | --debug          Enable debug mode.