DNS Configuration
=================

Version 1.5.0 of Bastille introduces the ability to configure DNS reolution
form host to jail as well as jail to jail using DNS names. This is done using
the ``local-unbound`` package included in default FreeBSD installs.

.. attention::

   The DNS feature set is experimental, and might be removed in a future version
   of Bastille.

Getting Started
---------------

To get started, you will need to make sure your ``bastille.conf`` file includes
the following variables"

.. code-block:: shell

  bastille_dns_enable=""
  bastille_dns_interface="${bastille_network_loopback}"
  bastille_dns_gateway="10.0.0.1"
  bastille_dns_domain="bastille"

* ``bastille_dns_enable`` will either enable or disable DNS for Bastille
* ``bastille_dns_interface`` is the interface the DNS server should listen on
* ``bastille_dns_gateway`` is the IP address of the DNS server
* ``bastille_dns_domain`` is the top level domain part of the DNS name

To get started right away, run ``bastille setup dns``. This will
set ``bastille_dns_enable="YES"``, add and persit ``bastille_dns_gateway`` to
the interface set in ``bastille_dns_interface``, and
run ``local-unbound-setup`` for you.

The ``local-unbound-setup`` sets your default resolver to
be ``127.0.0.1`` and adds your nameserver as a forwarder. Once that is
complete, ``bastille setup dns`` will start ``local-unbound``.

At this point, please make sure your networking is still working by
running ``pkg update`` or ``ping google.com``. It should work, but if it does
not, file a bug on the Bastille Github repo.

When networking is confirmed working, restart your jails and you should be able
to reach them using ``jailname.bastille`` from the host, or any other non-VNET jail.

.. important::

   VNET jails do not support the DNS feature set.

Manual Setup
------------

If you like manual work, and prefer not to run ``bastille setup dns`` for any reason,
here are the necessary steps to get DNS working.

First, enable ``local-unbound``:

.. code-block:: shell

  sysrc local_unbound_enable=YES

Next, we need to add our custom ``bastille.conf`` unbound config file to make
sure it will listne on the proper interfaces on startup. Place the contents of
the following file at ``/var/unbound/conf.d/bastille.conf``:

.. code-block:: shell

  server:
      # localhost (for host resolving)
      interface: 127.0.0.1
      # bastille_dns_gateway
      interface: 10.0.0.1

      # allow all rfc1918 addresses (local)
      access-control: 127.0.0.1/8 allow
      access-control: 10.0.0.0/8 allow
      access-control: 192.168.0.0/16 allow
      access-control: 172.16.0.0/12 allow

If you don't want local addresss all able to use your gateway, remove and edit
the ``access-control:`` entries.

Next, run ``local-unbound-setup``, which will configure your systems nameserver
as a forwarder, and set your new nameserver to ``127.0.0.1`` where ``local-unbound``
should be listening. After that, start ``local-unbound``:

.. code-block:: shell

  local-unbound-setup
  service local_unbound start

At this point you should confirm networking is still up, and restart your jails.
To confirm DNS is working as intended, run ``ping myjail.bastille``.

Notes
-----

* VNET jails do not support having their IP addresses added to the resolver, but there is
  a way to allow VNET jails to reach other jails via DNS, and that is to run the following
  two commands:

.. code-block:: shell

  bastille sysrc myjail static_routes="bastille"
  bastille sysrc myjail route_bastille="-net 10.0.0.1/32 192.168.1.10"

The ``10.0.0.1/32`` is the address of ``bastille_dns_gateway`` while
the ``192.168.1.10`` is the address of the interface IP the VNET jail is
connected to.

* ``bastille_dns_interface`` is purposely set to the same loopback interface used for NAT
   jails. NAT jails are the primary focus of the DNS feature set, and as such, will need to
   be able to reach the resolver. Alias/Shared IP jails also support this.

* ``bastille_dns_gateway`` should be set to an IP outside your local network. If your local
  network runs on ``10.x.x.x``, you should set this to something like ``172.16.0.1`` or
  perhaps ``192.168.1.1``. We set this to ``10.0.0.1`` because most networks run in
  the ``192.168.x.x`` range.

* If ``bastille_dns_domain`` is left empty, it will default to ``bastille``.
