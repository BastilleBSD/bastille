Startup Configuration
=====================

Bastille can start jails on system startup, and stop them on system shutdown. To enable this functionality, we
must first enable Bastille as a service using ``sysrc bastille_enable=YES``. Once you reboot your host, all jails
with ``boot=on`` will be started when the host boots.

If you have certain jails that must be started before other jails, you can use the priority option. Jails will start
in order starting at the lowest value, and will stop in order starting at the highest value. So, jails with a priority
value of 1 will start first, and stop last.

See the chapter on targeting for more info.

Boot
----

The boot setting controls whether a jail will be started on system startup. If you have enabled bastille
with ``sysrc bastille_enable=YES``, all jails with ``boot=on`` will start on system startup. Any jail(s)
with ``boot=off`` will not be started on system startup.

By default, when jails are created with Bastille, the boot setting is set to ``on`` by default. This can be overridden using
the ``--no-boot`` flag. See ``bastille create --no-boot TARGET...``.

You can also use ``bastille start --boot TARGET`` to make Bastille respect the boot setting. If ``-b|--boot`` is not
used, the targeted jail(s) will start, regardless of the boot setting.

Jails will still shut down on system shutdown, regardless of this setting.

The ``-b|--boot`` can also be used with the ``stop`` command. Any jails with ``boot=off`` will
not be touched if ``stop`` is called with ``-b|--boot``. Same goes for the ``restart`` command.

This value can be changed using ``bastille config TARGET boot [on|off]``.

This value will be shown using ``bastille list all``.

Startup Delay
-------------

Sometimes it is necessary to let a jail start fully before continuing to the next jail.

We can do this with another sysrc value called ``bastille_startup_delay``. Setting ``bastille_startup_delay=5`` will
tell Bastille to wait 5 seconds between starting each jail.

You can also use ``bastille start -d|--delay 5 all`` or ``bastille restart -d|--delay 5 all`` to achieve the same thing.