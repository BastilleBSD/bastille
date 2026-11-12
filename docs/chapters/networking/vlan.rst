VLAN Configuration
==================

Overview
--------

Bastille supports managing VLANs through the ``vlan`` subcommand. There are
essentially 3 different VLAN modes. There is the standard legacy mode, as well
as a new ``tagged`` and ``untagged`` mode (requires FreeBSD 15+).

VLANs can be added or removed from a jail at any time, providing the interface
that is chosen is already assigned to the jail.
See also: :doc:`/chapters/subcommands/network` for more details on adding or
removing interfaces from jails.

Legacy Mode - Trunk
-------------------

This is the default mode, and is used when specifying ``-v|--vlan`` while creating
a jail, or when not specifying ``-t|--tagged`` or ``-u|--untagged`` while using
the ``vlan`` subcommand.

When using this mode, the interface being assigned must be a trunk interface.
This means that it passes all traffic, leaving any VLAN tags as they are.

This requires configuring your host interface to be attached to a VLAN interface. See
the FreeBSD documentation for details, but the interface stack is basically
going to be: HOST > VLAN > BRIDGE

Legacy Mode - Host Tagging
--------------------------

Another method is to configure a host interface to tag the traffic. This way, the
jail doesn't have to worry about it.

You can only use a bridge interface with this method, due to the limitations
mentioned below. With this method we create the bridge interfaces in ``rc.conf``
and configure them to tag the traffic by VLAD ID.

Below is an ``rc.conf`` snippet that was provided by a user who has such a
configuration.

.. code-block:: shell

  # rename ethernet interfaces (optional)
  ifconfig_igb1_name="eth1"
  ifconfig_eth1_descr="vm/jail ethernet interface"

  # setup vlans
  vlans_eth1="10 20 30"

  # setup bridges
  cloned_interfaces="bridge10 bridge20 bridge30"
  ifconfig_bridge10_name="eth1.10bridge"
  ifconfig_bridge20_name="eth1.20bridge"
  ifconfig_bridge30_name="eth1.30bridge"
  ifconfig_eth1_10bridge="addm eth1.10 up"
  ifconfig_eth1_20bridge="addm eth1.20 up"
  ifconfig_eth1_30bridge="addm eth1.30 up"

  # bring interfaces up
  ifconfig_eth1="up"
  ifconfig_eth1_10="up"
  ifconfig_eth1_20="up"
  ifconfig_eth1_30="up"

VLAN Filter - Untagged
----------------------

FreeBSD 15 introduces a ``vlanfilter`` flag that can be enabled for a
bridge interface. This basically turns the bridge into a VLAN-aware switch
that can handle multiple VLANs without issue.

Bastille supports this for hosts running FreeBSD 15 and above.

Only one untagged VLAN can be added to a given jail interface at any time. This is due
to the fact that the bridge will essentially send the network packets to the jail
without a VLAN tag. If, for example, you have VLAN 50 assigned as untagged, the jail will see it as
the native network.

Adding an untagged VLAN is as simple as running ``bastille vlan --auto --untagged TARGET add 50 bridge0 10.50.50.50``.
This will add VLAN 50, connected to bridge0 and using 10.50.50.50 as the IP.

VLAN Filter - Tagged
--------------------

In addition to the untagged VLANs, Bastille also supports adding tagged VLANs. Keep in
mind that this still requires FreeBSD 15 and above, plus the ``vlanfilter`` flag for
the bridge interface you want to use.

Unlike the untagged VLAN option, a jail can have as many tagged VLANs as needed. Also, because
they are tagged, Bastille will create an interface inside the jail that corresponds to the
VLAN tag assinged to it.

Adding a tagged VLAN is as simple as running ``bastille vlan --auto --tagged TARGET add 60 bridge0 10.60.60.60``.
This will add VLAN 60, connected to bridge0 and using 10.60.60.60 as the IP.

.. attention::

   The ``-t|--tagged`` and ``-u|--untagged`` (vlanfilter) options are experimental.

VLAN Limitations
----------------

* When creating a jail, you cannot use the ``-V|--vnet`` options with
  interfaces that have dots (.) in the
  name, which is the standard way of naming a VLAN interface. This is due to the
  limitations of the JIB script that Bastille uses to manage VNET jails.

* Do not attempt to configure both the host and the jail to tag VLAN traffic.
  If you use the host method, do not use ``-v|--vlan`` when creating the jail.
  Doing so will prevent the jail from having network access.

Tip: When creating a jail, don't forget to set your gateway and nameserver is applicable
using ``-g|--gateway`` and ``-n|--nameserver``.