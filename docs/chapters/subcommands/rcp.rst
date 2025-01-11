===
rcp
===

This command allows copying files from a single jail to the host.

.. code-block:: shell

  ishmael ~ # bastille rcp bastion /tmp/myfile /temp
  [bastion]:
  /usr/local/bastille/jails/bastion/root/tmp/myfile -> /temp/myfile

Unless you see errors reported in the output the `rcp` was successful.

.. code-block:: shell

  ishmael ~ # bastille rcp help
  Usage: bastille rcp [option(s)] TARGET JAIL_PATH HOST_PATH
    Options:

    -q | --quiet          Suppress output.
    -x | --debug          Enable debug mode.
