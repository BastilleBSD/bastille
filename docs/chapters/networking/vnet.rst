VNET Configuration
==================

Bastille version 0.6.0 and above supports VNET jails. VNET jails are jails with
a completely separate network stack from the host, including a unique MAC address
and IP address. This is required for VPN, DHCP, and similar types of networking.

Setup
-----

To get started with VNET, run ``bastille setup vnet``. This will install the ``jib``
and ``jng`` scripts included with FreeBSD to manage VNET interfaces. Additionally, it
will create a ``devfs`` ruleset that Bastille will use for VNET jails:

.. code-block:: shell

  [bastille_vnet=13]
  add include \$devfsrules_hide_all
  add include \$devfsrules_unhide_basic
  add include \$devfsrules_unhide_login
  add include \$devfsrules_jail
  add include \$devfsrules_jail_vnet
  add path 'bpf*' unhide

Once that is complete, use the ``-V|--vnet`` or ``-B|--bridge`` option to create your jail.

If you do not want to run ``bastille setup vnet``, you can configure your host manually.

First, run the following command to install the ``jib`` script:

.. code-block:: shell

  install -m 0544 /usr/share/examples/jails/jib /usr/local/bin/jib

Next, add the following to ``/etc/devfs.rules``:

.. code-block:: shell

  [bastille_vnet=13]
  add include \$devfsrules_hide_all
  add include \$devfsrules_unhide_basic
  add include \$devfsrules_unhide_login
  add include \$devfsrules_jail
  add include \$devfsrules_jail_vnet
  add path 'bpf*' unhide

Lastly, you may want to consider these three ``sysctl`` values:

.. code-block:: shell

  net.link.bridge.pfil_bridge=0
  net.link.bridge.pfil_onlyip=0
  net.link.bridge.pfil_member=0

Below is the definition of what these three parameters are used for and mean:

.. code-block:: shell

       net.link.bridge.pfil_onlyip  Controls  the  handling  of	non-IP packets
				    which are not passed to pfil(9).  Set to 1
				    to only allow IP packets to	pass  (subject
				    to	firewall  rules), set to 0 to uncondi-
				    tionally pass all non-IP Ethernet frames.

       net.link.bridge.pfil_member  Set	to 1 to	enable filtering on the	incom-
				    ing	and outgoing member interfaces,	set to
				    0 to disable it.

       net.link.bridge.pfil_bridge  Set	to 1 to	enable filtering on the	bridge
				    interface, set to 0	to disable it.

Bastille can also configure a bridge for us to use. Simply run ``bastille setup bridge``.
This will do all of the above steps, and additionally create and persist a bridge
for us. The bridge name is named after the pattern, ``interfacebridge`` similar to
what the ``-V|--vnet`` option does for us.

If you do not want to run ``bastille setup bridge``, you can configure the bridge
manually.

First, we must create the bridge interface:

.. code-block:: shell

   ifconfig bridge create

Then we need to add our interface as a member of our new bridge
(substitute your interface for em0):

.. code-block:: shell

   ifconfig bridge0 addm vtnet0 up

Next we want to rename our bridge (optional):

.. code-block:: shell

   ifconfig bridge0 name bastille0bridge

To persist our bridge on a host reboot, add the following to ``/etc/rc.conf``:

.. code-block:: shell

   cloned_interfaces="bridge0"
   ifconfig_bridge0_name="bastille0bridge"
   ifconfig_bastille0bridge="addm vtnet0 up"

VNET - Physical Interface
-------------------------

To create a VNET based jail using the ``-V|--vnet`` option, you should include an
IP/netmask, and make sure the ``INTERFACE`` is a physical interface connected
to your network.

.. code-block:: shell

  bastille create -V folsom 15.1-RELEASE DHCP vtnet0

In this example, ``vtnet0`` is the interface connected to our network. If you
choose ``DHCP`` as we did, the jail will attempt to obtain an IP address from
your router. You can also specify an IP address instead of ``DHCP``. Bastille
uses the ``jib`` or ``jng`` (for netgraph) commands to create the necessary
epair/netgraph interfaces on jail start, and remove them on jail stop. See the
following example:

.. code-block:: shell

  root@dev1:~ # bastille create -V folsom 15.1-RELEASE 192.168.1.10/24 vtnet0
  ...

  root@dev1:~ # ifconfig

  ...
  vtnet0bridge: flags=1008843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST,LOWER_UP> metric 0 mtu 1500
          options=10<VLAN_HWTAGGING>
          ether 58:9c:fc:10:3f:e0
          id 00:00:00:00:00:00 priority 32768 hellotime 2 fwddelay 15
          maxage 20 holdcnt 6 proto rstp maxaddr 2000 timeout 1200
          root id 00:00:00:00:00:00 priority 32768 ifcost 0 port 0
          bridge flags=0<>
          member: e0a_folsom flags=143<LEARNING,DISCOVER,AUTOEDGE,AUTOPTP>
                  port 4 priority 128 path cost 2000 vlan protocol 802.1q
          member: vtnet0 flags=143<LEARNING,DISCOVER,AUTOEDGE,AUTOPTP>
                  port 1 priority 128 path cost 2000 vlan protocol 802.1q
          groups: bridge
          nd6 options=9<PERFORMNUD,IFDISABLED>
  e0a_folsom: flags=1008943<UP,BROADCAST,RUNNING,PROMISC,SIMPLEX,MULTICAST,LOWER_UP> metric 0 mtu 1500
          description: vnet0 host interface for Bastille jail folsom
          options=200009<RXCSUM,VLAN_MTU,RXCSUM_IPV6>
          ether 02:40:d5:2e:9b:d2
          hwaddr 58:9c:fc:10:8f:ba
          groups: epair
          media: Ethernet 10Gbase-T (10Gbase-T <full-duplex>)
          status: active
          nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>

  root@dev1:~ # bastille cmd folsom ifconfig

  lo0: flags=1008049<UP,LOOPBACK,RUNNING,MULTICAST,LOWER_UP> metric 0 mtu 16384
          options=680003<RXCSUM,TXCSUM,LINKSTATE,RXCSUM_IPV6,TXCSUM_IPV6>
          inet 127.0.0.1 netmask 0xff000000
          inet6 ::1 prefixlen 128
          inet6 fe80::1%lo0 prefixlen 64 scopeid 0x6
          groups: lo
          nd6 options=21<PERFORMNUD,AUTO_LINKLOCAL>
  vnet0: flags=1008843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST,LOWER_UP> metric 0 mtu 1500
          description: jail interface for vtnet0
          options=200009<RXCSUM,VLAN_MTU,RXCSUM_IPV6>
          ether 0e:40:d5:2e:9b:d2
          hwaddr 58:9c:fc:10:3c:c0
          inet 192.168.1.10 netmask 0xffffff00 broadcast 192.168.1.255
          groups: epair
          media: Ethernet 10Gbase-T (10Gbase-T <full-duplex>)
          status: active
          nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>


Bastille will automatically build a bridge for our jails matching the
pattern, ``interfacebridge``, so in our case ``vtnet0bridge`` and attach our
jail epair to it when we start the jail. When the jail is stopped, the epairs will be removed.

Because we used ``-V|--vnet``, Bastille created ``vtnet0bridge`` for us, and
epair ``e0a_folsom`` as well as ``e0b_folsom``. The ``a`` side goes on the host, while
the ``b`` side is inside the jail. Bastille also renames the ``b`` side to ``vnet0`` inside
the jail. Additionally, Bastille gives descriptions to these epairs to easily tell
which jail they are assigned to.

VNET - Manual Bridge Interface
------------------------------

Bastille also includes support for running jails attached to an already existing
bridge. The only difference between ``-V|--vnet`` and ``-B|--bridge`` is that
the ``-B|--bridge`` option must be used with an existing bridge interface as
the ``INTERFACE`` arg, while ``-V|--vnet`` must be used with a physical interface.

To create a VNET based jail and attach it to an already existing
bridge, use the ``-B|--bridge`` option, making sure that ``INTERFACE`` is
a bridge that already exists on our host.

The bridge used in the following example has already been configured on the host, and
has outbound access.

.. code-block:: shell

  bastille create -B azkaban 15.1-RELEASE 192.168.1.10/24 bridge0

In this example, ``bridge0`` is a bridge that we have previously created, so
Bastille will skip the step of creating the bridge, and just add/remove our
epair on jail start/stop:

.. code-block:: shell

  root@dev1:~ # ifconfig

  bridge0: flags=1008843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST,LOWER_UP> metric 0 mtu 1500
          options=10<VLAN_HWTAGGING>
          ether 58:9c:fc:10:3f:e0
          id 00:00:00:00:00:00 priority 32768 hellotime 2 fwddelay 15
          maxage 20 holdcnt 6 proto rstp maxaddr 2000 timeout 1200
          root id 00:00:00:00:00:00 priority 32768 ifcost 0 port 0
          bridge flags=0<>
          member: e0a_azkaban flags=143<LEARNING,DISCOVER,AUTOEDGE,AUTOPTP>
                  port 7 priority 128 path cost 2000 vlan protocol 802.1q
          member: vtnet0 flags=143<LEARNING,DISCOVER,AUTOEDGE,AUTOPTP>
                  port 1 priority 128 path cost 2000 vlan protocol 802.1q
          groups: bridge
          nd6 options=9<PERFORMNUD,IFDISABLED>
  e0a_azkaban: flags=1008943<UP,BROADCAST,RUNNING,PROMISC,SIMPLEX,MULTICAST,LOWER_UP> metric 0 mtu 1500
          description: vnet0 host interface for Bastille jail azkaban
          options=200009<RXCSUM,VLAN_MTU,RXCSUM_IPV6>
          ether 58:9c:fc:10:df:3a
          groups: epair
          media: Ethernet 10Gbase-T (10Gbase-T <full-duplex>)
          status: active
          nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>

  root@dev1:~ # bastille cmd azkaban ifconfig

  lo0: flags=1008049<UP,LOOPBACK,RUNNING,MULTICAST,LOWER_UP> metric 0 mtu 16384
          options=680003<RXCSUM,TXCSUM,LINKSTATE,RXCSUM_IPV6,TXCSUM_IPV6>
          inet 127.0.0.1 netmask 0xff000000
          inet6 ::1 prefixlen 128
          inet6 fe80::1%lo0 prefixlen 64 scopeid 0x9
          groups: lo
          nd6 options=21<PERFORMNUD,AUTO_LINKLOCAL>
  vnet0: flags=1008843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST,LOWER_UP> metric 0 mtu 1500
          description: jail interface for vtnet0bridge
          options=200009<RXCSUM,VLAN_MTU,RXCSUM_IPV6>
          ether 58:9c:fc:10:6d:c5
          inet 192.168.1.10 netmask 0xffffff00 broadcast 192.168.1.255
          groups: epair
          media: Ethernet 10Gbase-T (10Gbase-T <full-duplex>)
          status: active
          nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>

Note there is no difference to the structure of ``-V|--vnet`` or ``-B|--bridge`` jails. The
only difference is that ``-V|--vnet`` is used with a physical interface, while ``-B|--bridge`` is
used with an existing bridge interface.

If you do not specify a subnet mask, it defaults to ``/24``. This is due to some issues
with jail-to-jail networking, especially across VLANs.

Bastille includes some configuration values that will allow you to leave out the interface when
creating your jails.

.. code-block:: shell

  bastille_network_vnet="vtnet0"
  bastille_network_bridge="bridge0"

If you have supplied these values in ``/usr/local/etc/bastille/bastille.conf``, Bastille will
automatically use them if you do not specify an interface during jail creation. For
example, the following create command will automatically use ``bridge0`` if the value has been
added to the config file:

.. code-block:: shell

  bastille create -B folsom 15.1-RELEASE DHCP

Obviously, if you use ``-V|--vnet``, then ``vtnet0`` will be used from the above example.