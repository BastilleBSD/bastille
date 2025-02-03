=======
console
=======

This sub-command launches a login shell into the container. Default is password-less root login.

.. code-block:: shell

  ishmael ~ # bastille console folsom
  [folsom]:
  root@folsom:~ #

TARGET can also be a running jails JID value.

.. code-block:: shell

  ishmael ~ # bastille list
   JID  IP Address      Hostname                      Path
     1  10.1.2.3        ishmael                       /usr/local/bastille/jails/ishmael/root
  ishmael ~ # bastille console 1
  [ishmael]:
  root@ishmael:~ #

At this point you are logged in to the container and have full shell access.  The
system is yours to use and/or abuse as you like. Any changes made inside the
container are limited to the container.

.. code-block:: shell

  "Usage: bastille console [option(s)] TARGET [user]"
  Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.
