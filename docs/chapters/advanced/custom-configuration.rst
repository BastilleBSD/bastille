Custom Configuration
--------------------

Bastille supports using a custom config in addition to the default one. This
is nice if you have multiple users, or want to store different
jails at different locations based on your needs.

The customized config file MUST BE PLACED INSIDE THE BASTILLE CONFIG FOLDER at
``/usr/local/etc/bastille`` or it will not work.

Simply copy the default config file and edit it according to your new
environment or user. Then, it can be used in a couple of ways:

1. Run Bastille using ``bastille --config config.conf bootstrap 14.2-RELEASE``
   to bootstrap the release using the new config.

2. As a specific user, export the ``BASTILLE_CONFIG`` variable using ``export
   BASTILLE_CONFIG=config.conf``. This config will then always be used when
   running Bastille with that user. See notes below...

- Exporting the ``BASTILLE_CONFIG`` variable will only export it for the current session. If you want to persist the export, see documentation for the shell that you use.

- If you use sudo, you will need to run it with ``sudo -E bastille bootstrap...`` to preserve your users environment. This can also be persisted by editing the sudoers file.

- If you do set the ``BASTILLE_CONFIG`` variable, you do not need to specify the config file when running Bastille as that specified user.
