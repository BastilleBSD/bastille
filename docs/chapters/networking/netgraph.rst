Netgraph
========

Bastille supports netgraph as an VNET management tool, thanks to the `jng` script.
To enable netgraph, run `bastille setup netgraph`. This will load and persist the
required kernel modules. Once netgraph is configured, any VNET jails
you create will be managed with netgraph.

Note that you should only enable netgraph on a new system. Bastille is set up to
use either `netgraph` or `if_bridge` as the VNET management, and uses `if_bridge`
as the default, as it always has. The `netgraph` option is new, and should only
be used with new systems.

This value is set with the `bastille_network_vnet_type` option inside the config
file.