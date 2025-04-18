setup
=====

The ``setup`` sub-command attempts to automatically configure a host system for
Bastille containers. This allows you to configure networking, firewall, and storage
options for a Bastille host with one command.

.. code-block:: shell

  ishmael ~ # bastille setup -h        ## display setup help
  ishmael ~ # bastille setup network   ## only configure loopback interface
  ishmael ~ # bastille setup pf        ## only configure default firewall
  ishmael ~ # bastille setup zfs       ## only configure ZFS storage
  ishmael ~ # bastille setup vnet      ## only configure VNET bridge
  ishmael ~ # bastille setup           ## configure all of the above

.. code-block:: shell

  ishmael ~ # bastille setup help
  Usage: bastille setup [pf|network|zfs|vnet]
