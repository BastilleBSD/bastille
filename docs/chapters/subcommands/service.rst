service
=======

The ``service`` sub-command allows for managing services within jails. This
allows you to start, stop, restart, and otherwise interact with services running
inside the jail(s).

.. code-block:: shell

  ishmael ~ # bastille service web01 'nginx start'
  ishmael ~ # bastille service db01 'mysql-server restart'
  ishmael ~ # bastille service proxy 'nginx configtest'
  ishmael ~ # bastille service proxy 'nginx enable'
  ishmael ~ # bastille service proxy 'nginx disable'
  ishmael ~ # bastille service proxy 'nginx delete'

.. code-block:: shell

  ishmael ~ # bastille service help
  Usage: bastille service [options(s)] TARGET SERVICE_NAME ACTION
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.
