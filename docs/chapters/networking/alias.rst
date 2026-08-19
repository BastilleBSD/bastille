Alias Configuration
===================

To configure a jail with the alias network mode, we simply make sure
that the IP we assign is reachable within our local network, and the
interface we assign is connected to our local network.

Attaching a jail to the ``bastille0`` interface using an IP that
is reachable within our local network will cause the jail to not
have outbound access. This is becaue the jail IP will not be added
to the pf firewall table, and ``bastille0`` is a loopback address
intended only for NAT jails.