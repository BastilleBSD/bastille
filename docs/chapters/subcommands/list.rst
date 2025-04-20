list
====

List jails, ports, releases, templates, logs, limits, exports and imports
managed by bastille.

.. code-block:: shell

  ishmael ~ # bastille list help
  Usage: bastille list [option(s)] [-j|-a] [RELEASE (-p)|template|jails|logs|limits|imports|exports|backups]
    Options:
    
    -a | --all            List all jails, running and stopped, in BastilleBSD format.
    -j | --json           List jails in json format.
    -x | --debug          Enable debug mode.

