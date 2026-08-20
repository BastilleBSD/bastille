Jail Types
==========

A jail is an isolated, virtualized environment that allows for the isolation
and control of network resources for processes running within it. FreeBSD has had
jails for a very long time, even before Linux containers.

There are a few different types of jails that Bastille can create for you. We will
go through a basic outline of each one.

Thin Jail
---------

A thin jail is the default jail type for Bastille. If no options are given along
with the ``bastille create`` command, Bastille will create a thin jail.

Thin jails are called thin because most of the filesystem is mounted into the jail
from the release. This mainly includes sytem binaries, files and folders. User generated
binaries, files and folders will stay confined to the jail.

These system files are mounted read-only, so the jail is highly secure by default. You still get the full
FreeBSD base, but system files are all mounted read-only. This also means the jail is
very lightweight compared to a thick jail.

Another important thing to note about thin jails is that the release base will be shared
by all jails created using that specific release base.

When updating this release base, all jails bound to it will also be updated. After updating
a release that has child jails, it might be necessary to run ``etcupdate`` inside the jail.
See :doc:`/chapters/subcommands/etcupdate`.

A thin jail is created when no other options are specifed on jail creation.

Thick Jail
----------

A thick jail is a complete copy of a given release. All files inside stay confined to the jail, and
it does not share a release base with other jails. Once you create a thick jail, it remains
completely independant of the release it was created from.

Because a thick jail is a complete copy of a release, it consumes the same amount of space as the
release.

One of the main reasons people choose thick jails is because of their complete isolation. It is the
type of jail that is most similar to a virtual machine.

To create a thick jail, use the ``-T|--thick`` option when creating a jail.

Clone Jail
----------

A clone jail is similar to a thin jail, but is only available when usin ZFS. It uses the ``zfs clone``
command to essentially create a zfs snapshot of a given release. This also means that the only space it
consumes is the changes you make to the jail.

To create a clone jail, use the ``-C|--clone`` option when creating a jail.

Empty Jail
----------

An empty jail is a Batille specific jail, which is simply a jail path without a release. This is
for advanced use cases, and should not be used unles you know what you are doing.

To create an empty jail, use the ``-E|--empty`` option when creating a jail.

Linux Jail
----------

A Linux jail is basically a jail that contains a Linux distribution.
See :doc:`/chapters/releases/bootstrap` to learn how to bootstrap a Linux distribution.

These jails allow you to run Linux inside them, and install Linux programs. They do not support
VNET, or updating and upgrading. This has to be done inside the jail using Linux specific commands.
Linux jails are thick jails, and don't support the thin jail feature.

Note also that Linux jails are an experimental feature.

To create a linux jail, use the ``-C|--linux`` option when creating a jail.