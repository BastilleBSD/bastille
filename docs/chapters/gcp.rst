Bastille VNET on GCP
====================

Bastille VNET runs on GCP with a few small tweaks. In summary, they are:

- change MTU setting in jib script
- add an IP address to the bridge interface
- configure host pf to NAT and allow bridge traffic
- set defaultrouter and nameserver in the host

## Change MTU in the jib script

GCP uses ``vtnet`` with MTU 1460, which [jib fails on](https://github.com/BastilleBSD/bastille/issues/538).

Apply the below patch to set the correct MTU. You may need to ``cp /usr/share/examples/jails/jib /usr/local/bin/`` first.

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

## Configure bridge interface

Configure the bridge interface in /etc/rc.conf so it is available in the firewall rules.

.. code-block:: shell
  sysrc cloned_interfaces="bridge0"
  sysrc ifconfig_bridge0="inet 192.168.1.1/24 mtu 1460 addm vtnet0 name vtnet0bridge up"
  sysrc gateway_enable="yes"
  sysrc pf_enable="yes"

## Configure host pf

This basic /etc/pf.conf allow incoming packets on the bridge interface, and NATs them through the external interface:

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
  pass in inet proto icmp icmp-type { echoreq }
  pass in on $bridge_if

Restart the host and make sure everything comes up correctly. You should see the following ifconfig:

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

## Configure router and resolver for new jails

Set the default network gateway for new jails as described in the Networking chapter, and configure a default resolver.

.. code-block:: shell
  sysrc -f /usr/local/etc/bastille/bastille.conf bastille_network_gateway="192.168.1.1"
  echo "nameserver 8.8.8.8" > /usr/local/etc/bastille/resolv.conf
  sysrc -f /usr/local/etc/bastille/bastille.conf bastille_resolv_conf="/usr/local/etc/bastille/resolv.conf"

You can now create a VNET jail with ``bastille create -V myjail 13.2-RELEASE 192.168.1.50/24 vtnet0``
