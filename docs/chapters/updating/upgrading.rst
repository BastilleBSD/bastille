Upgrading
=========

This document outlines updating and upgrading jails hosted by Bastille.

Bastille can "bootstrap" multiple versions of FreeBSD to be used by jails. All
jails do not NEED to be the same version (even if they often are), the only
requirement here is that the "bootstrapped" versions are less than or equal to
the host version of FreeBSD.

To keep releases updated, use ``bastille update RELEASE``

To keep thick jails updated, use ``bastille update TARGET``

Minor Release Upgrades - Legacy
-------------------------------

To upgrade Bastille jails for a minor release (ie; 13.1 > 13.2) you can do the
following:

Thick Jails
^^^^^^^^^^^

1. Use ``bastille upgrade TARGET 13.2-RELEASE`` to upgrade the jail to
   13.2-RELEASE
2. Use ``bastille upgrade TARGET install`` to apply the updates
3. Reboot the jail ``bastille restart TARGET``
4. Use ``bastille upgrade TARGET install`` to finish applying the
   upgrade
5. Upgrade complete!

Thin Jails
^^^^^^^^^^

1. Ensure the new release version is bootstrapped: ``bastille bootstrap 13.2-RELEASE``
2. Update the release (optional): ``bastille update 13.2-RELEASE``
3. Stop the jail(s) that need to be updated.
4. Use ``bastille upgrade TARGET 13.2-RELEASE`` to automatically change the mount points to 13.2-RELEASE
5. Start the jail(s)
6. Upgrade complete!

Major Release Upgrades - Legacy
-------------------------------

To upgrade Bastille jails for a major release (ie; 12.4 > 13.2) you can do the
following:

Thick Jails
^^^^^^^^^^^

1. Use ``bastille upgrade TARGET 13.2-RELEASE`` to upgrade the jail to
   13.2-RELEASE
2. Use ``bastille upgrade TARGET install`` to apply the updates
3. Reboot the jail ``bastille restart TARGET``
4. Use ``bastille upgrade TARGET install`` to finish applying the
   upgrade
5. Force the reinstallation or upgrade of all installed packages (ABI change):
   ``pkg upgrade -f`` within each jail (or ``bastille pkg ALL upgrade -f``)
6. Upgrade complete!

Thin Jails
^^^^^^^^^^

1. Ensure the new release version is bootstrapped: ``bastille bootstrap 13.2-RELEASE``
2. Update the release: ``bastille update 13.2-RELEASE``
3. Stop the jail(s) that need to be updated.
4. Use ``bastille upgrade TARGET 13.2-RELEASE`` to automatically change the
   mount points to 13.2-RELEASE
5. Use ``bastille etcupdate bootstrap 13.2-RELEASE`` to bootstrap src for
   13.2-RELEASE
6. Use ``bastille etcupdate TARGET update 13.2-RELEASE`` to update the contents
   of /etc for 13.2-RELEASE
7. Use ``bastille etcupdate TARGET resolve`` to resolve any conflicts
8. Start the jail(s)
9. Force the reinstallation or upgrade of all installed packages (ABI change):
   ``pkg upgrade -f`` within each jail (or ``bastille pkg ALL upgrade -f``)
10. Upgrade complete!

Minor Release Upgrades - Pkgbase
--------------------------------

To upgrade Bastille jails for a minor release (ie; 15.1 > 15.2) you can do the
following:

Thick Jails
^^^^^^^^^^^

1. Use ``bastille upgrade TARGET 15.2-RELEASE`` to upgrade the jail to
   15.2-RELEASE
2. Reboot the jail ``bastille restart TARGET``
3. Upgrade complete!

Thin Jails
^^^^^^^^^^

1. Ensure the new release version is bootstrapped: ``bastille bootstrap --pkgbase 15.2-RELEASE``
2. Update the release (optional): ``bastille update 15.2-RELEASE``
3. Stop the jail(s) that need to be updated.
4. Use ``bastille upgrade TARGET 15.2-RELEASE`` to automatically change the mount points to 15.2-RELEASE
5. Start the jail(s)
6. Upgrade complete!

Major Release Upgrades - Pkgbase
--------------------------------

To upgrade Bastille jails for a major release (ie; 15.5 > 16.0) you can do the
following:

Thick Jails
^^^^^^^^^^^

1. Use ``bastille upgrade TARGET 16.0-RELEASE`` to upgrade the jail to
   16.0-RELEASE
2. Reboot the jail ``bastille restart TARGET``
3. Force the reinstallation or upgrade of all installed packages (ABI change):
   ``pkg upgrade -f`` within each jail (or ``bastille pkg ALL upgrade -f``)
4. Upgrade complete!

Thin Jails
^^^^^^^^^^

1. Ensure the new release version is bootstrapped: ``bastille bootstrap 16.0-RELEASE``
2. Update the release: ``bastille update 16.0-RELEASE``
3. Stop the jail(s) that need to be updated.
4. Use ``bastille upgrade TARGET 16.0-RELEASE`` to automatically change the
   mount points to 16.0-RELEASE
5. Use ``bastille etcupdate bootstrap 16.0-RELEASE`` to bootstrap src for
   16.0-RELEASE
6. Use ``bastille etcupdate TARGET update 16.0-RELEASE`` to update the contents
   of /etc for 16.0-RELEASE
7. Use ``bastille etcupdate TARGET resolve`` to resolve any conflicts
8. Start the jail(s)
9. Force the reinstallation or upgrade of all installed packages (ABI change):
   ``pkg upgrade -f`` within each jail (or ``bastille pkg ALL upgrade -f``)
10. Upgrade complete!