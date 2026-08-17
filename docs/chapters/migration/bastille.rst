Migration
=========

Bastille
--------

Bastille supports migrations to a remote system using the ``migrate`` subcommand.

Prerequisites
^^^^^^^^^^^^^

There are a couple of things that need to be in place before running the
``migrate`` command.

First, you must have bastille configured both locally and remotely to use the
same filesystem configuration. ZFS on both, or UFS on both.

Second, you must create a user on the remote system that will be used to migrate
the jail. The user must be able to log in via SSH using either key-based
authentication, or password based authentication.
The user also needs ``sudo`` permissions on the remote system. This user should
then be given as the ``USER`` arg in the ``migrate`` command.

If you don't want to use ``sudo``, we support using ``doas`` as the super-user
command. Simply set ``--doas`` as one of the options when running the ``migrate`` command.

If you are using key-based auth, the keys should be stored in the default
location at ``$HOME/.ssh/id_rsa``, where ``$HOME`` is the users home directory.
This is the default location for ssh keys, and where Bastille will try to load
them from.

If you want to use password based authentication, simply run
``bastille migrate -p TARGET USER@HOST``. This will prompt you to enter the
password for the remote system, which Bastille will then use during the migration
process.

Migrating a Bastille Jail
^^^^^^^^^^^^^^^^^^^^^^^^^

To migrate a jail (or multiple jails) we can simply run
``bastille migrate TARGET USER@HOST``. This will export the jail(s), send them
to the remote system, and import them.

The ``migrate`` sub-command includes the ``-a|--auto`` option, which will
auto-stop the old jail, migrate it, and attempt to start the migrated jail on
the remote system after importing it. See the warning below about auto-starting
the migrated jail.

WARNING: Every system is unique, has different interfaces, bridges, and network
configurations. It is possible, with the right configuration, for jails to start
and work normally. But for some systems, it will be necessary to edit the
``jail.conf`` file of the migrated jail to get it working properly.

Using ``-l|--live`` mode (ZFS only) will leave the local jail running, and the
remote jail stopped.

Using ``-a|--auto`` mode will stop the local jail, and start the remote jail.

Using the ``-l|--live`` and ``-a|--auto`` options together will migrate the jail
while it is running, then stop the local jail, and start the remote jail.

You can optionally set ``-d|--destroy`` to have Bastille destroy the old jail on
completion.

You can also set ``-b|--backup`` to retain the archives remotely. They will be
copied into ``${bastille_backupsdir}``.