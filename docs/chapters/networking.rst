Network Requirements
====================
Here's the scenario. You've installed Bastille at home or in the cloud and want
to get started putting applications in secure little containers, but how do I
get these containers on the network?

Bastille tries to be flexible about how to network containerized applications.
The two most common methods are described here. Consider both options to decide
which design work best for your needs. One of the methods works better across
clouds while the other is simpler if used in local area networks.

As you've probably seen, Bastille containers require certain information when
they are created. An IP address has to be assigned to the container through
which all network traffic will flow.

When the container is started the IP address assigned at creation will be bound
to a network interface. In FreeBSD these interfaces have different names, but
look something like `em0`, `bge0`, `re0`, etc. On a virtual machine it may be
`vtnet0`. You get the idea...

**Note: if you are running in the cloud and only have a single public IP you
may want the Public Network option. See below.**


Local Area Network
------------------
I will cover the local area network (LAN) method first. This method is simpler
to get going and works well in a home network (or similar) where adding alias
IP addresses is no problem.

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

(Bastille does try to verify that the interface name you provide it is a valid
interface. This validation has not been exhaustively tested yet in Bastille's
beta state.)


Public Network
--------------
In this section I'll describe how to network containers in a public network
such as a cloud hosting provider (AWS, digital ocean, vultr, etc)

In the public cloud you don't often have access to multiple private IP
addresses for your virtual machines. This means if you want to create multiple
containers and assign them all IP addresses, you'll need to create a new
network.

What I recommend is creating a cloned loopback interface (`bastille0`) and
assigning all the containers private (rfc1918) addresses on that interface. The
setup I develop on and use Bastille day to day uses the `10.0.0.0/8` address
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
  nat on $ext_if from <jails> to any -> ($ext_if)

  ## static rdr example
  ## rdr pass inet proto tcp from any to any port {80, 443} -> 10.17.89.45

  ## dynamic rdr anchor (see below)
  rdr-anchor "rdr/*"

  block in all
  pass out quick modulate state
  antispoof for $ext_if inet
  pass in inet proto tcp from any to any port ssh flags S/SA modulate state

  # If you are using dynamic rdr also need to ensure that the external port
  # range you are using is open
  # pass in inet proto tcp any to any port <rdr-start>:<rdr-end>

- Make sure to change the `ext_if` variable to match your host system interface.
- Make sure to include the last line (`port ssh`) or you'll end up locked out.

Note: if you have an existing firewall, the key lines for in/out traffic
to containers are:

.. code-block:: shell

  nat on $ext_if from <jails> to any -> ($ext_if)

  ## static rdr example
  ## rdr pass inet proto tcp from any to any port {80, 443} -> 10.17.89.45

The `nat` routes traffic from the loopback interface to the external
interface for outbound access.

The `rdr pass ...` will redirect traffic from the host firewall on port X to
the ip of Container Y. The example shown redirects web traffic (80 & 443) to the
containers at `10.17.89.45`.

  ## dynamic rdr anchor (see below)
  rdr-anchor "rdr/*"

The `rdr-anchor "rdr/*"` enables dynamic rdr rules to be setup using the
`bastille rdr` command at runtime - eg.

  bastille rdr <jail> tcp 2001 22 # Redirects tcp port 2001 on host to 22 on jail
  bastille rdr <jail> udp 2053 53 # Same for udp
  bastille rdr <jail> list        # List dynamic rdr rules
  bastille rdr <jail> clear       # Clear dynamic rdr rules

  Note that if you are redirecting ports where the host is also listening
  (eg. ssh) you should make sure that the host service is not listening on
  the cloned interface - eg. for ssh set sshd_flags in rc.conf

  sshd_flags="-o ListenAddress=<hostname>"

Finally, start up the firewall:

.. code-block:: shell

  ishmael ~ # service pf restart

At this point you'll likely be disconnected from the host. Reconnect the
ssh session and continue.

This step only needs to be done once in order to prepare the host.
