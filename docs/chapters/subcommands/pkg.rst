===
pkg
===

To manage binary packages within the container use `bastille pkg`.

.. code-block:: shell

  ishmael ~ # bastille pkg folsom 'install vim-console git-lite zsh'
  [folsom]:
  The package management tool is not yet installed on your system.
  Do you want to fetch and install it now? [y/N]: y
  Bootstrapping pkg from pkg+http://pkg.FreeBSD.org/FreeBSD:10:amd64/quarterly, please wait...
  Verifying signature with trusted certificate pkg.freebsd.org.2013102301... done
  [folsom] Installing pkg-1.10.5_5...
  [folsom] Extracting pkg-1.10.5_5: 100%
  Updating FreeBSD repository catalogue...
  pkg: Repository FreeBSD load error: access repo file(/var/db/pkg/repo-FreeBSD.sqlite) failed: No such file or directory
  [folsom] Fetching meta.txz: 100%    944 B   0.9kB/s    00:01
  [folsom] Fetching packagesite.txz: 100%    6 MiB   3.4MB/s    00:02
  Processing entries: 100%
  FreeBSD repository update completed. 32550 packages processed.
  All repositories are up to date.
  Updating database digests format: 100%
  The following 10 package(s) will be affected (of 0 checked):

  New packages to be INSTALLED:
      vim-console: 8.1.0342
      git-lite: 2.19.1
      zsh: 5.6.2
      expat: 2.2.6_1
      curl: 7.61.1
      libnghttp2: 1.33.0
      ca_root_nss: 3.40
      pcre: 8.42
      gettext-runtime: 0.19.8.1_1
      indexinfo: 0.3.1

  Number of packages to be installed: 10

  The process will require 77 MiB more space.
  17 MiB to be downloaded.

  Proceed with this action? [y/N]: y
  [folsom] [1/10] Fetching vim-console-8.1.0342.txz: 100%    5 MiB   5.8MB/s    00:01
  [folsom] [2/10] Fetching git-lite-2.19.1.txz: 100%    4 MiB   2.1MB/s    00:02
  [folsom] [3/10] Fetching zsh-5.6.2.txz: 100%    4 MiB   4.4MB/s    00:01
  [folsom] [4/10] Fetching expat-2.2.6_1.txz: 100%  109 KiB 111.8kB/s    00:01
  [folsom] [5/10] Fetching curl-7.61.1.txz: 100%    1 MiB   1.2MB/s    00:01
  [folsom] [6/10] Fetching libnghttp2-1.33.0.txz: 100%  107 KiB 109.8kB/s    00:01
  [folsom] [7/10] Fetching ca_root_nss-3.40.txz: 100%  287 KiB 294.3kB/s    00:01
  [folsom] [8/10] Fetching pcre-8.42.txz: 100%    1 MiB   1.2MB/s    00:01
  [folsom] [9/10] Fetching gettext-runtime-0.19.8.1_1.txz: 100%  148 KiB 151.3kB/s    00:01
  [folsom] [10/10] Fetching indexinfo-0.3.1.txz: 100%    6 KiB   5.7kB/s    00:01
  Checking integrity... done (0 conflicting)
  [folsom] [1/10] Installing libnghttp2-1.33.0...
  [folsom] [1/10] Extracting libnghttp2-1.33.0: 100%
  [folsom] [2/10] Installing ca_root_nss-3.40...
  [folsom] [2/10] Extracting ca_root_nss-3.40: 100%
  [folsom] [3/10] Installing indexinfo-0.3.1...
  [folsom] [3/10] Extracting indexinfo-0.3.1: 100%
  [folsom] [4/10] Installing expat-2.2.6_1...
  [folsom] [4/10] Extracting expat-2.2.6_1: 100%
  [folsom] [5/10] Installing curl-7.61.1...
  [folsom] [5/10] Extracting curl-7.61.1: 100%
  [folsom] [6/10] Installing pcre-8.42...
  [folsom] [6/10] Extracting pcre-8.42: 100%
  [folsom] [7/10] Installing gettext-runtime-0.19.8.1_1...
  [folsom] [7/10] Extracting gettext-runtime-0.19.8.1_1: 100%
  [folsom] [8/10] Installing vim-console-8.1.0342...
  [folsom] [8/10] Extracting vim-console-8.1.0342: 100%
  [folsom] [9/10] Installing git-lite-2.19.1...
  ===> Creating groups.
  Creating group 'git_daemon' with gid '964'.
  ===> Creating users
  Creating user 'git_daemon' with uid '964'.
  [folsom] [9/10] Extracting git-lite-2.19.1: 100%
  [folsom] [10/10] Installing zsh-5.6.2...
  [folsom] [10/10] Extracting zsh-5.6.2: 100%


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
      nginx-lite: 1.14.0_14,2 -> 1.14.1,2

  Number of packages to be upgraded: 1

  315 KiB to be downloaded.

  Proceed with this action? [y/N]: y
  [nginx] [1/1] Fetching nginx-lite-1.14.1,2.txz: 100%  315 KiB 322.8kB/s    00:01
  Checking integrity... done (0 conflicting)
  [nginx] [1/1] Upgrading nginx-lite from 1.14.0_14,2 to 1.14.1,2...
  ===> Creating groups.
  Using existing group 'www'.
  ===> Creating users
  Using existing user 'www'.
  [nginx] [1/1] Extracting nginx-lite-1.14.1,2: 100%
  You may need to manually remove /usr/local/etc/nginx/nginx.conf if it is no longer needed.
