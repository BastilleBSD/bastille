===
rdr
===

`bastille rdr` allows you to configure dynamic rdr rules for your containers
without modifying pf.conf (assuming you are using the `bastille0` interface
for a private network and have enabled `rdr-anchor 'rdr/*'` in /etc/pf.conf
as described in the Networking section).

When using `dev` modifier you need to make sure the proper nat configuration is
active for specified network device (`nat on DEV from <jails> to any -> (DEV:0)`).

Note: you need to be careful if host services are configured to run
on all interfaces as this will include the jail interface - you should
specify the interface they run on in rc.conf (or other config files)

.. code-block:: shell

    # bastille rdr --help
    Usage: bastille rdr TARGET [(dev <net_device>)|(ip <destination_ip>)] (clear [persistent])|(list [persistent])|(tcp|udp <host_port> <jail_port> [log ['(' logopts ')'] ] )
    # bastille rdr dev1 tcp 2001 22
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    # bastille rdr dev1 list persistent
    tcp 2001 22
    # bastille rdr dev1 udp 2053 53
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    # bastille rdr dev1 dev lo0 ip 10.0.0.2 tcp 8080 80
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    rdr on lo0 inet proto tcp from any to 10.0.0.2 port = 8080 -> 10.17.89.1 port 80
    # bastille rdr dev1 clear
    Clearing dev1 redirects.
    nat cleared
    # bastille rdr dev1 clear persistent
    Clearing dev1 redirects.
    nat cleared
    Clearing dev1 rdr.conf.
