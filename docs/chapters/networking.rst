Network Requirements
====================
Here's the scenario. You've installed Bastille at home or in the cloud and want
to get started putting applications in secure little containers, but how do I
get these containers on the network?

Bastille tries to be flexible about how to network containerized applications.
Three methods are described here. Consider each options when deciding
which design work best for your needs. One of the methods works better in the 
cloud while the others are simpler if used in local area networks.

**Note: if you are running in the cloud and only have a single public IP you
may want the Public Network option. See below.**


Local Area Network
==================
I will cover the local area network (LAN) method first. This method is simpler
to get going and works well in a home network (or similar) where adding alias
IP addresses is no problem.

Shared Interface (IP alias)
---------------------------
In FreeBSD network interfaces have different names, but look something like
`em0`, `bge0`, `re0`, etc. On a virtual machine it may be `vtnet0`. You get the
idea...

Bastille allows you to define the interface you want the IP attached to when
you create it. An example:

.. code-block:: shell

  bastille create alcatraz 12.1-RELEASE 192.168.1.50 em0

When the `alcatraz` container is started it will add `192.168.1.50` as an IP
alias to the `em0` interface. It will then simply be another member of the
hosts network. Other networked systems (firewall permitting) should be able to
reach services at that address.

This method is the simplest. All you need to know is the name of your network
interface and a free IP on your current network.

Bastille tries to verify that the interface name you provide it is a valid
interface. It also checks for a valid syntax IP4 or IP6 address.

Virtual Network (VNET)
----------------------
(Added in 0.6.x) VNET is supported on FreeBSD 12+ only.

Virtual Network (VNET) creates a private network interface for a container.
This includes a unique hardware address. This is required for VPN, DHCP, and
similar containers.

To create a VNET based container use the `-V` option, an IP/netmask and
external interface.

.. code-block:: shell

  bastille create -V azkaban 12.1-RELEASE 192.168.1.50/24 em0

Bastille will automagically create the bridge interface and connect /
disconnect containers as they are started and stopped. A new interface will be
created on the host matching the pattern `interface0bridge`. In the example
here, `em0bridge`. 

The `em0` interface will be attached to the bridge along with the unique
container interfaces as they are started and stopped. These interface names
match the pattern `eXb_bastilleX`. Internally to the containers these
interfaces are presented as `vnet0`.

VNET also requires a custom devfs ruleset. Create the file as needed on the
host system:

.. code-block:: shell

  ## /etc/devfs.rules (NOT .conf)
  
  [bastille_vnet=13]
  add path 'bpf*' unhide

Lastly, you may want to consider these three `sysctl` values:

.. code-block:: shell

  net.link.bridge.pfil_bridge=0
  net.link.bridge.pfil_onlyip=0
  net.link.bridge.pfil_member=0

**Regarding Routes**

Bastille will attempt to auto-detect the default route from the host system and
assign it to the VNET container. This auto-detection may not always be accurate
for your needs for the particular container. In this case you'll need to add
a default route manually or define the preferred default route in the
`bastille.conf`.

.. code-block:: shell

  bastille sysrc TARGET defaultrouter=aa.bb.cc.dd
  bastille service TARGET routing restart

To define a default route / gateway for all VNET containers define the value in
`bastille.conf`:

.. code-block:: shell

  bastille_network_gateway=aa.bb.cc.dd

This config change will apply the defined gateway to any new containers.
Existing containers will need to be manually updated.

Virtual Network (VNET) on External Bridge
--------------------------------------
To create a VNET based container and attach it to an external, already existing bridge, use the `-B` option, an IP/netmask and
external bridge.

.. code-block:: shell

  bastille create -B azkaban 12.1-RELEASE 192.168.1.50/24 bridge0

Bastille will automagically create the interface, attach it to the specified bridge and connect /
disconnect containers as they are started and stopped. 
The bridge needs to be created/enabled before creating and starting the jail.

Public Network
==============
In this section I'll describe how to network containers in a public network
such as a cloud hosting provider (AWS, digital ocean, vultr, etc)

In the public cloud you don't often have access to multiple private IP
addresses for your virtual machines. This means if you want to create multiple
containers and assign them all IP addresses, you'll need to create a new
network.

loopback (bastille0)
--------------------
What I recommend is creating a cloned loopback interface (`bastille0`) and
assigning all the containers private (rfc1918) addresses on that interface. The
setup I develop on and use Bastille day-to-day uses the `10.0.0.0/8` address
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
------------
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
  pass in inet proto tcp from any to any port ssh flags S/SA modulate state

- Make sure to change the `ext_if` variable to match your host system interface.
- Make sure to include the last line (`port ssh`) or you'll end up locked out.

Note: if you have an existing firewall, the key lines for in/out traffic
to containers are:

.. code-block:: shell

  nat on $ext_if from <jails> to any -> ($ext_if)

The `nat` routes traffic from the loopback interface to the external
interface for outbound access.

.. code-block:: shell

  rdr-anchor "rdr/*"

The `rdr-anchor "rdr/*"` enables dynamic rdr rules to be setup using the
`bastille rdr` command at runtime - eg.

.. code-block:: shell

  bastille rdr <jail> tcp 2001 22 # Redirects tcp port 2001 on host to 22 on jail
  bastille rdr <jail> udp 2053 53 # Same for udp
  bastille rdr <jail> list        # List dynamic rdr rules
  bastille rdr <jail> clear       # Clear dynamic rdr rules

Note that if you are redirecting ports where the host is also listening (eg.
ssh) you should make sure that the host service is not listening on the cloned
interface - eg. for ssh set sshd_flags in rc.conf

  sshd_flags="-o ListenAddress=<hostname>"

Finally, start up the firewall:

.. code-block:: shell

  ishmael ~ # service pf restart

At this point you'll likely be disconnected from the host. Reconnect the
ssh session and continue.

This step only needs to be done once in order to prepare the host.
