Bastille
========
[Bastille](https://bastillebsd.org/) is an open-source system for automating
deployment and management of containerized applications on FreeBSD.

[Bastille Documentation](https://bastille.readthedocs.io/en/latest/)

Installation
============
Bastille is available for installation from the official FreeBSD ports tree.

**pkg**
```shell
pkg install bastille
```

**ports**
```shell
portsnap fetch auto
make -C /usr/ports/sysutils/bastille install clean
```

**Git** (bleeding edge / unstable -- primarily for developers)
```shell
git clone https://github.com/bastillebsd/bastille.git
cd bastille
make install
```

**enable at boot**
```shell
sysrc bastille_enable=YES
sysrc bastille_rcorder=YES
```

Upgrading from a previous version
---------------------------------
When upgrading from a previous version of bastille (e.g. 0.10.20230714 to 
0.10.20231013) you will need to update your bastille.conf

```shell
cd /usr/local/etc/bastille
diff -u bastille.conf bastille.conf.sample
```

Merge the lines that are present in the new bastille.conf.sample into
your bastille.conf

Basic Usage
-----------
```shell
Bastille is an open-source system for automating deployment and management of
containerized applications on FreeBSD.

Usage:
  bastille command TARGET [args]

Available Commands:
  bootstrap   Bootstrap a FreeBSD release for container base.
  clone       Clone an existing container.
  cmd         Execute arbitrary command on targeted container(s).
  config      Get or set a config value for the targeted container(s).
  console     Console into a running container.
  convert     Convert a Thin container into a Thick container.
  cp          cp(1) files from host to targeted container(s).
  create      Create a new thin container or a thick container if -T|--thick option specified.
  destroy     Destroy a stopped container or a FreeBSD release.
  edit        Edit container configuration files (advanced).
  export      Exports a specified container.
  help        Help about any command.
  htop        Interactive process viewer (requires htop).
  import      Import a specified container.
  limits      Apply resources limits to targeted container(s). See rctl(8).
  list        List containers (running and stopped).
  mount       Mount a volume inside the targeted container(s).
  pkg         Manipulate binary packages within targeted container(s). See pkg(8).
  rdr         Redirect host port to container port.
  rcp         reverse cp(1) files from a single container to the host.
  rename      Rename a container.
  restart     Restart a running container.
  service     Manage services within targeted container(s).
  setup       Attempt to auto-configure network, firewall and storage on new installs.
  start       Start a stopped container.
  stop        Stop a running container.
  sysrc       Safely edit rc files within targeted container(s).
  tags        Add or remove tags to targeted container(s).
  template    Apply file templates to targeted container(s).
  top         Display and update information about the top(1) cpu processes.
  umount      Unmount a volume from within the targeted container(s).
  update      Update container base -pX release.
  upgrade     Upgrade container release to X.Y-RELEASE.
  verify      Compare release against a "known good" index.
  zfs         Manage (get|set) ZFS attributes on targeted container(s).

Use "bastille -v|--version" for version information.
Use "bastille command -h|--help" for more information about a command.

```

## 0.10-beta
This document outlines the basic usage of the Bastille container management
framework. This release is still considered beta.

Setup Requirements
==================
Bastille can now (attempt) to configure the networking, firewall and storage
automatically. This feature is new since version 0.10.20231013.

**bastille setup**

```shell
ishmael ~ # bastille setup -h
ishmael ~ # Usage: bastille setup [pf|bastille0|zfs|vnet]
```

On fresh installations it is likely safe to run `bastille setup` with no
arguments. This will configure the firewall, the loopback interface and attempt
to determine ZFS vs UFS storage.

If you have an existing firewall, or customized network design, you may want to
run individual options; eg `bastille setup zfs` or `bastille setup vnet`.

Note: The `bastille setup` command can configure and enable PF but it does not
automatically reload the firewall. You will still need to manually `service pf
start`.  At that point you'll likely be disconnected if configuring a remote
host. Simply reconnect the ssh session and continue.

This step only needs to be done once in order to prepare the host.

Example (create, start, console)
================================
This example creates, starts and consoles into the container.

```shell
ishmael ~ # bastille create alcatraz 14.0-RELEASE 10.17.89.10/24
```

```shell
ishmael ~ # bastille start alcatraz
[alcatraz]:
alcatraz: created
```

```shell
ishmael ~ # bastille console alcatraz
[alcatraz]:
FreeBSD 14.0-RELEASE GENERIC

Welcome to FreeBSD!

Release Notes, Errata: https://www.FreeBSD.org/releases/
Security Advisories:   https://www.FreeBSD.org/security/
FreeBSD Handbook:      https://www.FreeBSD.org/handbook/
FreeBSD FAQ:           https://www.FreeBSD.org/faq/
Questions List:        https://www.FreeBSD.org/lists/questions/
FreeBSD Forums:        https://forums.FreeBSD.org/

Documents installed with the system are in the /usr/local/share/doc/freebsd/
directory, or can be installed later with:  pkg install en-freebsd-doc
For other languages, replace "en" with a language code like de or fr.

Show the version of FreeBSD installed:  freebsd-version ; uname -a
Please include that output and any error messages when posting questions.
Introduction to manual pages:  man man
FreeBSD directory layout:      man hier

To change this login announcement, see motd(5).
root@alcatraz:~ #
```

```shell
root@alcatraz:~ # ps -auxw
USER   PID %CPU %MEM  VSZ  RSS TT  STAT STARTED    TIME COMMAND
root 83222  0.0  0.0 6412 2492  -  IsJ  02:21   0:00.00 /usr/sbin/syslogd -ss
root 88531  0.0  0.0 6464 2508  -  SsJ  02:21   0:00.01 /usr/sbin/cron -s
root  6587  0.0  0.0 6912 2788  3  R+J  02:42   0:00.00 ps -auxw
root 92441  0.0  0.0 6952 3024  3  IJ   02:21   0:00.00 login [pam] (login)
root 92565  0.0  0.0 7412 3756  3  SJ   02:21   0:00.01 -csh (csh)
root@alcatraz:~ #
```

Community Support
=================
If you've found a bug in Bastille, please submit it to the [Bastille Issue
Tracker](https://github.com/bastillebsd/bastille/issues/new).
