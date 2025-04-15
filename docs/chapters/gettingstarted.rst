Getting Started
===============

This guide is meant to get you up and running with bastille, and will show you a number
of different options to create and manage your jails.

The first step is running ``bastille setup`` to try to configure bastille initially.

.. code-block:: shell

  ishmael ~ # bastille setup

Then we need to bootstrap a release for bastille to use. We will use 14.2-RELEASE.

.. code-block:: shell

  ishmael ~ # bastille bootstrap 14.2-RELEASE

Next we can create our first jail. Bastille can create a few different types of jails.

* Thin jails are the default, and are called thin because they use symlinks to the bootstrapped release. They are lightweight and are created quickly.

* Thick jails used the entire release, which is copied into the jail. The jail then acts like a full BSD install, completely independant of the release. Created with ``bastille create -T``.

* Clone jails are essentially clones of the bootstrapped release. Changes to the release will affect the clone jail. Created with ``bastille create -C``.

* Empty jails are just that, empty. These should be used only if you know what you are doing. Created with ``bastille create -E``.

* Linux jails are jails that run linux. Created with ``bastille create -L``.

Only clone, thin, and thick jails can be created with ``-V`` ``-B`` and ``-M``.

We will focus on thin jails for the guide.

Classic/Standard Jail
---------------------

.. code-block:: shell

  ishmael ~ # bastille create nextcloud 14.2-RELEASE 10.1.1.4/24 vtnet0

This will create a classic jail and add the IP as an alias to the vtnet0 interface. This jail will
use NAT for its outbound traffic. If you want to run a webserver of something similar inside it, you
will have to redirect traffic from the host using ``bastille rdr``

It the IP is reachable within your local subnet, however, then it is not necessary to redirect the
traffic. It will pass in and out normally.

.. code-block:: shell

  ishmael ~ # bastille rdr nextcloud tcp 80 80

This will forward traffic from port 80 on the host to port 80 inside the jail.

VNET Jail
---------

VNET jails can use either a host interface with ``-V`` or a manually created bridge interface with ``-B``. You can
also optionally set a static MAC for the jail interface with ``-M``.

.. code-block:: shell

  ishmael ~ # bastille create -BM nextcloud 14.2-RELEASE 192.168.1.50/24 bridge0

or 

.. code-block:: shell

  ishmael ~ # bastille create -VM nextcloud 14.2-RELEASE 192.168.1.50/24 vtnet0

The IP used for VNET jails should be an IP reachable inside your local network. You can also specify 0.0.0.0 or DHCP
to use DHCP.

Linux Jail
----------

Linux jails are still considered experimental, but they seem to work. First we must bootstrap a linux distro.

.. code-block:: shell

  ishmael ~ # bastille bootstrap bionic

Then we can create our linux jail using this release. This will take a while...

.. code-block:: shell

  ishmael ~ # bastille create -L linuxjail bionic 10.1.1.7/24 vtnet0
