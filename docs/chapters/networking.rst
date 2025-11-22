Networking
==========

Bastille is very flexible with its networking options. Below are the supported
networking modes, how they work, and some tips on where you might want to use
each one.

Bastille also supports VLANs to some extent. See the VLAN section below.

Jail Network Modes
------------------

Bastille tries to be flexible in the different network modes it supports. Below
is a breakdown of each network mode, what each one does, as well as some
suggestions as to where you might want to use each one.

VNET
^^^^

* For VNET jails (``-V``) Bastille will create a bridge
  interface and attach your jail to it. It will be called ``em0bridge`` or
  whatever your interface is called. This will be used for the host/jail epairs.
  Bastille will create/destroy these epairs as the jail is started/stopped.

* This mode works best if you want your jail to be in your local network, acting
  as a physical device with its own MAC address and IP.

Bridged VNET
^^^^^^^^^^^^

* For bridged VNET jails (``-B``) you must manually create a
  bridge interface to attach your jail to. Bastille will then create and attach
  the host/jail epairs to this interface when the jail starts, and remove them\
  when it stops.

* This mode is identical to `VNET` above, with one exception. The interface it
  is attached to is a manually created bridge, as opposed to a regular interface
  that is used with `VNET` above.

Alias/Shared Interface
^^^^^^^^^^^^^^^^^^^^^^

* For classic/standard jails that use an IP that is accessible
  within your local subnet (alias mode) Bastille will add the IP to the
  specified interface as an alias.

* This mode is best used if you have one interface, and don't want the jail to
  have its own MAC address. The jail IP will simply be added to the specified
  interface as an additional IP, and will inherit the rest of the interface.

* Note that this mode does not function as the two `VNET` modes above, but still
  allows the jail to have an IP address inside your local network.

NAT/Loopback Interface
^^^^^^^^^^^^^^^^^^^^^^

* For classic/standard jails that use an IP not reachable in your local
  subnet, Bastille will add the IP to the specified interface as an alias, and
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

IP Address Options
------------------

Bastille includes a number of IP options.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE 192.168.1.50/24 vtnet0

The IP address specified above can be any of the following options.

* An IP in your local subnet should be chosen if you create your jail using
  ``-V`` or ``-B`` (VNET jail). It is also preferable to add the subnet mask
  (/24 or whaterver your subnet is) to the IP.

* DHCP, SYNCDHCP, or 0.0.0.0 will configure your jail to use DHCP to obtain an
  address from your router. This should only be used with ``-V`` and ``-B``.

* Any IP address inside the RFC1918 range if you are not using a VNET jail.
  Bastille will automatically add this IP to the firewall table to allow
  outbound access. It you want traffic to be forwarded into the jail, you can
  use the ``bastille rdr`` command.

* Any IP in your local subnet without the ``-V`` or ``-B`` options will add the
  IP as an alias to the selected interface, which will simply end up sharing the
  interface. If the IP is in your local subnet, you will not need the ``bastille
  rdr`` command. Traffic will pass in and out just as in a VNET jail.

* Setting the IP to ``inherit`` will make the jail inherit the entire host
  network stack.

* Setting the IP to ``ip_hostname`` will add all the IPs that the hostname
  resolves to. This is an advanced option and should only be used if you know
  what you are doing.

Note that jails support specifying an IP without the subnet (/24 or whatever
yours is) but we highly recommend setting it, especially on VNET jails. Not
doing so can cause issues in some rare cases.

Bastille also supports IPv6. Instead of an IPv4 address, you can specify an
IPv6 address when creating a jail to use IPv6. It is also possible to use both
by quoting an IPv4 and IPv6 address together as seen in the following example.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE "192.168.1.50/24 2001:19f0:6c01:114c:0:100/64" vtnet0

For the ``inherit`` and ``ip_hostname`` options, you can also specify
``-D|--dual`` to use both IPv4 and IPv6 inside the jail.

Networking Limitations
----------------------

VNET Jail Interface Names
^^^^^^^^^^^^^^^^^^^^^^^^^

* FreeBSD has certain limitations when it comes to interface names. One
  of these is that interface names cannot be longer than 15 characters.
  Because of this, Bastille uses a generic name for any epairs created
  whose corresponding jail name exceeds the maximum length. See below...

  ``e0a_jailname`` and ``e0b_jailname`` are the default epair interfaces for every
  jail. The ``e0a`` side is on the host, while the ``e0b`` is in the jail. Due
  to the above mentioned limitations, Bastille will name any epairs whose
  jail names exceed the maximum length, to ``e0b_bastilleX`` and ``e0b_bastilleX``
  with the ``X`` starting at ``1`` and incrementing by 1 for each new epair.
  So, ``mylongjailname`` will be ``e0a_bastille2`` and ``e0b_bastille2``.

Netgraph and Proxmox VE
^^^^^^^^^^^^^^^^^^^^^^^

* When running a FreeBSD VM on Proxmox VE, you might encounter crashes when using
  Netraph. This bug is being tracked at
  https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=238326

  One workaround is to add the following line to the ``jail.conf`` file of the affected
  jail(s).

.. code-block:: shell

  exec.prestop += "jng shutdown JAILNAME";

Network Scenarios
-----------------

SOHO (Small Office/Home Office)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This scenario works best when you have just one computer, or a home or small
office network that is separated from the rest of the internet by a router. So
you are free to use
`private IP addresses
<https://www.lifewire.com/what-is-a-private-ip-address-2625970>`_.

In this environment, we can create the container, give it a
unique private ip address within our local subnet, and attach
its ip address to our primary interface.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE 192.168.1.50 em0

You may have to change em0

When the ``alcatraz`` container is started it will add ``192.168.1.50`` as an IP
alias to the ``em0`` interface. It will then simply be another member of the
hosts network. Other networked systems (firewall permitting) should be able to
reach services at that address.

This method is the simplest. All you need to know is the name of your network
interface and a free IP on your local network.

We can also run ``bastille setup shared`` to configure our primary interface as
a default interface for Bastille to use. Once we have run the command and chosen
our interface, it will not be necessary to specify an interface in our create
command.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE 192.168.1.50

This will automatically use the interface we selected during the setup command.

Note that we cannot use the ``shared`` option together with the ``loopback``
option. Configuring one using the ``bastille setup`` command will disable the other.

Shared Interface on IPV6 network (vultr.com)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Some ISP's, such as `Vultr <https://vultr.com>`_, give you a single ipv4
address,
and a large block of ipv6 addresses. You can then assign a unique ipv6 address
to each Bastille Container.

On a virtual machine such as vultr.com the virtual interface may be ``vtnet0``.
So we issue the command:

.. code-block:: shell

 bastille create alcatraz 13.2-RELEASE 2001:19f0:6c01:114c::100 vtnet0

We could also write the ipv6 address as 2001:19f0:6c01:114c:0:100

The tricky part are the ipv6 addresses. IPV6 is a string of 8 4 digit
hexadecimal characters.  At vultr they said:

Your server was assigned the following six section subnet:

2001:19f0:6c01:114c::/64

The `vultr ipv6 subnet calculator
<https://www.vultr.com/resources/subnet-calculator-ipv6/?prefix_length=64&display=long&ipv6_address=2001%3Adb8%3Aacad%3Ae%3A%3A%2F64>`_
is helpful in making sense of that ipv6 address.

We could have also written that IPV6 address as 2001:19f0:6c01:114c:0:0

Where the /64 basicaly means that the first 64 bits of the address (4x4
character hexadecimal) values define the network, and the remaining characters,
we can assign as we want to the Bastille Container. In the actual bastille
create command given above, it was defined to be 100. But we also have to tell
the host operating system that we are now using this address. This is done on
freebsd with the following command

.. code-block:: shell

  ifconfig_vtnet0_alias0="inet6 2001:19f0:6c01:114c::100 prefixlen 64"

At that point your container can talk to the world, and the world can ping your
container.  Of course when you reboot the machine, that command will be
forgotten. To make it permanent, prefix the same command with ``sysrc``

Just remember you cannot ping out from the container. Instead, install and
use ``wget/curl/fetch`` to test the connectivity.


VNET (Virtual Network)
^^^^^^^^^^^^^^^^^^^^^^

(Added in 0.6.x) VNET is supported on FreeBSD 12+ only.

Virtual Network (VNET) creates a private network interface for a container. This
includes a unique hardware address. This is required for VPN, DHCP, and similar
containers.

To create a VNET based container use the ``-V|--vnet`` option, an IP/netmask and
external interface.

.. code-block:: shell

  bastille create -V azkaban 13.2-RELEASE 192.168.1.50/24 em0

Bastille will automagically create the bridge interface and connect /
disconnect containers as they are started and stopped. A new interface will be
created on the host matching the pattern ``interface0bridge``. In the example
here, ``em0bridge``.

The ``em0`` interface will be attached to the bridge along with the unique
container interfaces as they are started and stopped. These interface names
match the pattern ``eXb_bastilleX``. Internally to the containers these
interfaces are presented as ``vnet0``.

If you do not specify a subnet mask, you might have issues with jail to jail
networking, especially VLAN to VLAN. We recommend always adding a subnet to
VNET jail IPs when creating them to avoid these issues.

VNET also requires a custom devfs ruleset. Create the file as needed on the
host system:

.. code-block:: shell

  ## /etc/devfs.rules (NOT .conf)

  [bastille_vnet=13]
  add include $devfsrules_hide_all
  add include $devfsrules_unhide_basic
  add include $devfsrules_unhide_login
  add include $devfsrules_jail
  add include $devfsrules_jail_vnet
  add path 'bpf*' unhide

Lastly, you may want to consider these three ``sysctl`` values:

.. code-block:: shell

  net.link.bridge.pfil_bridge=0
  net.link.bridge.pfil_onlyip=0
  net.link.bridge.pfil_member=0

Below is the definition of what these three parameters are used for and mean:


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

Bridged VNET (Virtual Network)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To create a VNET based container and attach it to an external, already existing
bridge, use the ``-B`` option, an IP/netmask and external bridge.

.. code-block:: shell

  bastille create -B azkaban 13.2-RELEASE 192.168.1.50/24 bridge0

Bastille will automagically create the needed interface(s), attach it to the
specified bridge and connect/disconnect containers as they are started and stopped.
The bridge needs to be created/enabled before creating and starting the jail.

Below are the steps to creating a bridge for this purpose.

The first thing you have to do is to create a bridge
interface on your system.  This is done with the ifconfig command and will
create a bridged interface named bridge0:

.. code-block:: shell

   ifconfig bridge create

Then you need to add your system's network interface to the bridge and bring it
up (substitute your interface for em0).

.. code-block:: shell

   ifconfig bridge0 addm em0 up

Optionally you can rename the interface if you wish to make it obvious that it
is for bastille:

.. code-block:: shell

   ifconfig bridge0 name bastille0bridge

To create a bridged container you use the ``-B`` option, an IP or DHCP, and the
bridge interface.

.. code-block:: shell

   bastille create -B folsom 14.2-RELEASE DHCP bastille0bridge

All the epairs and networking other than the manually created bridge will be
created for you automagically. Now if you want this to persist after a reboot
then you need to add some lines to your ``/etc/rc.conf`` file.  Add the
following lines, again, obviously change em0 to whatever your network interface
on your system is.

.. code-block:: shell

   cloned_interfaces="bridge0"
   ifconfig_bridge0_name="bastille0bridge"
   ifconfig_bastille0bridge="addm vtnet0 up"

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

Regarding Routes
----------------

Bastille will attempt to auto-detect the default route from the host system and
assign it to the VNET container. This auto-detection may not always be accurate
for your needs for the particular container. In this case you'll need to add a
default route manually or define the preferred default route in the
``bastille.conf``.

.. code-block:: shell

  bastille sysrc TARGET defaultrouter=aa.bb.cc.dd
  bastille service TARGET routing restart

To define a default route / gateway for all VNET containers define the value in
``bastille.conf``:

.. code-block:: shell

  bastille_network_gateway=aa.bb.cc.dd

This config change will apply the defined gateway to any new containers.
Existing containers will need to be manually updated.

Public Network
--------------

In this section we describe how to network containers in a public network
such as a cloud hosting provider who only provides you with a single ip address.
(AWS, Digital Ocean, etc) (The exception is vultr.com, which does
provide you with lots of IPV6 addresses and does a great job supporting
FreeBSD!)

So if you only have a single IP address and if you want to create multiple
containers and assign them all unique IP addresses, you'll need to create a new
network.

Netgraph
--------

Bastille supports netgraph as an VNET management tool, thanks to the `jng` script.
To enable netgraph, run `bastille setup netgraph`. This will load and persist the
required kernel modules. Once netgraph is configured, any VNET jails
you create will be managed with netgraph.

Note that you should only enable netgraph on a new system. Bastille is set up to
use either `netgraph` or `if_bridge` as the VNET management, and uses `if_bridge`
as the default, as it always has. The `netgraph` option is new, and should only
be used with new systems.

This value is set with the `bastille_network_vnet_type` option inside the config
file.

loopback (bastille0)
^^^^^^^^^^^^^^^^^^^^

What we recommend is creating a cloned loopback interface (``bastille0``) and
assigning all the containers private (rfc1918) addresses on that interface. The
setup I develop on and use Bastille day-to-day uses the ``10.0.0.0/8`` address
range. I have the ability to use whatever address I want within that range
because I've created my own private network. The host system then acts as the
firewall, permitting and denying traffic as needed.

I find this setup the most flexible across all types of networks. It can be
used in public and private networks just the same and it allows me to keep
containers off the network until I allow access.

Having said all that here are instructions I used to configure the network with
a private loopback interface and system firewall. The system firewall NATs
traffic out of containers and can selectively redirect traffic into containers
based on connection ports (ie; 80, 443, etc.)

To set up the loopback address automatically, we can simply run ``bastille setup``.
This will configure the storage, pf firewall, and loopback addresses for us.
To set these up individually, we can run ``bastille setup storage``,
``bastille setup firewall``, and ``bastille setup loopback`` respectively.

Alternatively, you can do it all manually, as shown below.

First, create the loopback interface:

.. code-block:: shell

  ishmael ~ # sysrc cloned_interfaces+=lo1
  ishmael ~ # sysrc ifconfig_lo1_name="bastille0"
  ishmael ~ # service netif cloneup

Second, enable the firewall:

.. code-block:: shell

  ishmael ~ # sysrc pf_enable="YES"

Create the firewall rules:

/etc/pf.conf
^^^^^^^^^^^^

.. code-block:: shell

  ext_if="vtnet0"

  set block-policy return
  scrub in on $ext_if all fragment reassemble
  set skip on lo

  table <jails> persist
  nat on $ext_if from <jails> to any -> ($ext_if:0)
  rdr-anchor "rdr/*"

  block in all
  pass out quick keep state
  antispoof for $ext_if inet
  pass in proto tcp from any to any port ssh flags S/SA modulate state

- Make sure to change the ``ext_if`` variable to match your host system
interface.
- Make sure to include the last line (``port ssh``) or you'll end up locked out.

Note: if you have an existing firewall, the key lines for in/out traffic
to containers are:

.. code-block:: shell

  nat on $ext_if from <jails> to any -> ($ext_if:0)

The ``nat`` routes traffic from the loopback interface to the external
interface for outbound access.

.. code-block:: shell

  rdr-anchor "rdr/*"

The ``rdr-anchor "rdr/*"`` enables dynamic rdr rules to be setup using the
``bastille rdr`` command at runtime - eg.

.. code-block:: shell

  bastille rdr TARGET tcp 2001 22 # Redirects tcp port 2001 on host to 22 on jail
  bastille rdr TARGET udp 2053 53 # Same for udp
  bastille rdr TARGET list        # List dynamic rdr rules
  bastille rdr TARGET clear       # Clear dynamic rdr rules

Note that if you are redirecting ports where the host is also listening (eg.
ssh) you should make sure that the host service is not listening on the cloned
interface - eg. for ssh set sshd_flags in rc.conf

.. code-block:: shell

  sshd_flags="-o ListenAddress=<host-address>"

Finally, start up the firewall:

.. code-block:: shell

  ishmael ~ # service pf restart

At this point you'll likely be disconnected from the host. Reconnect the
ssh session and continue.

This step only needs to be done once in order to prepare the host.

Note that we cannot use the ``loopback`` option together with the ``shared``
option. Configuring one using the ``bastille setup`` command will disable the other.

local_unbound
-------------

If you are running "local_unbound" on your server, you will probably have issues
with DNS resolution.

To resolve this, add the following configuration to local_unbound:

.. code-block:: shell

  server:
  interface: 0.0.0.0
  access-control: 192.168.0.0/16 allow
  access-control: 10.17.90.0/24 allow

Also, change the nameserver to the servers IP instead of 127.0.0.1 inside
/etc/rc.conf

Adjust the above "access-control" strings to fit your network.
