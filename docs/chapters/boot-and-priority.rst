Boot and Priority
=================

Boot
----

The boot setting control whether a jail will be started on system startup if you have enabled bastille
with ``sysrc bastille_enable=YES``. You can also use ``bastille start -b TARGET`` to respect this boot setting.
If it is off, the jail(s) will not be started if ``-b`` is used with ``start/stop/restart`` or on system
startup. Jails will still shut down on system shutdown, regardless of this setting.

When jails are created with Bastille, the boot setting is set to ``on`` by default. This can be overridden using
the ``--no-boot`` flag. See ``bastille create --no-boot TARGET...``.

This value can also be changed using ``bastille config TARGET boot [on|off]``.

This value will be shown using ``bastille list all``.

Priority
--------

The priority value determines in what order commands are executed. This also controls in what order jails are started
and stopped. 

When jails are created with Bastille, this value defaults to ``99``, but can be overridden with ``-p|--priority VALUE`` on
creation. See ``bastille create -p 90 TARGET...``.

This value can also be changed using ``bastille config TARGET priority VALUE``.

This value will be shown using ``bastille list all``.
