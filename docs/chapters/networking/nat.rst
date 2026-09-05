NAT Configuration
=================

For NAT jails, we recommend creating a cloned loopback interface (``bastille0``) and
assigning all the jails private (rfc1918) addresses on that interface. The
setup I develop on and use Bastille day-to-day uses the ``10.0.0.0/8`` address
range. I have the ability to use whatever address I want within that range
because I've created my own private network. The host system then acts as the
firewall, permitting and denying traffic as needed.

I find this setup the most flexible across all types of networks. It can be
used in public and private networks just the same and it allows me to keep
jails off the network until I allow access.

Having said all that here are instructions I used to configure the network with
a private loopback interface and system firewall. The system firewall NATs
traffic out of jails and can selectively redirect traffic into jails
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
This file should be placed at ``/etc/pf.conf``

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

  anchor "bastille/*"
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
``bastille rdr`` command at runtime.

.. code-block:: shell

  anchor "bastille/*"

The ``anchor "bastille/*"`` enables more granular filtering for inbound traffic
for the rdr rules.

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