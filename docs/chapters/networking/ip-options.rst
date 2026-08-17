IP Address Options
==================

IPv4 Network
------------

Bastille includes a number of IP options for IPv4 networking.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE 192.168.1.50/24 vtnet0

The IP address specified above can be any of the following options.

* An IP in your local subnet should be chosen if you create your jail using
  ``-V``, ``-B`` or ``-P`` (VNET jail).

  Note: It is mandatory to add the subnet mask (/24 or whaterver your subnet is)
  to the IP for any types of VNET jail. See below...

* DHCP, SYNCDHCP, or 0.0.0.0 will configure your jail to use DHCP to obtain an
  address from your router. This should only be used with VNET jails.

* Any IP address inside the RFC1918 range if you are not using a VNET jail will cause
  Bastille to automatically add this IP to the firewall table to allow
  outbound access. It you want traffic to be forwarded into the jail, you can
  use the ``bastille rdr`` command. Bastille will not add the IP to the firewall table
  if the IP is reachable inside your local network.

* Any IP in your local network without any VNET options will add the
  IP as an alias to the selected interface, which will simply end up sharing the
  interface. If the IP is in your local subnet, you will not need the ``bastille
  rdr`` command. Traffic will pass in and out just as in a VNET jail.

* Setting the IP to ``inherit`` will make the jail inherit the entire host
  network stack.

* Setting the IP to ``ip_hostname`` will add all the IPs that the hostname
  resolves to. This is an advanced option and should only be used if you know
  what you are doing.

Standard (non-VNET) jails support specifying an IP without the subnet (/24 or whatever
yours is), but for VNET jails it is mandatory. If none is supplied, it will
default to /24. This is because FreeBSD does not support adding an IP to an interface
without a subnet.

IPv6 Network
------------

Bastille also supports IPv6. Instead of an IPv4 address, you can specify an
IPv6 address when creating a jail to use IPv6.

.. code-block:: shell

  bastille create alcatraz 13.2-RELEASE 2001:19f0:6c01:114c:0:100/64 vtnet0

The IP address specified above can be any of the following options.

* A valid IPv6 address including the subnet. If not subnet is given, it
  will defalut to /64.

* SLAAC will configure your jail to use router advertisement to obtain an
  address from your router. This should only be used with VNET jails.

Dual Stack Network
------------------

It is also possible to use both IPv4 and IPv6 by quoting an IPv4 and IPv6 addresses together
as seen in the following examples.

.. code-block:: shell

  bastille create alcatraz 14.3-RELEASE "192.168.1.50/24 2001:19f0:6c01:114c:0:100/64" vtnet0

.. code-block:: shell

  bastille create alcatraz 14.3-RELEASE "DHCP SLAAC" vtnet0

Note: For the ``inherit`` and ``ip_hostname`` options, you can also specify
``-D|--dual`` to use both IPv4 and IPv6 inside the jail. Otherwise, for dual
stack networking, simply supply both IPv4 and IPv6 addresses as seen above.