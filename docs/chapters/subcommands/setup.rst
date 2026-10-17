setup
=====

The ``setup`` sub-command attempts to automatically configure a host system for
Bastille jails. This allows you to configure networking, firewall, storage, and
some additional options for a Bastille host with one command.

Options
-------

Below is a list of available options that can be used with the ``setup`` command.

The ``bridge`` option will attempt to configure a bridge interface for use with
bridged VNET (``-B``) jails. This interface will be used as a default when not
specifying an interface with the ``create`` command for bridged VNET jails.

The ``dns`` option will configrue your system to use ``local-unbound`` for
host to jail and jail to jail DNS resolution.

The ``linux`` option will attempt to configure your system to run
Linux (``-L|--linux``) jails. This will load some required kernel modules, and
add the to ``/boot/loader.conf``.

The ``loopback`` option will configure a loopback interface called ``bastille0``
that will be used as a default when not specifying an interface with the
``create`` command for NAT jail.

The ``netgraph`` option will attempt to configure your system to use ``netgraph``
as the network mode as opposed to the standard ``if_bridge`` mode.

The ``pf|firewall`` option will configure the pf firewall by enabling the service
and creating the default ``pf.conf`` file. Once this is done, you can use the
``rdr`` command to forward traffic into a jail.

The ``shared`` option will configure the interface you choose to also be used as
the default when not specifying an interface with the ``create`` command for
alias/shared ip jails.

The ``storage`` option will attempt to configure a pool and dataset for Bastille,
but only if ZFS in enabled on your system. Otherwise it will use UFS.

The ``vnet`` option will configure your system for use with VNET (``-V``) jails.

Running ``bastille setup`` without any options will attempt to auto-configure the
``loopback``, ``firewall`` and ``storage`` options.

.. code-block:: shell

  ishmael ~ # bastille setup -h
  Usage: bastille setup [option(s)] [bridge|dns|linux|loopback|netgraph|firewall|shared|storage|vnet]
	
      Options:

      -y | --yes       Do not prompt. Assume always yes.