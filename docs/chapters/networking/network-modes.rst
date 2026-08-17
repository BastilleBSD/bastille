Jail Network Modes
------------------

Bastille tries to be flexible in the different network modes it supports. Below
is a breakdown of each network mode, what each one does, as well as some
suggestions as to where you might want to use each one.

NAT
^^^

* For jails that use an IP not reachable in your local
  network, Bastille will add the IP to the specified interface as an alias, and
  additionally, add it to the pf firewall table (if available) to allow the jail
  outbound access. If you do not specify an interface, Bastille will assume you
  have run the ``bastille setup`` command and will attempt to use ``bastille0``
  (which is created using the setup command) as its interface. If you have not
  run ``bastille setup`` and do not specify an interface, Bastille will error.

* This mode works best if you want your jail to be in its own private network.
  Bastille will dynamically add each jail IP to the firewall table to ensure
  network connectivity.

* This mode is similar to the Alias/Shared Interface mode, except that it is not
  limited to IP addresses within your local network.

Alias
^^^^^

* For jails that use an IP that is accessible
  within your local network, Bastille will add the IP to the
  specified interface as an alias.

* This mode is best used if you have one interface, and don't want the jail to
  have its own MAC address. The jail IP will simply be added to the specified
  interface as an additional IP, and will inherit the rest of the interface.

* Note that this mode does not function as the two `VNET` modes below, but still
  allows the jail to have an IP address inside your local network.

VNET
^^^^

* For VNET jails (``-V``) Bastille will create a bridge
  interface and attach your jail to it. It will be called ``em0bridge`` or
  whatever your interface is called. This will be used for the host/jail epairs.
  Bastille will create/destroy these epairs as the jail is started/stopped.

* This mode works best if you want your jail to be in your local network, acting
  as a physical device with its own MAC address and IP.

VNET - Manual Bridge
^^^^^^^^^^^^^^^^^^^^

* For bridged VNET jails (``-B``) you must manually create a
  bridge interface to attach your jail to. Bastille will then create and attach
  the host/jail epairs to this interface when the jail starts, and remove them\
  when it stops.

* This mode is identical to `VNET` above, with one exception. The interface it
  is attached to is a manually created bridge, as opposed to a regular interface
  that is used with `VNET` above.

Inherit
^^^^^^^

* For classic/standard jails that are set to ``inherit`` or
  ``ip_hostname``, bastille will simply set ``ip4`` to ``inherit`` inside the
  jail config. The jail will then function according the jail(8) documentation.

* This mode makes the jail inherit the entire network stack of the host.

IP Hostname
^^^^^^^^^^^

* For classic/standard jails that are set to ``ip_hostname``,
  bastille will simply set ``ip4`` to ``ip_hostname`` inside the jail config.
  The jail will then function according the jail(8) documentation.

* This is an advanced parameter. See the official FreeBSD jail(8) documentation
  for details.

You cannot use ``-V|--vnet`` with any interface that is already a member of
another bridge. For example, if you create a bridge, and assign ``vtnet0`` as a
member, you will not be able to use ``vtnet0`` with ``-V|--vnet``.