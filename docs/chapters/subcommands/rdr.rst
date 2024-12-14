===
rdr
===

bastille rdr allows you to configure dynamic rdr rules for your containers
without modifying pf.conf (assuming you are using the `bastille0` interface
for a private network and have enabled `rdr-anchor 'rdr/*'` in /etc/pf.conf
as described in the Networking section).

Note: you need to be careful if host services are configured to run
on all interfaces as this will include the jail interface - you should
specify the interface they run on in rc.conf (or other config files)

.. code-block:: shell

    # bastille rdr --help
    Usage: bastille rdr TARGET [option(s)] [clear|reset|list|(tcp|udp host_port jail_port [log ['(' logopts ')'] ] )]
    Options:

    -i | --interface   [interface]      | -- Set the interface to create the rdr rule on. Useful if you have multiple interfaces.
    -s | --source      [source ip]      | -- Limit rdr to a source IP. Useful to only allow access from a certian IP or subnet.
    -d | --destination [destination ip] | -- Limit rdr to a destination IP. Useful if you have multiple IPs on one interface.
    -t | --type        [ipv4|ipv6]      | -- Specify IP type. Must be used if -s or -d are used. Defaults to both.

    
    # bastille rdr dev1 tcp 2001 22
    [jail1]:
    IPv4 tcp/any:2001 -> any:22 on em0
   
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    
    # bastille rdr dev1 udp 2053 53
    [jail1]:
    IPv4 udp/any:2001 -> any:22 on em0
    
    # bastille rdr dev1 list
    rdr pass on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr pass on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    
    # bastille rdr dev1 clear
    nat cleared

The `rdr` command includes 3 additional options:

- **-i** | Set a non-default interface on which to create the `rdr` rule.
- **-s** | Limit the source IP on the `rdr` rule.
- **-d** | Limit the destination IP on the `rdr` rule.

.. code-block:: shell

    # bastille rdr dev1 -i vtnet0 udp 2001 22
    [jail1]:
    IPv4 tcp/any:8000 -> any:80 on vtnet0
    
    # bastille rdr dev1 -s 192.168.0.1 tcp 8080 81
    [jail1]:
    IPv4 tcp/192.168.0.1:8080 -> any:81 on em0

    # bastille rdr dev1 -d 192.168.0.84 tcp 8082 82
    [jail1]:
    IPv4 tcp/any:8082 -> 192.168.0.84:82 on em0

    # bastille rdr dev1 -i vtnet0 -d 192.168.0.45 tcp 9000 9000
    [jail1]:
    IPv4 tcp/any:9000 -> 192.168.0.45:9000 on vtnet0

    # bastille rdr dev1 list
    rdr pass on vtnet0 inet proto udp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr pass on em0 inet proto tcp from 192.168.0.1 to any port = 8080 -> 10.17.89.1 port 81
    rdr pass on em0 inet proto tcp from any to 192.168.0.84 port = 8082 -> 10.17.89.1 port 82
    rdr pass on vtnet0 inet proto tcp from any to 192.168.0.45 port = 9000 -> 10.17.89.1 port 9000

The options can be used together, as seen above.
