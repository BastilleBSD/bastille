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


