HardenedBSD
===========

Bastille supports HardenedBSD as an OS since it is FreeBSD based. There
are some differences in how HBSD handles release names, updates, and
upgrades.

Most of the Bastille commands will work with HardenedBSD, but please report
any bugs you may find.

There are a number of ways in which HardenedBSD differs from FreeBSD.
Most of the functionality is the same, but some things are different.
See the following examples...

Bootstrap
---------

HardenedBSD follows the ``STABLE`` branches of FreeBSD, and releases
are named ``X-stable``, where ``X`` is the major version of a given FreeBSD
branch/release.

It also has a ``current`` release, which follows the master/current
branch for the latest FreeBSD release.

When bootstrapping a release, use the above release keywords.

Updating
--------

To update HardenedBSD jails/releases you can do the following:

Thick Jails
^^^^^^^^^^^

1. Use ``bastille update TARGET`` to update the jail
2. Upgrade complete!

Thin Jails
^^^^^^^^^^

See ``bastille update RELEASE`` to update thin jails, as thin
jails are based on a given release.

Releases
^^^^^^^^

1. Use ``bastille update 15-stable`` to update the release to the latest version
2. Update complete!

Upgrading
---------

To upgrade HardenedBSD jails to a different (higher) release (ie; 14-stable > 15-stable)
you can do the following:

Thick Jails
^^^^^^^^^^^

1. Use ``bastille upgrade TARGET current`` to upgrade the jail to
   the ``current`` release
2. Force the reinstallation or upgrade of all installed packages (ABI change):
   ``pkg upgrade -f`` within each jail (or ``bastille pkg ALL upgrade -f``)
3. Upgrade complete!

Thin Jails
^^^^^^^^^^

1. Ensure the new release is bootstrapped: ``bastille bootstrap 15-stable``
2. Update the release: ``bastille update 15-stable``
3. Stop the jail(s) that need to be updated.
4. Use ``bastille upgrade TARGET 15-stable`` to automatically change the
   mount points to 15-stable
5. Start the jail(s)
6. Force the reinstallation or upgrade of all installed packages (ABI change):
   ``pkg upgrade -f`` within each jail (or ``bastille pkg ALL upgrade -f``)
7. Upgrade complete!

Releases
^^^^^^^^

The ``upgrade`` sub-command does not support upgrading a release
to a different release. See ``bastille bootstrap`` to bootstrap
the new release.

Limitations
-----------

Bastille tries its best to determine which *BSD you are using. It is possible to
mix and match any of the supported BSD distributions, but it is up to the end
user to ensure the correct environment/tools when doing so. See below...

* Running HardenedBSD jails/releases requires many of the tools found only
  in the HardenedBSD base.
* Running FreeBSD jails/releases requires many of the tools found only in
  the FreeBSD base.
