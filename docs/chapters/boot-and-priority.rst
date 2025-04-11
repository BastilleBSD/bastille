Boot and Priority
=================

Boot
----

The boot setting controls whether a jail will be started on system startup. If you have enabled bastille
with ``sysrc bastille_enable=YES``, all jails with ``boot=on`` will start on system startup. Any jail(s)
with ``boot=off`` will not be started on system startup.

You can also use ``bastille start --boot TARGET`` to make Bastille respect the boot setting. If ``-b|--boot`` is not
used, the targeted jail(s) will start, regardless of the boot setting.

Jails will still shut down on system shutdown, regardless of this setting.

The ``-b|--boot`` can also be used with the ``stop`` command. Any jails with ``boot=off`` will
not be touched if ``stop`` is called with ``-b|--boot``. Same goes for the ``restart`` command.

When jails are created with Bastille, the boot setting is set to ``on`` by default. This can be overridden using
the ``--no-boot`` flag. See ``bastille create --no-boot TARGET...``.

This value can be changed using ``bastille config TARGET boot [on|off]``.

This value will be shown using ``bastille list all``.

Priority
--------

The priority value determines in what order commands are executed if multiple jails are targetted. This also controls
in what order jails are started and stopped on system startup and shutdown. This requires Bastille to be enabled
with ``sysrc bastille_enable=YES``. Jails will start in order starting at the lowest value, and will stop in order starting
at the highest value. So, jails with a priority value of 1 will start first, and stop last.

When jails are created with Bastille, this value defaults to ``99``, but can be overridden with ``-p|--priority VALUE`` on
creation. See ``bastille create --priority 90 TARGET...``.

This value can be changed using ``bastille config TARGET priority VALUE``.

This value will be shown using ``bastille list all``.
