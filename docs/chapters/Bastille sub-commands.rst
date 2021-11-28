Bastille sub-commands
====================
Before you can begin creating containers, Bastille needs to "bootstrap" a release. Current supported releases are 12.2-RELEASE and 13.0-RELEASE.

Important: If you need ZFS support see the above section BEFORE bootstrapping.

To ``bootstrap`` a release, run the bootstrap sub-command with the release version as the argument.

FreeBSD 12.2-RELEASE
---

.. code-block:: shell

  ishmael ~ # bastille bootstrap 12.2-RELEASE

FreeBSD 13.0-RELEASE
---

.. code-block:: shell

  ishmael ~ # bastille bootstrap 13.0-RELEASE

HardenedBSD 12-STABLE-BUILD-XX
---

.. code-block:: shell

  ishmael ~ # bastille bootstrap 12-STABLE-BUILD-XX

HardenedBSD 13-STABLE-BUILD-XX
---

.. code-block:: shell

  ishmael ~ # bastille bootstrap 13-STABLE-BUILD-XX

>>> ``bastille bootstrap RELEASE`` update to apply updates automatically at bootstrap.

This command will ensure the required directory structures are in place and download the requested release. For each requested release, ``bootstrap`` will download the base.txz. 
If you need more than base (eg; ports, lib32, src) you can configure the ``bastille_bootstrap_archives`` in the configuration file. By default this value is set to "base". Additional components are added, space separated, without file extension.

Bastille will attempt to fetch the required archives if they are not found in the ``cache/$RELEASE`` directory. 
Downloaded artifacts are stored in the ``cache/RELEASE`` directory. "bootstrapped" releases are stored in ``releases/RELEASE``.

Advanced: If you want to create your own custom base.txz, or use an unsupported variant of FreeBSD, drop your own base.txz in ``cache/RELEASE/base.txz`` and ``bastille bootstrap`` will attempt to extract and use it.

The bootstrap subcommand is generally only used once to prepare the system. The other use cases for the bootstrap command are when a new FreeBSD version is released and you want to start building containers on that version, or bootstrapping templates from GitHub or GitLab.

See ``bastille update`` to ensure your bootstrapped releases include the latest patches.

** Ubuntu Linux [new since 0.9] **

The bootstrap process for Linux containers is very different from the BSD process. You will need the package debootstrap and some kernel modules for that. But don't worry, Bastille will do that for you.


.. code-block:: shell

  ishmael ~ # bastille bootstrap focal
  sysrc: unknown variable 'linprocfs_load'
  sysrc: unknown variable 'linsysfs_load'
  sysrc: unknown variable 'tmpfs_load'
  linprocfs_load, linsysfs_load, tmpfs_load not enabled in /boot/loader.conf or linux_enable not active. Should I do that for you?  (N|y)
  #y
  Loading modules
  Persisting modules
  linux_enable:  -> YES
  linprocfs_load:  -> YES
  linsysfs_load:  -> YES
  tmpfs_load:  -> YES
  Debootstrap not found. Should it be installed? (N|y)
  #y
  FreeBSD repository is up to date.
  All repositories are up to date.
  Checking integrity... done (0 conflicting)
  The following 1 package(s) will be affected (of 0 checked):

  New packages to be INSTALLED:
          debootstrap: 1.0.123_4
  [...]

As of 0.9.20210714 Bastille supports Ubuntu 18.04 (bionic) and Ubuntu 20.04 (focal).

bastille create
---------------------------
``bastille create`` uses a bootstrapped release to create a lightweight container system. To create a container simply provide a name, release and a private (rfc1918) IP address. Optionally provide a network interface name to attach the IP at container creation.

 - name
 - release (bootstrapped)
 - ip (ip4 or ip6)
 - interface (optional)

ip4
.. code-block:: shell

  ishmael ~ # bastille create folsom 12.2-RELEASE 10.17.89.10
  Valid: (10.17.89.10).

  NAME: folsom.
  IP: 10.17.89.10.
  RELEASE: 12.2-RELEASE.

  syslogd_flags: -s -> -ss
  sendmail_enable: NO -> NONE
  cron_flags:  -> -J 60

This command will create a 12.2-RELEASE container assigning the 10.17.89.10 ip address to the new system.

ip6
.. code-block:: shell

  ishmael ~ # bastille create folsom 12.2-RELEASE fd35:f1fd:2cb6:6c5c::13
  Valid: (fd35:f1fd:2cb6:6c5c::13).

  NAME: folsom.
  IP: fd35:f1fd:2cb6:6c5c::13
  RELEASE: 12.1-RELEASE.

  syslogd_flags: -s -> -ss
  sendmail_enable: NO -> NONE
  cron_flags:  -> -J 60

This command will create a 12.2-RELEASE container assigning the fd35:f1fd:2cb6:6c5c::13 ip address to the new system.

VNET
.. code-block:: shell

  ishmael ~ # bastille create -V vnetjail 12.2-RELEASE 192.168.87.55/24 em0
  Valid: (192.168.87.55/24).
  Valid: (em0).

  NAME: vnettest0.
  IP: 192.168.87.55/24.
  INTERFACE: em0.
  RELEASE: 12.1-RELEASE.

  syslogd_flags: -s -> -ss
  sendmail_enable: NO -> NONE
  cron_flags:  -> -J 60
  ifconfig_e0b_bastille0_name:  -> vnet0
  ifconfig_vnet0:  -> inet 192.168.87.55/24

This command will create a 12.2-RELEASE container assigning the 192.168.87.55/24 ip address to the new system.

VNET-enabled containers are attached to a virtual bridge interface for connectivity. This bridge interface is defined by the interface argument in the create command (in this case, em0).

VNET also requires a custom ``devfs`` ruleset. Create the file as needed on the host system:

/etc/devfs.rules
.. code-block:: shell

  [bastille_vnet=13]
  add path 'bpf*' unhide

Optionally ``bastille create [ -T | --thick ]`` will create a container with a private base. This is sometimes referred to as a "thick" container (whereas the shared base container is a "thin").

.. code-block:: shell

  ishmael ~ # bastille create -T folsom 12.2-RELEASE 10.17.89.10

Linux
.. code-block:: shell

  ishmael ~ # bastille create folsom focal 10.17.89.10

Systemd is not supported due to the missing boot process.

I recommend using private (rfc1918) ip address ranges for your containers. These ranges include:

 - 10.0.0.0/8
 - 172.16.0.0/12
 - 192.168.0.0/16

If your Bastille host also uses private (rfc1918) addresses, use a different range for your containers. ie; Host uses 192.168.0.0/16, containers use 10.0.0.0/8.

Bastille does its best to validate the submitted ip is valid. I generally use the 10.0.0.0/8 range for containers.

bastille start
---------------------------
To start a containers you can use the ``bastille start`` command.

.. code-block:: shell

  ishmael ~ # bastille start folsom
  [folsom]:
  folsom: created

bastille stop
---------------------------
To stop a containers you can use the ``bastille stop`` command.

.. code-block:: shell

  ishmael ~ # bastille stop folsom
  [folsom]:
  folsom: removed

bastille restart
---------------------------
To restart a containers you can use the ``bastille restart`` command.

.. code-block:: shell

  ishmael ~ # bastille restart folsom
  [folsom]:
  folsom: removed

  [folsom]:
  folsom: created


bastille list
---------------------------
This sub-command will show you the running containers on your system.

.. code-block:: shell

  ishmael ~ # bastille list
   JID             IP Address      Hostname                      Path
   bastion         10.17.89.65      bastion                       /usr/local/bastille/jails/bastion/root
   unbound0        10.17.89.60      unbound0                      /usr/local/bastille/jails/unbound0/root
   unbound1        10.17.89.61      unbound1                      /usr/local/bastille/jails/unbound1/root
   squid           10.17.89.30      squid                         /usr/local/bastille/jails/squid/root
   nginx           10.17.89.45      nginx                         /usr/local/bastille/jails/nginx/root
   folsom          10.17.89.10      folsom                        /usr/local/bastille/jails/folsom/root

You can also list non-running containers with ``bastille list containers``. In the same manner you can list archived ``logs``, downloaded ``templates``, and ``releases`` and ``backups``. Providing the ``-j`` flag to list alone will result in JSON output.

bastille service
---------------------------
To restart services inside a containers you can use the ``bastille service`` command.

.. code-block:: shell

  ishmael ~ # bastille service folsom postfix restart
  [folsom]
  postfix/postfix-script: stopping the Postfix mail system
  postfix/postfix-script: starting the Postfix mail system

bastille cmd
---------------------------
To execute commands within the container you can use ``bastille cmd``.


.. code-block:: shell

  ishmael ~ # bastille cmd folsom ps -auxw
  [folsom]:
  USER   PID %CPU %MEM   VSZ  RSS TT  STAT STARTED    TIME COMMAND
  root 71464  0.0  0.0 14536 2000  -  IsJ   4:52PM 0:00.00 /usr/sbin/syslogd -ss
  root 77447  0.0  0.0 16632 2140  -  SsJ   4:52PM 0:00.00 /usr/sbin/cron -s
  root 80591  0.0  0.0 18784 2340  1  R+J   4:53PM 0:00.00 ps -auxw


bastille pkg
---------------------------
To manage binary packages within the container use ``bastille pkg``.


.. code-block:: shell

  ishmael ~ # bastille pkg folsom install vim-console git-lite zsh
  [folsom]:
  Updating FreeBSD repository catalogue...
  [folsom] Fetching meta.txz: 100%    944 B   0.9kB/s    00:01
  [folsom] Fetching packagesite.txz: 100%    6 MiB   6.6MB/s    00:01
  Processing entries: 100%
  FreeBSD repository update completed. 32617 packages processed.
  All repositories are up to date.
  Updating database digests format: 100%
  The following 10 package(s) will be affected (of 0 checked):

  New packages to be INSTALLED:
  	  vim-console: 8.1.1954
  	  git-lite: 2.23.0
  	  zsh: 5.7.1_1
	  expat: 2.2.8
	  curl: 7.66.0
	  libnghttp2: 1.39.2
	  ca_root_nss: 3.47.1
	  pcre: 8.43_2
	  gettext-runtime: 0.20.1
	  indexinfo: 0.3.1

  Number of packages to be installed: 10

  The process will require 87 MiB more space.
  18 MiB to be downloaded.

  Proceed with this action? [y/N]:
  ...[snip]...


The PKG sub-command can, of course, do more than just ``install``. The expectation is that you can fully leverage the pkg manager. This means, ``install``, ``update``, ``upgrade``, ``audit``, ``clean``, ``autoremove``, etc.


