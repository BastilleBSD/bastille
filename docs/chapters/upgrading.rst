=========
Upgrading
=========
This document outlines upgrading jails hosted using Bastille.

Bastille can "bootstrap" multiple versions of FreeBSD to be used by jails. All jails do not NEED to be the same version (even if they often are), the only requirement here is that the "bootstrapped" versions are less than or equal to the host version of FreeBSD.

To upgrade Bastille jails for a minor release (ie; 13.1→13.2) you can do the following:

1. ensure the new release version is bootstrapped and updated to the latest patch release: `bastille bootstrap 13.2-RELEASE update`
2. stop the jail(s) that need to be updated.
3. use `bastille edit TARGET fstab` to manually update the jail mounts from 13.1 to 13.2 release path.
4. start the jail(s) that were edited
5. upgrade complete!

To upgrade Bastille jails for a major release (ie; 12.4→13.2) you can do the following:

1. ensure the new version is bootstrapped and update to the latest patch release: `bastille bootstrap 13.2-RELEASE update`
2. stop the jail(s) that need to be updated.
3. use `bastille edit TARGET fstab` to manually update the jail mounts from 12.4 to 13.2 release path.
4. start the jail(s) that were edited
5. Force the reinstallation or upgrade of all installed packages (ABI change): `pkg upgrade -f` within each jail (or `bastille pkg ALL upgrade -f`)
6. restart the affected jail(s)
7. upgrade complete!

Revert Upgrade / Downgrade Process
----------------------------------
The downgrade process (not usually needed) is similar to the upgrade process only in reverse.

If you did a minor upgrade changing the release path from 13.1 to 13.2, stop the jail and revert that change. Downgrade complete.

If you did a major upgrade changing the release path from 12.4 to 13.2, stop the jail and revert that change. The pkg reinstallation will also need to be repeated after the jail restarts on the previous release.

Old Releases
----------------------------------
After upgrading all jails from one release to the next you may find that you now have bootstrapped a release that is no longer used. Once you've decided that you no longer need the option to revert the change you can destroy the old release.


`bastille list releases` to list all bootstrapped releases.

`bastille destroy X.Y-RELEASE` to fully delete the release. 
