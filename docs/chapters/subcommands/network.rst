network
=======

Add or remove interfaces to existing jails.

You can only add an interface once to a jail, with two exceptions.

1. For classic jails, you can add an interface as many times as you want, but each time with a different IP. All this does is add the IP as another alias on that interface.

2. For VNET jails, if the `-v|--vlan` switch is given along with a numerical VLAN ID, Bastille will add the VLAN ID to the jail as a vnetX.X interface, depending on which interface is specified.

Bridges and VNET interfaces can be added to VNET jails, no matter if they were created with `-V` or `-B`.

.. code-block:: shell

  ishmael ~ # bastille network help
  Usage: bastille network [option(s)] TARGET [remove|add] INTERFACE [IP_ADDRESS]
    Options:

    -a | --auto                 Start/stop the jail(s) if required.
    -B | --bridge               Add a bridged VNET interface to an existing jail.
    -C | --classic              Add an interface to a classic (non-VNET) jail.
    -M | --static-mac           Generate a static MAC address for the interface.
    -n | --no-ip                Create interface without an IP (VLAN+VNET only).
    -V | --vnet                 Add a VNET interface to an existing jail.
    -v | --vlan VLANID          Add interface with specified VLAN ID (VNET only).
    -x | --debug                Enable debug mode.
