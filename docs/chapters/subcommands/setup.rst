setup
=====

The ``setup`` sub-command attempts to automatically configure a host system for
Bastille jails. This allows you to configure networking, firewall, storage, vnet
and bridge options for a Bastille host with one command.

Options
-------

Below is a list of available options that can be used with the ``setup`` command.

.. code-block:: shell

  ishmael ~ # bastille setup -h
  Usage: bastille setup [option(s)] [bridge]
                                    [filesystem]
                                    [loopback]
                                    [pf|firewall]
                                    [shared]
                                    [vnet]
                                    [storage]
	
    Options:

    -y | --yes             Assume always yes on prompts.
    -x | --debug           Enable debug mode.

The ``loopback`` option will configure a loopback interface called ``bastille0`` that
will be used as a default when not specifying an interface with the ``create`` command.

The ``shared`` option will configure the interface you choose to also be used as the default
when not specifying an interface with the ``create`` command.

Please note. You CANNOT run both a loopback and a shared interface with Bastille. Only one
should be configured. If you configure one, it will disable the other.

The ``loopback`` option is the default, and is enough for most use cases. It is simply an ``lo`` interface
that jails will get linked to on creation. It is not attached to any specific interface. This is the simplest
networking option. The ``loopback`` and ``shared`` options are only for cases where the ``interface``
is not specified during the ``create`` command. If an interface is specified, these options have no effect. 
Instead, the specified interface will be used.

The ``filesystem`` option is to ensure the proper datasets/directories are in place
for using Bastille. This should only have to be run once on a new system.

The ``shared`` option is for cases where you want an actual interface to use with bastille as
opposed to a loopback. Jails will be linked to the shared interface on creation.

The ``pf|firewall`` option will configure the pf firewall by enabling the service and creating the
default ``pf.conf`` file. Once this is done, you can use the ``rdr`` command to forward traffic into
a jail.

The ``storage`` option will attempt to configure a pool and dataset for Bastille, but only
if ZFS in enabled on your system. Otherwise it will use UFS.

The ``vnet`` option will configure your system for use with VNET ``-V`` jails.

The ``bridge`` options will attempt to configure a bridge interface for use with bridged VNET
``-B`` jails.

Running ``bastille setup`` without any options will attempt to auto-configure the ``filesystem``, ``loopback``, ``firewall`` and
``storage`` options.

.. code-block:: shell

  ishmael ~ # bastille setup -h
  Usage: bastille setup [option(s)] [bridge]
                                    [filesystem]
                                    [loopback]
                                    [pf|firewall]
                                    [shared]
                                    [vnet]
                                    [storage]
	
    Options:

    -y | --yes             Assume always yes on prompts.
    -x | --debug           Enable debug mode.
