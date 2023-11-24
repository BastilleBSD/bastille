Network Requirements
====================
Here's the scenario. You've installed Bastille at home or in the cloud and want
to get started putting applications in secure little containers, but how do you
get these containers on the network?  Bastille tries to be flexible about how to 
network containerized applications. Four methods are described here.

1. Home or Small Office

2. Cloud with IPV4 and multiple IPV6

3. Cloud with single IPV4 (internal bridge)

4. Cloud with a single IPV4 (external bridge)

Please choose the option which is most appropriate for your environment.

First a few notes. Bastille tries to verify that the interface name you provide
is a valid interface. In FreeBSD network interfaces have different names, but
look something like `em0`, `bge0`, `re0`, `vtnet0` etc. Running the ifconfig
commend will tell you the name of your existing interfaces. Bastille also
checks for a valid syntax IP4 or IP6 address. When you are testing calling out
from your containers, please note that the ping command is disabled within the
containers, because raw socket access are a security hole. Instead, install and
test with `wget`/`curl`/`fetch` instead.

Shared Interface on Home or Small Office Network
================================================
If you have just one computer, or a home or small office network, where you are
separated from the rest of the internet by a router.  So you are free to use
`private IP addresses
<https://www.lifewire.com/what-is-a-private-ip-address-2625970>`_.

In this environment, to use Bastille, just create the container, give it a
unique private ip address, and attach its ip address to your primary interface.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE 192.168.1.50 em0

You may have to change em0

When the `alcatraz` container is started it will add `192.168.1.50` as an IP
alias to the `em0` interface. It will then simply be another member of the
hosts network. Other networked systems (firewall permitting) should be able to
reach services at that address.

This method is the simplest. All you need to know is the name of your network
interface and a free IP on your local network.

Shared Interface on IPV6 network (vultr.com)
============================================ 
Some ISP's, such as `Vultr <https://vultr.com>`_, give you a single ipv4 address,
and a large block of ipv6 addresses. You can then assign a unique ipv6 address
to each Bastille Container.

On a virtual machine such as vultr.com the virtual interface may be `vtnet0`.
So we issue the command:

.. code-block:: shell

 bastille create alcatraz 13.2-RELEASE 2001:19f0:6c01:114c::100 vtnet0

We could also write the ipv6 address as 2001:19f0:6c01:114c:0:100

The tricky part are the ipv6 addresses. IPV6 is a string of 8 4 digit
hexadecimal characters.  At vultr they said:

Your server was assigned the following six section subnet:

2001:19f0:6c01:114c:: / 64

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
forgotten. To make it permanent, prefix the same command with `sysrc`

Just remember you cannot ping out from the container. Instead, install and
use `wget`/`curl`/`fetch` to test the connectivity.


Virtual Network (VNET)
======================
(Added in 0.6.x) VNET is supported on FreeBSD 12+ only.

Virtual Network (VNET) creates a private network interface for a container.
This includes a unique hardware address. This is required for VPN, DHCP, and
similar containers.

To create a VNET based container use the `-V` option, an IP/netmask and
external interface.

.. code-block:: shell

  bastille create -V azkaban 13.2-RELEASE 192.168.1.50/24 em0

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
  add include $devfsrules_hide_all
  add include $devfsrules_unhide_basic
  add include $devfsrules_unhide_login
  add include $devfsrules_jail
  add include $devfsrules_jail_vnet
  add path 'bpf*' unhide

Lastly, you may want to consider these three `sysctl` values:

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

  
**Regarding Routes**

Bastille will attempt to auto-detect the default route from the host system and
assign it to the VNET container. This auto-detection may not always be accurate
for your needs for the particular container. In this case you'll need to add a
default route manually or define the preferred default route in the
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
=========================================
To create a VNET based container and attach it to an external, already existing
bridge, use the `-B` option, an IP/netmask and external bridge.

.. code-block:: shell

  bastille create -B azkaban 13.2-RELEASE 192.168.1.50/24 bridge0

Bastille will automagically create the interface, attach it to the specified
bridge and connect / disconnect containers as they are started and stopped.
The bridge needs to be created/enabled before creating and starting the jail.

Public Network
==============
In this section we describe how to network containers in a public network
such as a cloud hosting provider who only provides you with a single ip address. 
(AWS, Digital Ocean, etc) (The exception is vultr.com, which does 
provide you with lots of IPV6 addresses and does a great job supporting FreeBSD!)  

So if you only have a single IP address and if you want to create multiple
containers and assign them all unique IP addresses, you'll need to create a new
network.

loopback (bastille0)
--------------------
What we recommend is creating a cloned loopback interface (`bastille0`) and
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

  nat on $ext_if from <jails> to any -> ($ext_if:0)

The `nat` routes traffic from the loopback interface to the external
interface for outbound access.

.. code-block:: shell

  rdr-anchor "rdr/*"

The `rdr-anchor "rdr/*"` enables dynamic rdr rules to be setup using the
`bastille rdr` command at runtime - eg.

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
