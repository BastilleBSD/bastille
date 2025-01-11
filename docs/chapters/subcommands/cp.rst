==
cp
==

This command allows efficiently copying files from host to container(s).

.. code-block:: shell

  ishmael ~ # bastille cp ALL /tmp/resolv.conf-cf /etc/resolv.conf
  [bastion]:
  /tmp/resolv.conf-cf -> /usr/local/bastille/jails/bastion/root/etc/resolv.conf
  [unbound0]:
  /tmp/resolv.conf-cf -> /usr/local/bastille/jails/unbound0/root/etc/resolv.conf
  [unbound1]:
  /tmp/resolv.conf-cf -> /usr/local/bastille/jails/unbound1/root/etc/resolv.conf
  [squid]:
  /tmp/resolv.conf-cf -> /usr/local/bastille/jails/squid/root/etc/resolv.conf
  [nginx]:
  /tmp/resolv.conf-cf -> /usr/local/bastille/jails/nginx/root/etc/resolv.conf
  [folsom]:
  /tmp/resolv.conf-cf -> /usr/local/bastille/jails/folsom/root/etc/resolv.conf

Unless you see errors reported in the output the `cp` was successful.

.. code-block:: shell

  ishmael ~ # bastille cp help
  Usage: bastille cp [option(s)] TARGET HOST_PATH JAIL_PATH
    Options:

    -q | --quiet          Suppress output.
    -x | --debug          Enable debug mode.
