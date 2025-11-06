Configuration
=============

Bastille is configured using a default config file located at
``/usr/local/etc/bastille/bastille.conf``. When first installing bastille, you
should run ``bastille setup``. This will ask if you want to copy the sample
config file to the above location. The defaults are sensible for UFS, but if you
want to use ZFS, you will have to change a few options. See the chapter on ZFS
Support.

The default configuration file is located at
``/usr/local/etc/bastille/bastille.conf.sample``.

Notes
-----

The options here are fairly self-explanitory, but there are some things to note.

* If you use ZFS, DO NOT create the bastille dataset. You must only create the
  parent. Bastille must be allowed to create the ``bastille`` child dataset, or
  you will have issues. So, if you want bastille to live at
  ``zroot/data/bastille`` you should set ``bastille_zfs_zpool`` to ``zroot`` and
  ``bastille_zfs_prefix`` to ``data/bastille`` but you should only create
  ``zroot/data`` before running bastille for the first time.

* Bastille will mount the dataset it creates at ``bastille_prefix`` which
  defaults to ``/usr/local/bastille``. So if you want to navigate to your jails,
  you will use the ``bastille_prefix`` as the location because this is where the
  will be mounted.

Custom Configuration
--------------------

Bastille now supports using a custom config in addition to the default one. This
is nice if you have multiple users, or want to store different
jails at different locations based on your needs.

The customized config file MUST BE PLACED INSIDE THE BASTILLE CONFIG FOLDER at
``/usr/local/etc/bastille`` or it will not work.

Simply copy the default config file and edit it according to your new
environment or user. Then, it can be used in a couple of ways.

1. Run Bastille using ``bastille --config config.conf bootstrap 14.2-RELEASE``
   to bootstrap the release using the new config.

2. As a specific user, export the ``BASTILLE_CONFIG`` variable using ``export
   BASTILLE_CONFIG=config.conf``. This config will then always be used when
   running Bastille with that user. See notes below...

- Exporting the ``BASTILLE_CONFIG`` variable will only export it for the current session. If you want to persist the export, see documentation for the shell that you use.

- If you use sudo, you will need to run it with ``sudo -E bastille bootstrap...`` to preserve your users environment. This can also be persisted by editing the sudoers file.

- If you do set the ``BASTILLE_CONFIG`` variable, you do not need to specify the config file when running Bastille as that specified user.
