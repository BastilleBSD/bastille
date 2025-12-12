htop
====

This command runs ``htop`` in the targeted jail. Requires htop to be installed
in the jail.

.. image:: ../../images/htop.png
    :align: center
    :alt: bastille htop container

.. code-block:: shell

  ishmael ~ # bastille htop help
  Usage: bastille htop [options(s)] TARGET

      Options:

      -a | --auto      Auto mode. Start/stop jail(s) if required.
      -x | --debug     Enable debug mode.