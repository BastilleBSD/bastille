Linux Jails
===========

Bastille can create Linux jails using the ``debootstrap`` tool. When
attempting to create a Linux jail, Bastille will need to load some modules
as well as install the ``debootstrap`` package. When prompted, enter
'yes' when bootstrapping a Linux release.

Bootstrapping a Linux Release
-----------------------------

To bootstrap a Linux release, run ``bastille bootstrap bionic`` or
whichever release you want to bootstrap. Once bootstrapped, we can
use the ``--linux|-L`` option to create a Linux jail.

Creating a Linux Jail
---------------------

To create a Linux jail, run ``bastille create -L mylinuxjail bionic 10.1.1.3``.
This will create and initialize your jail using the ``debootstrap`` tool.

Once the jail is created, proceed to do your "linux stuff".

Limitations
-----------

* Linux jails are still considered experimental.

* Linux jails cannot be created with any type of VNET options.