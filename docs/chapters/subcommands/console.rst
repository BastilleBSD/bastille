console
=======

Launch a login shell into the jail. Default is password-
less root login.

.. code-block:: shell

  ishmael ~ # bastille console folsom
  [folsom]:
  root@folsom:~ #

At this point you are logged in to the jail and have full shell access. The
system is yours to use and/or abuse as you like. Any changes made inside the
jail are limited to the jail.

.. code-block:: shell

  ishmael ~ # bastille console help
  Usage: bastille console [option(s)] TARGET [USER]

      Options:

      -a | --auto           Auto mode. Start/stop jail(s) if required.
      -x | --debug          Enable debug mode.