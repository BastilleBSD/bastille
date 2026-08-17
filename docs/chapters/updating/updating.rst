Updating
--------

To keep jails updated with the latest security patches and base,
use the ``bastille update`` command.

Thick Jails
^^^^^^^^^^^

Use ``bastille update TARGET`` to update the jail with the latest
patches and security updates.

Thin Jails
^^^^^^^^^^

Use ``bastille update RELEASE`` to update the release that any thin jails
are based on with the latest patches and security updates.

Revert Upgrade / Downgrade Process
----------------------------------
The downgrade process (not usually needed) is similar to the upgrade process,
only in reverse.

Thick Jails
^^^^^^^^^^^

Thick jails should not be downgraded and is not supported in general on FreeBSD.

Thin Jails
^^^^^^^^^^

Not recommended, but you can run ``bastille upgrade TARGET 13.1-RELEASE`` to
downgrade a thin jail. Make sure to run ``bastille etcupdate TARGET update
13.1-RELEASE`` to keep the contents of /etc updated with each release.

The pkg re-installation will also need to be repeated after the jail restarts on
the previous release.

Old Releases
------------

After upgrading all jails from one release to the next you may find that you now
have bootstrapped a release that is no longer used. Once you've decided that you
no longer need the option to revert the change you can destroy the old release.

``bastille list releases`` to list all bootstrapped releases.

``bastille destroy X.Y-RELEASE`` to fully delete the release, including the
cache (cache is not used with pkgbase).

``bastille destroy -c|--no-cache X.Y-RELEASE`` to retain the cache directory
(not supported when using pkgbase).
