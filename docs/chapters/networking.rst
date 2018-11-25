====================
Network Requirements
====================

In order to segregate jails from the network and from the world, Bastille
attaches jails to a loopback interface only. The host system then acts as
the firewall, permitting and denying traffic as needed.

First, create the loopback interface:

.. code-block:: shell

  ishmael ~ # sysrc cloned_interfaces+=lo1
  ishmael ~ # service netif cloneup

Second, enable NAT through the firewall:

.. code-block:: shell

  ishmael ~ # sysrc pf_enable="YES"

/etc/pf.conf
------------

Create the firewall config, or merge as necessary.

.. code-block:: shell

  ext_if="vtnet0"
  
  set block-policy drop
  scrub in on $ext_if all fragment reassemble
  
  set skip on lo
  nat on $ext_if from !($ext_if) -> ($ext_if:0)
  
  ## rdr example
  ## rdr pass inet proto tcp from any to any port {80, 443} -> 10.88.9.45
  
  block in log all
  pass out quick modulate state
  antispoof for $ext_if inet
  pass in inet proto tcp from any to any port ssh flags S/SA keep state


- Make sure to change the `ext_if` variable to match your host system interface.
- Make sure to include the last line (`port ssh`) or you'll end up locked out.


Note: if you have an existing firewall, the key lines for in/out traffic
to jails are:

.. code-block:: shell

  nat on $ext_if from lo1:network to any -> ($ext_if)
  
  ## rdr example
  ## rdr pass inet proto tcp from any to any port {80, 443} -> 10.88.9.45

The `nat` routes traffic from the loopback interface to the external
interface for outbound access.

The `rdr pass ...` will redirect traffic from the host firewall on port X
to the ip of Jail Y. The example shown redirects web traffic (80 & 443) to
the jails at `10.88.9.45`.

We'll get to that later, but when you're ready to allow traffic inbound to
your jails, that's where you'd do it.

Finally, start up the firewall:

.. code-block:: shell

  ishmael ~ # service pf restart

At this point you'll likely be disconnected from the host. Reconnect the
ssh session and continue.

This step only needs to be done once in order to prepare the host.
