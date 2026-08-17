Bootstrapping a Release
=======================

In order to create a jail, we must first bootstrap a release to use as its
base OS. Bastille supports a number of release types.

For FreeBSD releases, there are some configurable options as to what will be
downloaded when bootstrapping a release.
See :doc:`/chapters/configuration/configuration-file`.

Legacy Releases
---------------

The first type of release Bastille supports is distribution sets. These
"dist" sets are official FreeBSD archives of a given release base.

To bootstrap a legacy release simpy run ``bastille bootstrap 15.0-RELEASE``. To
update the release immediately after bootstrapping it, run
``bastille bootstrap --update 15.0-RELEASE``.

Pkgbase Releases
----------------

Pkgbase is the new method introduced in FreeBSD 15, and is likely to become the standard
in FreeBSD 16. These releases are installed and managed completely by the ``pkg`` command.
Since FreeBSD 15, Bastille supports these types of releases as well.

Pkgbase only supports FreeBSD version 15 and above.

To bootstrap a release using pkgbase, run ``bastille bootstrap --pkgbase 15.0-RELEASE``. It
is not necessary to specify ``--update`` for pkgbase releases, as they are fetched from the
current package repository, and should already be up to date.

HardenedBSD Releases
--------------------

Bastille also supports bootstrapping HardenedBSD releases, but DOES NOT RECOMMEND using them
on a FreeBSD host. If you want to use HBSD releases, it is best to do so on an HBSD host, as
many of the tooling it uses differs from FreeBSD.

To bootstrap an HBSD release, there are some things to keep in mind.
HBSD follows the ``STABLE`` branches of FreeBSD, and releases
are named ``X-stable``, where ``X`` is the major version of a given FreeBSD
branch/release. It also has a ``current`` release, which follows the master/current
branch for the latest FreeBSD release. This is simply named ``current``.

So, to bootstrap a stable release, run ``bastille bootstrap 15-stable``. To bootstrap
the current release, run ``bastille bootstrap current``.

MidnightBSD Releases
--------------------

Bastille also supports bootstrapping MidnightBSD releases. It is also NOT RECOMMENDED to use
MBSD releases on any host other than a MBSD host.

To bootstrap an MBSD release, we simply use the semantic version of a given release. For
example, to bootstrap the latest release we can run ``bastille bootstrap 4.0.4``.

Linux
-----

Bastille has experimental support for bootstrapping Linux distributions. Currently Ubuntu and
Debian releases are the most supported.

Before we start playing with Linux on Bastille, run ``bastille setup linux``, which will
load the required modules and install the required packages.

To bootstrap a Linux distribution, use the code name for the given distribution. To bootstrap
Debian 12 for example, we can run ``bastille bootstrap bookworm``. Or, for Ubuntu 24, we
can run ``bastille bootstrap noble``.

Note that Linux distributions are still experimental, and might not fuction as well as standard
FreeBSD releases.