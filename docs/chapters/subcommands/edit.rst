edit
====

Edit jail config files.

.. code-block:: shell

  ishmael ~ # bastille edit azkaban [FILE]

Syntax requires a target an optional filename. By default the file edited will
be ``jail.conf``. Other common filenames are ``fstab`` or ``rctl.conf``.

.. code-block:: shell

  ishmael ~ # bastille edit help
  Usage: bastille edit [option(s)] TARGET [FILE]

      Options:

      -x | --debug          Enable debug mode.