VLAN Configuration
------------------

Jail VLAN Tagging
^^^^^^^^^^^^^^^^^

Bastille supports VLANs to some extent when creating jails. When creating a jail,
use the ``--vlan ID`` options to specify a VLAN ID for your jail. This will set
the proper variables inside the jails `rc.conf` to add the jail to the specified
VLAN. The jail will then take care of tagging the traffic. Do not use ``-v|--vlan``
if you have already configured the host interface to tag the traffic. See limitations
below.

When using this method, the interface being assigned must be a trunk interface.
This means that it passes all traffic, leaving any VLAN tags as they are.

Host VLAN Tagging
^^^^^^^^^^^^^^^^^

Another method is to configure a host interface to tag the traffic. This way, the
jail doesn't have to worry about it.

You can only use ``-B|--bridge`` with host VLAN interfaces, due to the limitation
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

Notice that the interfaces are bridge interfaces, and can be used with ``-B|--bridge``
without issue.

VLAN Limitations
^^^^^^^^^^^^^^^^

* You cannot use the ``-V|--vnet`` options with interfaces that have dots (.) in the
  name, which is the standard way of naming a VLAN interface. This is due to the
  limitations of the JIB script that Bastille uses to manage VNET jails.

* Do not attempt to configure both the host and the jail to tag VLAN traffic.
  If you use the host method, do not use ``-v|--vlan`` when creating the jail.
  Doing so will prevent the jail from having network access.

Tip: Don't forget to set you gateway and nameserver is applicable
using ``-g|--gateway`` and ``-n|--nameserver``.