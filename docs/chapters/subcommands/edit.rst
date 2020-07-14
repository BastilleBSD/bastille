====
edit
====

To edit container configuration use `bastille edit`.

.. code-block:: shell

  ishmael ~ # bastille edit azkaban [filename]

Syntax requires a target an optional filename. By default the file edited will
be `jail.conf`. Other common filenames are `fstab` or `rctl.conf`.

.. code-block:: shell

  Usage: bastille edit TARGET
