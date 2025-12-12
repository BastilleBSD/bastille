monitor
=======

NEW in Bastille version 1.1.20250814

The ``monitor`` sub-command adds, removes, lists and enables/disables monitoring for container services.


Managing Bastille Monitor
-------------------------

To enable Bastille monitoring, run ``bastille monitor enable``.

To disable Bastille monitoring, run ``bastille monitor disable``.

We can always check if Bastille monitoring is active with ``bastille monitor status``.


Managing Services
-----------------

Bastille Monitor will attempt to monitor any services defined for any given container. If the service is
stopped, Bastille will attempt to restart it. Everything is logged in ``${bastille_monitor_logfile}``.

To have Bastille monitor a service, run ``bastille monitor TARGET add SERVICE``. The ``SERVICE`` arg can also be a
comma-separated list of services such as ``bastille monitor TARGET add SERVICE1,SERVICE2``.

To remove a service from monitoring, we can run ``bastille monitor TARGET delete SERVICE``. These can also be a
comma-separated list.

To show all services that Bastille is monitoring, run ``bastille monitor TARGET list``.

To list all jails that have a selected service defined for monitoring, run ``bastille monitor TARGET list SERVICE``.
This option only accepts a single ``SERVICE``, and cannot be a comma-separated list.

If you run ``bastille monitor TARGET``, without any args or actions, Bastille will run through the process of
checking the status of each defined service, and attempt to start any that are stopped.

Services can also be manually added or removed by editing the ``monitor`` file inside the jail directory, but
is not recommended unless you are an advanced user.


Configuration
-------------

The monitor sub-command is configurable via the ``bastille.conf`` file. See below
for configuration defaults:

.. code-block:: shell

  bastille_monitor_cron_path="/usr/local/etc/cron.d/bastille-monitor"
  bastille_monitor_cron="*/5 * * * * root /usr/local/bin/bastille monitor ALL >/dev/null 2&>1"
  bastille_monitor_logfile="${bastille_logsdir}/monitor.log"
  bastille_monitor_healthchecks=""


Alerting modules
----------------

The first alerting module to be supported is Health Checks
(https://healthchecks.io), which is both a free SaaS service (up to 20 checks)
and provides a self-hosted option (see ``sysutils/py-healthchecks``).

Simply configure the ``${bastille_monitor_healthchecks}`` variable with your Ping
URL and you're done!


Help
----

.. code-block:: shell

    ishmael ~ # bastille monitor help
    Usage: bastille monitor [option(s)] enable|disable|status
                                        TARGET add|delete|list service1,service2
                                        TARGET list [service]
                                        TARGET

      Options:

      -x | --debug      Enable debug mode.
