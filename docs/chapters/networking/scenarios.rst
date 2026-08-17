Network Scenarios
=================

Below are some common networking setups that we found helpful to include.
You are welcome to contribute more.

SOHO (Small Office/Home Office)
-------------------------------

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
--------------------------------------------

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

VNET on GCP (Google Cloud Platform)
-----------------------------------

Bastille VNET runs on GCP with a few small tweaks. In summary, they are:

- change MTU setting in jib script
- add an IP address to the bridge interface
- configure host pf to NAT and allow bridge traffic
- set defaultrouter and nameserver in the host

GCP uses ``vtnet`` with MTU 1460, which `jib fails
on <https://github.com/BastilleBSD/bastille/issues/538>`_.

Apply the below patch to set the correct MTU. You may need to ``cp
/usr/share/examples/jails/jib /usr/local/bin/`` first.

``patch /usr/local/bin/jib jib.patch``

.. code-block:: text

  --- /usr/local/bin/jib	2022-07-31 03:27:04.163245000 +0000
  +++ jib.fixed	2022-07-31 03:41:16.710401000 +0000
  @@ -299,14 +299,14 @@

   		# Make sure the interface has been bridged
   		if ! ifconfig "$iface$bridge" > /dev/null 2>&1; then
  -			new=$( ifconfig bridge create ) || return
  +			new=$( ifconfig bridge create mtu 1460 ) || return
   			ifconfig $new addm $iface || return
   			ifconfig $new name "$iface$bridge" || return
   			ifconfig "$iface$bridge" up || return
   		fi

   		# Create a new interface to the bridge
  -		new=$( ifconfig epair create ) || return
  +		new=$( ifconfig epair create mtu 1460 ) || return
   		ifconfig "$iface$bridge" addm $new || return

   		# Rename the new interface

Configure the bridge interface in /etc/rc.conf so it is available in the
firewall rules.

.. code-block:: shell

  sysrc cloned_interfaces="bridge0"
  sysrc ifconfig_bridge0="inet 192.168.1.1/24 mtu 1460 addm vtnet0 name vtnet0bridge up"
  sysrc gateway_enable="yes"
  sysrc pf_enable="yes"

This basic /etc/pf.conf allow incoming packets on the bridge interface, and NATs
them through the external interface:

.. code-block:: text

  ext_if="vtnet0"
  bridge_if="vtnet0bridge"

  set skip on lo
  scrub in

  # permissive NAT allows jail bridge and wireguard tunnels
  nat on $ext_if inet from !($ext_if) -> ($ext_if:0)

  block in
  pass out

  pass in proto tcp to port {22}
  pass in proto icmp icmp-type { echoreq }
  pass in on $bridge_if

Restart the host and make sure everything comes up correctly. You should see the
following ifconfig:

.. code-block:: text

  vtnet0bridge: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1460
  	ether 58:9c:fc:10:ff:90
  	inet 192.168.1.1 netmask 0xffffff00 broadcast 192.168.1.255
  	id 00:00:00:00:00:00 priority 32768 hellotime 2 fwddelay 15
  	maxage 20 holdcnt 6 proto rstp maxaddr 2000 timeout 1200
  	root id 00:00:00:00:00:00 priority 32768 ifcost 0 port 0
  	member: vtnet0 flags=143<LEARNING,DISCOVER,AUTOEDGE,AUTOPTP>
  	        ifmaxaddr 0 port 1 priority 128 path cost 2000
  	groups: bridge

Set the default network gateway for new jails as described in the Networking
chapter, and configure a default resolver.

.. code-block:: shell

  sysrc -f /usr/local/etc/bastille/bastille.conf bastille_network_gateway="192.168.1.1"
  echo "nameserver 8.8.8.8" > /usr/local/etc/bastille/resolv.conf
  sysrc -f /usr/local/etc/bastille/bastille.conf bastille_resolv_conf="/usr/local/etc/bastille/resolv.conf"

You can now create a VNET jail with ``bastille create -V myjail 13.2-RELEASE
192.168.1.50/24 vtnet0``
