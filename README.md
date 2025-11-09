Bastille 1.x
========
[Bastille](https://bastillebsd.org/) is an open-source system for automating
deployment and management of containerized applications on FreeBSD.


Table of Contents
=================

* [Table of Contents](#table-of-contents)
* [Bastille](#bastille)
   * [Installation](#installation)
   * [Usage](#usage)
   * [Getting Started](#getting-started)
   * [Documentation](#documentation)
   * [Comparing](#comparing)


# Bastille

[Bastille](https://bastillebsd.org/) is an open-source system for automating
deployment and management of containerized applications on FreeBSD.

## Installation

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

### Upgrading

When upgrading from a previous version of bastille (e.g. 0.10.20230714 to
0.10.20231013) you will need to update your bastille.conf

Be sure to read the [Breaking Changes](#breaking-changes) below.

```shell
cd /usr/local/etc/bastille
diff -u bastille.conf bastille.conf.sample
```

Merge the lines that are present in the new bastille.conf.sample into
your bastille.conf

## Usage

See [Usage](https://bastille.readthedocs.io/en/latest/chapters/usage.html)

## Getting Started

See [Getting Started](https://bastille.readthedocs.io/en/latest/chapters/getting-started.html)

## Documentation

See [Documentation](https://bastille.readthedocs.io/en/latest/)

## Comparing

See [Comparing](https://bastille.readthedocs.io/en/latest/chapters/comparing.html)

## Breaking Changes ⚠
======================

### Version 1.x

Up until version 1.0.20250714, Bastille has handled epairs for -V jails
using the jib script included in FreeBSD installs. However, for -B jails,
Bastille statically assigned an epair to each jail. This means you can only
run one type (-V or -B) of VNET jails on a given system.

Starting with version 1.0.20250714, we are now handling all epairs
dynamically, allowing the use of both types of VNET jails without issue. We
have also selected a naming scheme that will allow for consistency across
these jail types. The naming scheme is as follows:

`e0a_jailname` and `e0b_jailname` are the default epair interfaces for every
jail. The `e0a` side is on the host, while the `e0b` is in the jail. This will
allow better management when trying to figure out which jail a given epair is
linked to. Due to a limitations in how long an interface name can be, Bastille
will name any epairs whose jail names exceed the maximum length, to
`e0b_bastille1` and `e0b_bastille1` with the `1` incrementing by 1 for
each new epair. So, mylongjailname will be `e0a_bastille2` and `e0b_bastille2`.

If you decide to add an interface using the network sub-command, they will
be named `e1a_jailname` and `e1b_jailname` respectively. The number included
in the prefix `eXa_` will increment by 1 for each interface you add.

### Mandatory

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

### Important Limitations

Due to the JIB script that gets used when creating VNET jails, you
will face changes with the MAC address if these jails.

If you have any VNET jails (created with -V), the MAC addresses
will change if you did not also use -M when creating them. This
is due to the JIB script generating a MAC based on the jail interface
name.

If you did use -M when creating them, the MAC should stay the same.

### Support

If you've found a bug in Bastille, please submit it to the [Bastille Issue
Tracker](https://github.com/bastillebsd/bastille/issues/new)
