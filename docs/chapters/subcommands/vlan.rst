vlan
====

The ``vlan`` subcommand can add or remove VLANs to a specified interface.

The default is to add the VLANs only to the ``rc.conf`` of the jail. This
means you will have to make sure the host is properly configured.
See :doc:`/chapters/networking/vlan` for more details.

There are two other modes supported, but require the host to be on FreeBSD
15 as that is the first major release to support them. It also requires a
bridge interface with the ``vlanfilter`` option enabled.
See :doc:`/chapters/networking/vlan` for more details.

Note: When specifying and interface, it should be the actual interface on the
host that the jail is connected to, not the ``vnetX`` interfaces inside
the jail.

.. code-block:: shell

  ishmael ~ # bastille vlan help
  Usage: bastille vlan [option(s)] TARGET add VLAN INTERFACE [IP]
                                   TARGET remove VLAN INTERFACE

      Options:

      -a | --auto            Start/stop jail(s) if required.
      -n | --no-ip           Add VLAN withouth an IP.
      -t | --tagged          Add/remove a tagged VLAN (bridge interface only).
      -u | --untagged        Add/remove an untagged VLAN (bridge interface only).
