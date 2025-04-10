rcp
===

This command allows copying files from jail to host.

.. code-block:: shell

  ishmael ~ # bastille rcp bastion /test/testfile.txt /tmp/testfile.txt
  [bastion]:
  /usr/local/bastille/jails/bastion/root/test/testfile.txt -> /tmp/testfile.txt

Unless you see errors reported in the output the ``rcp`` was successful.

.. code-block:: shell

  ishmael ~ # bastille rcp help
  Usage: bastille rcp [option(s)] TARGET JAIL_PATH HOST_PATH
    Options:

    -q | --quiet          Suppress output.
    -x | --debug          Enable debug mode.
