Monitor
=======

NEW in Bastille version 1.1.20250814

The ``monitor`` sub-command adds, removes, lists and enables/disables monitoring for container services.

.. code-block:: shell

  ishmael ~ # bastille monitor help                            ## display monitor help
  ishmael ~ # bastille monitor TARGET add "service1 service2"  ## add the services "service1" and "service2" to TARGET monitoring
  ishmael ~ # bastille monitor TARGET delete service1          ## delete service "service1" from TARGET monitoring
  ishmael ~ # bastille monitor TARGET list                     ## list services monitored on TARGET
  ishmael ~ # bastille monitor ALL list                        ## list monitored services from ALL containers

  ishmael ~ # bastille monitor -s                              ## return monitoring cronjob status
  ishmael ~ # bastille monitor -e                              ## enable monitoring cronjob
  ishmael ~ # bastille monitor -d                              ## disable monitoring cronjob

.. code-block:: shell

    ishmael ~ # bastille monitor help
    Usage: bastille monitor [option(s)] TARGET [add|delete|list] [service1 service2]

    Options:

    -x | --debug      Enable debug mode.
    -e | --enable     Enable (install) bastille-monitor cronjob. Configurable in bastille.conf.
    -d | --disable    Disable (uninstall) bastille-monitor cronjob.
    -s | --status     Return monitor status (Enabled or Disabled).


Configuration
-------------

The monitor sub-command is configurable via the `bastille.conf` file. See below
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
and provides a self-hosted option (see `sysutils/py-healthchecks`).

Simply configure the `${bastille_monitor_healthchecks}` variable with your Ping
URL and you're done!
