edit
====

To edit a jails configuration, use ``bastille edit TARGET``.

.. code-block:: shell

  ishmael ~ # bastille edit azkaban [filename]

Syntax requires a target an optional filename. By default the file edited will
be ``jail.conf``. Other common filenames are ``fstab`` or ``rctl.conf``.

.. code-block:: shell

  ishmael ~ # bastille edit help
  Usage: bastille edit [option(s)] TARGET [filename]
    Options:

    -x | --debug          Enable debug mode.
