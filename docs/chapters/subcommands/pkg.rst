===
pkg
===

To manage binary packages within the container use `bastille pkg`.

.. code-block:: shell

  ishmael ~ # bastille pkg folsom install vim-console git-lite zsh
  [folsom]:
  The package management tool is not yet installed on your system.
  Do you want to fetch and install it now? [y/N]: y
  ...[snip]...

  Number of packages to be installed: 10

  The process will require 77 MiB more space.
  17 MiB to be downloaded.

  Proceed with this action? [y/N]: y
  ...[snip]...


The PKG sub-command can, of course, do more than just `install`. The
expectation is that you can fully leverage the pkg manager. This means,
`install`, `update`, `upgrade`, `audit`, `clean`, `autoremove`, etc., etc.

.. code-block:: shell

  ishmael ~ # bastille pkg ALL upgrade
  [bastion]:
  Updating pkg.bastillebsd.org repository catalogue...
  [bastion] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [bastion] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 493 packages processed.
  All repositories are up to date.
  Checking for upgrades (1 candidates): 100%
  Processing candidates (1 candidates): 100%
  Checking integrity... done (0 conflicting)
  Your packages are up to date.

  [unbound0]:
  Updating pkg.bastillebsd.org repository catalogue...
  [unbound0] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [unbound0] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 493 packages processed.
  All repositories are up to date.
  Checking for upgrades (0 candidates): 100%
  Processing candidates (0 candidates): 100%
  Checking integrity... done (0 conflicting)
  Your packages are up to date.

  [unbound1]:
  Updating pkg.bastillebsd.org repository catalogue...
  [unbound1] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [unbound1] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 493 packages processed.
  All repositories are up to date.
  Checking for upgrades (0 candidates): 100%
  Processing candidates (0 candidates): 100%
  Checking integrity... done (0 conflicting)
  Your packages are up to date.

  [squid]:
  Updating pkg.bastillebsd.org repository catalogue...
  [squid] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [squid] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 493 packages processed.
  All repositories are up to date.
  Checking for upgrades (0 candidates): 100%
  Processing candidates (0 candidates): 100%
  Checking integrity... done (0 conflicting)
  Your packages are up to date.

  [nginx]:
  Updating pkg.bastillebsd.org repository catalogue...
  [nginx] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [nginx] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 493 packages processed.
  All repositories are up to date.
  Checking for upgrades (1 candidates): 100%
  Processing candidates (1 candidates): 100%
  The following 1 package(s) will be affected (of 0 checked):

  Installed packages to be UPGRADED:
      nginx-lite: 1.23.0 -> 1.24.0_12,3

  Number of packages to be upgraded: 1

  315 KiB to be downloaded.

  Proceed with this action? [y/N]: y
  [nginx] [1/1] Fetching nginx-lite-1.14.1,2.txz: 100%  315 KiB 322.8kB/s    00:01
  Checking integrity... done (0 conflicting)
  [nginx] [1/1] Upgrading nginx-lite from 1.23.0 to 1.24.0_12,3...
  ===> Creating groups.
  Using existing group 'www'.
  ===> Creating users
  Using existing user 'www'.
  [nginx] [1/1] Extracting nginx-lite-1.24.0_12: 100%
  You may need to manually remove /usr/local/etc/nginx/nginx.conf if it is no longer needed.
