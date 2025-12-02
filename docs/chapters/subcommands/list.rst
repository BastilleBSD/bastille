list
====

List jails, ports, releases, templates, logs, limits, exports and imports and
much more managed by bastille. See the ``help`` output below.

Using `bastille list` without args will print all jails with the info we feel is
most important.

Most options can be printed in JSON format by including the ``-j|--json`` flag.
Use ``-p|--pretty`` to print in columns instead of rows.

.. code-block:: shell

  ishmael ~ # bastille list help
  Usage: bastille list [option(s)] [RELEASE (-p)] [all] [backup(s)] [export(s)] [import(s)] [ip(s)] [jail(s)] [limit(s)] [log(s)]
                                                  [path(s)] [port(s)] [prio|priority] [release(s)] [state(s)] [template(s)] [type]
      Options:

      -d | --down                List stopped jails only.
      -j | --json                List jails or sub-arg(s) in json format.
      -p | --pretty              Print JSON in columns. Must be used with -j|--json.
      -u | --up                  List running jails only.
      -x | --debug               Enable debug mode.
