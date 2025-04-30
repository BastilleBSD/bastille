list
====

List jails, ports, releases, templates, logs, limits, exports and imports and much more
managed by bastille.

Using `bastille list` without args will print with all the info we feel is most important.

Most options can be printed in JSON format by including the `-j|--json` flag.

.. code-block:: shell

  ishmael ~ # bastille list help
  Usage: bastille list [option(s)] [RELEASE (-p)] [all] [backup(s)] [export(s)] [import(s)] [ip(s)] [jail(s)] [limit(s)] [log(s)]
                                                  [path(s)] [port(s)] [prio|priority] [state(s)] [template(s)]
    Options:
    
    -j | --json           List jails or sub-arg(s) in json format.
    -x | --debug          Enable debug mode.
