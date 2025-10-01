Bastille 1.x
========
[Bastille](https://bastillebsd.org/) is an open-source system for automating
deployment and management of containerized applications on FreeBSD.

Check the [Bastille Documentation](https://bastille.readthedocs.io/en/latest/)


Potentially breaking changes since 1.0 ⚠️
========================================
Up until version 1.0.20250714, Bastille has handled epairs for -V jails
using the jib script included in FreeBSD installs. However, for -B jails,
Bastille statically assigned an epair to each jail. This means you can only
run one type (-V or -B) of VNET jails on a given system.

Starting with version 1.0.20250714, we are now handling all epairs
dynamically, allowing the use of both types of VNET jails without issue. We
have also selected a naming scheme that will allow for consistency across
these jail types. The naming scheme is as follows:

e0a_jailname and e0b_jailname are the default epair interfaces for every
jail. The a side is on the host, while the b is in the jail. This will
allow better management when trying to figure out which jail a given epair is
linked to. Due to a limitation in how long an interface name can be, Bastille
will truncate "jailname" to avoid errors if it is too long. So,
mylongjailname will be e0a_mylongjxxme and e0b_mylongjxxme. The xx
part is necessary due to another limitation that does not allow dots (.) in
interface names when using the jib script.

If you decide to add an interface using the network sub-command, they will
be named e1a_jailname and e1b_jailname respectively. The number included
will increment by 1 for each interface you add.

Mandatory
---------
We have tried our best to auto-convert each jails jail.conf and rc.conf
to the new syntax (this happens when the jail is stopped). It isn't a huge
change (only a handful of lines), but if you do have an issue please open a
bug report.

After updating, you must restart all your jails (probably one at a time, in
case of issues) to have Bastille convert the jail.conf and rc.conf files.
This simply involves renaming the epairs to the new syntax.

If you have used the network sub-command to add any number of interfaces, you
will have to edit the jail.conf and rc.conf files for each jail to update
the names of the epair interfaces. This is because all epairs will have been
renamed to e0... in both files. For each additional one, simply increment
the number by 1.

Important
---------
Due to the JIB script that gets used when creating VNET jails, you
will face changes with the MAC address if these jails.

If you have any VNET jails (created with -V), the MAC addresses
will change if you did not also use -M when creating them. This
is due to the JIB script generating a MAC based on the jail interface
name.

If you did use -M when creating them, the MAC should stay the same.

Bastille Compared to Other Jail Managers
========================================
See the [comparison table.](COMPARE.md)


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
  bastille [options(s)] command [option(s)] TARGET [args]

Available Commands:
  bootstrap   Bootstrap a release for jail base.
  clone       Clone an existing jail.
  cmd         Execute arbitrary command(s) in targeted jail(s).
  config      Get, set or remove a config value for the targeted jail(s).
  console     Console into a jail.
  convert     Convert thin jail to thick jai. Convert jail to custom release base.
  cp          cp(1) files from host to targeted jail(s).
  create      Create a jail.
  destroy     Destroy a jail or release.
  edit        Edit jail configuration files (advanced).
  export      Export a jail.
  help        Help about any command.
  htop        Interactive process viewer (requires htop).
  import      Import a jail.
  jcp         cp(1) files from a jail to jail(s).
  limits      Apply resources limits to targeted jail(s). See rctl(8) and cpuset(1).
  list        List jails, releases, templates and more...
  migrate     Migrate targeted jail(s) to a remote system.
  mount       Mount a volume inside targeted jail(s).
  network     Add or remove interfaces from targeted jail(s).
  pkg         Manipulate binary packages within targeted jail(s). See pkg(8).
  rcp         cp(1) files from a jail to host.
  rdr         Redirect host port to jail port.
  rename      Rename a jail.
  restart     Restart a running jail.
  service     Manage services within targeted jail(s).
  setup       Attempt to auto-configure network, firewall, storage and more...
  start       Start a stopped jail.
  stop        Stop a running jail.
  sysrc       Safely edit rc files within targeted jail(s).
  tags        Add or remove tags to targeted jail(s).
  template    Apply file templates to targeted jail(s).
  top         Display and update information about the top(1) cpu processes.
  umount      Unmount a volume from targeted jail(s).
  update      Update jail base -pX release.
  upgrade     Upgrade jail release to X.Y-RELEASE.
  verify      Compare release against a "known good" index.
  zfs         Manage (get|set) ZFS attributes on targeted container(s).

Use "bastille -v|--version" for version information.
Use "bastille command -h|--help" for more information about a command.
Use "bastille -c|--config config.conf command" to specify a non-default config file.
```

## 1.x
This document outlines the basic usage of the Bastille container management
framework. This release is still considered beta.

Setup Requirements
==================
Bastille can now (attempt) to configure the networking, firewall and storage
automatically. This feature is new since version 0.10.20231013.

**bastille setup**

```shell
ishmael ~ # bastille setup -h
Usage: bastille setup [-p|pf|firewall] [-l|loopback] [-s|shared] [-z|zfs|storage] [-v|vnet] [-b|bridge]
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
