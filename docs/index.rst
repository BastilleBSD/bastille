Bastille
========

Welcome to the official Bastille documentation. This collection of documents
will outline installation and usage of Bastille.

While reading the documentation and using Bastille, you will find that
sometimes "container" is used, and sometimes "jail" is used.
These are completely interchangeable, but there is some debate as to
which one is more correct. Be that as it may, anytime you read "container"
or "jail", it means a FreeBSD jail.

The latest version of this documentation can always be found at
https://docs.bastillebsd.org.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   chapters/overview/installation
   chapters/overview/getting-started
   chapters/overview/comparing

   chapters/configuration/usage
   chapters/configuration/configuration
   chapters/configuration/startup
   chapters/configuration/targeting
   chapters/configuration/jail-conf

   chapters/releases/bootstrap
   chapters/releases/release-management

   chapters/jails/jail-types
   chapters/jails/jail-management

   chapters/networking/network-modes
   chapters/networking/ip-options
   chapters/networking/nat
   chapters/networking/alias
   chapters/networking/vnet
   chapters/networking/routing
   chapters/networking/vlan
   chapters/networking/scenarios
   chapters/networking/netgraph
   chapters/networking/limitations

   chapters/updating/updating
   chapters/updating/upgrading
   chapters/updating/limitations

   chapters/migration/bastille
   chapters/migration/iocage

   chapters/templates/overview
   chapters/templates/bootstrap
   chapters/templates/hooks
   chapters/templates/creating-templates
   chapters/templates/applying-templates
   chapters/templates/limitations

   chapters/zfs/zfs-support
   chapters/zfs/jailing-a-dataset

   chapters/advanced/centralized-assets
   chapters/advanced/custom-configuration
   chapters/advanced/plugins

   chapters/subcommands/index

   copyright

Note: this documentation is included with the source code in ``docs``.
