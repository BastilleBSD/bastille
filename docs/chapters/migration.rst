Migration
=========

Bastille
--------

Bastille supports migrations to a remote system using the ``migrate`` subcommand.

Prerequisites
^^^^^^^^^^^^^

There are a couple of things that need to be in place before running the ``migrate`` command.

First, you must have bastille configured both locally and remotely to use the same filesystem
configuration. ZFS on both, or UFS on both.

Second, we need a user on the remote system that has key-based authentication set up. Bastille
does not support password-based authentication. This also implies that SSH is working on the
remote system. This user also needs ``sudo`` permissions on the remote system.

Third, if updating from a previous version, please make sure to ``diff`` your ``bastille.conf``
file, as the ``migrate`` sub-command adds a new variable called ``bastille_migratedir``.

Migration
^^^^^^^^^

To migrate a jail (or multiple jails) we can simply run
``bastille migrate TARGET USER HOST``. This will export the jail(s), send them to the
remote system, and import them.

The ``migrate`` sub-command includes the ``-a|--auto`` option, which will auto-stop the old jail,
migrate it, and attempt to start the migrated jail on the remote system after importing it. See the
warning below about auto-starting the migrated jail.

WARNING: Every system is unique, has different interfaces, bridges, and network configurations.
It is possible, with the right configuration, for jails to start and work normally. But for some
systems, it will be necessary to edit the ``jail.conf`` file of the migrated jail to get it working
properly.

You can optionally set ``-d|--destroy`` to have Bastille destroy the old jail on completion.

iocage
------

Stop the running jail and export it:

.. code-block:: shell

     iocage stop jailname
     iocage export jailname

Move the backup files (.zip and .sha256) into Bastille backup dir (default:
/usr/local/bastille/backups/):

.. code-block:: shell

     mv /iocage/images/jailname_$(date +%F).* /usr/local/bastille/backups/

for remote systems you can use rsync:

.. code-block:: shell

     rsync -avh /iocage/images/jailname_$(date +%F).* root@10.0.1.10:/usr/local/bastille/backups/

     
Import the iocage backup file (use zip file name)

.. code-block:: shell

     bastille import jailname_$(date +%F).zip

Bastille will attempt to configure your interface and IP from the
``config.json`` file, but if you have issues you can configure it manully.

.. code-block:: shell

  bastille edit jailname
  ip4.addr = bastille0|192.168.0.1/24;

You can use your primary network interface instead of the virtual ``bastille0``
interface as well if you know what you’re doing.
