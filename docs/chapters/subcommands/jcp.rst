jcp
===

Copy files from jail to jail(s).

.. code-block:: shell

  ishmael ~ # bastille jcp bastion /tmp/resolv.conf-cf ALL /etc/resolv.conf
  [unbound0]:
  /usr/local/bastille/jails/bastion/root/tmp/resolv.conf-cf -> /usr/local/bastille/jails/unbound0/root/etc/resolv.conf
  [unbound1]:
  /usr/local/bastille/jails/bastion/root/tmp/resolv.conf-cf -> /usr/local/bastille/jails/unbound1/root/etc/resolv.conf
  [squid]:
  /usr/local/bastille/jails/bastion/root/tmp/resolv.conf-cf -> /usr/local/bastille/jails/squid/root/etc/resolv.conf
  [nginx]:
  /usr/local/bastille/jails/bastion/root/tmp/resolv.conf-cf -> /usr/local/bastille/jails/nginx/root/etc/resolv.conf
  [folsom]:
  /usr/local/bastille/jails/bastion/root/tmp/resolv.conf-cf -> /usr/local/bastille/jails/folsom/root/etc/resolv.conf

Unless you see errors reported in the output the ``jcp`` was successful.

.. code-block:: shell

  ishmael ~ # bastille jcp help
  Usage: bastille jcp [option(s)] SOURCE_JAIL JAIL_PATH DEST_JAIL JAIL_PATH

      Options:

      -q | --quiet          Suppress output.
      -x | --debug          Enable debug mode.