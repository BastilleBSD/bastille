<p align="center">
    <img src="docs/images/bastille.svg" width="60%" height="auto" />
</p>

----


Table of Contents
=================

* [Table of Contents](#table-of-contents)
* [Bastille](#bastille)
   * [Installation](#installation)
   * [Usage](#usage)
   * [Getting Started](#getting-started)
   * [Documentation](#documentation)
   * [Comparing](#comparing)
   * [Breaking Changes](#breaking-changes)
   * [Support](#support)


# Bastille

Bastille is an open-source system for automating
deployment and management of containerized applications on FreeBSD.

[Official BastilleBSD Website](https://bastillebsd.org)

## Installation

Bastille is available for installation from the official FreeBSD ports tree.

**pkg**
```shell
pkg install bastille
```

**ports**
```shell
git clone https://git.freebsd.org/ports.git --depth 1 /usr/ports
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
1.2.1.251203) you will need to update your bastille.conf

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

## Support

If you've found a bug in Bastille, please submit it to the [Bastille Issue
Tracker](https://github.com/bastillebsd/bastille/issues/new)
