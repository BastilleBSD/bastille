Getting Started
===============

Bastille has many different options when it comes to creating
and managing jails. This guide is meant to show some basic
setup and configuration options.

Setup
-----

The first command a new user should run is ``bastille setup``. This
will configure the networking, storage, and firewall on your system
for use with Bastille.

By default the ``bastille setup`` will configure a loopback interface, storage (ZFS if
enabled, otherwise UFS) and the ``pf`` firewall.

Alternatively, you can run ``bastille setup OPTION`` command with any of the supported
options to configure the selected option by itself.

To see a list of available options, see the :doc:`/chapters/subcommands/setup` subcommand.

.. code-block:: shell

  ishmael ~ # bastille setup

Now we are ready to bootstrap a release and start creating jails.

Bootstrapping a Release
-----------------------

To bootstrap a release, run ``bastille bootstrap RELEASE``.

.. code-block:: shell

  ishmael ~ # bastille bootstrap 14.2-RELEASE

This will fetch the necessary components of the specified release, and
enable us to create jails from the downloaded release.

Creating a Jail
---------------

There are a few different types of jails we can create, described below.

* Thin jails are the default, and are called thin because they use symlinks to
  the bootstrapped release. They are lightweight and are created quickly.

* Thick jails use the entire release, which is copied into the jail. The jail
  then acts like a full BSD install, completely independent of the release.
  Created with the ``--thick|-T`` option.

* Clone jails are essentially clones of the bootstrapped release. Changes to the
  release will affect the clone jail. Created with the ``--clone|-C`` option.

* Empty jails are just that, empty. These should be used only if you know what
  you are doing. Created with the ``--empty|-E`` option.

* Linux jails are jails that run linux. Created with the ``--linux|-L`` option.
  See :doc:`/chapters/linux-jails`.

We will focus on thin jails for this guide.

Classic/Standard Jail
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: shell

  ishmael ~ # bastille create nextcloud 14.2-RELEASE 10.1.1.4/24

This will create a classic jail, which uses the loopback interface
(created with ``bastille setup``) for outbound connections.

To be able to reach a service inside the jail, use ``bastille rdr``.

.. code-block:: shell

  ishmael ~ # bastille rdr nextcloud tcp 80 80

This will forward traffic from port 80 on the host to port 80 inside the jail.
See also :doc:`/chapters/subcommands/rdr`.

VNET Jail
^^^^^^^^^

VNET jails can use either a host interface with ``-V`` or a manually created
bridge interface with ``-B``. You can also optionally set a static MAC for the
jail interface with ``-M``.

.. code-block:: shell

  ishmael ~ # bastille create -BM nextcloud 14.2-RELEASE 192.168.1.50/24 bridge0

or

.. code-block:: shell

  ishmael ~ # bastille create -VM nextcloud 14.2-RELEASE 192.168.1.50/24 vtnet0

The IP used for VNET jails should be an IP reachable inside your local network.
You can also specify 0.0.0.0 or DHCP to use DHCP.
