rdr
===

``bastille rdr`` allows you to configure dynamic rdr rules for your containers
without modifying pf.conf (assuming you are using the ``bastille0`` interface
for a private network and have enabled ``rdr-anchor 'rdr/*'`` in /etc/pf.conf as
described in the Networking section).

Note: you need to be careful if host services are configured to run on all
interfaces as this will include the jail interface - you should specify the
interface they run on in rc.conf (or other config files)

.. code-block:: shell
    
    # bastille rdr dev1 tcp 2001 22
    [jail1]:
    IPv4 tcp/2001:22  on em0
   
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    
    # bastille rdr dev1 udp 2053 53
    [jail1]:
    IPv4 udp/2053:53 on em0
    
    # bastille rdr dev1 list
    rdr pass on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr pass on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    
    # bastille rdr dev1 clear
    nat cleared

The ``rdr`` command includes 4 additional options:

.. code-block:: shell

    -d | --destination [destination]          Limit rdr to a destination IP. Useful if you have multiple IPs on one interface.
    -i | --interface   [interface]            Set the interface to create the rdr rule on. Useful if you have multiple interfaces.
    -s | --source      [source]               Limit rdr to a source IP or table. Useful to only allow access from certain sources.
    -t | --type        [ipv4|ipv6]            Specify IP type. Must be used if -s or -d are used. Defaults to both.

.. code-block:: shell

    # bastille rdr -i vtnet0 dev1 udp 8000 80
    [jail1]:
    IPv4 tcp/8000:80 on vtnet0
    
    # bastille rdr -s 192.168.0.1 dev1 tcp 8080 81
    [jail1]:
    IPv4 tcp/8080:81 on em0

    # bastille rdr -d 192.168.0.84 dev1 tcp 8082 82
    [jail1]:
    IPv4 tcp/8082:82 on em0

    # bastille rdr -i vtnet0 -d 192.168.0.45 dev1 tcp 9000 9000
    [jail1]:
    IPv4 tcp/9000:9000 on vtnet0

    # bastille rdr dev1 list
    rdr pass on vtnet0 inet proto udp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr pass on em0 inet proto tcp from 192.168.0.1 to any port = 8080 -> 10.17.89.1 port 81
    rdr pass on em0 inet proto tcp from any to 192.168.0.84 port = 8082 -> 10.17.89.1 port 82
    rdr pass on vtnet0 inet proto tcp from any to 192.168.0.45 port = 9000 -> 10.17.89.1 port 9000

The options can be used together, as seen above.

If you have multiple interfaces assigned to your jail, ``bastille rdr`` will
only redirect using the default one.

It is also possible to specify a pf table as the source, providing it exists.
Simply use the table name instead of an IP address or subnet.

.. code-block:: shell

  # bastille rdr --help
  Usage: bastille rdr TARGET [option(s)] [clear|reset|list|(tcp|udp host_port jail_port [log ['(' logopts ')'] ] )]
 
      Options:

      -d | --destination [destination]             Limit rdr to a destination IP. Useful if you have multiple IPs on one interface.
      -i | --interface   [interface]               Set the interface to create the rdr rule on. Useful if you have multiple interfaces.
      -s | --source      [source]                  Limit rdr to a source IP or table. Useful to only allow access from certain sources.
      -t | --type        [ipv4|ipv6]               Specify IP type. Must be used if -s or -d are used. Defaults to both.
      -x | --debug                                 Enable debug mode.
