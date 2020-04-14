===
rdr
===

`bastille rdr` allows you to configure dynamic rdr rules for your containers
without modifying pf.conf (assuming you are using the `bastille0` interface
for a private network and have enabled `rdr-anchor 'rdr/*'` in /etc/pf.conf
as described in the Networking section).

Note: you need to be careful if host services are configured to run
on all interfaces as this will include the jail interface - you should
sepcify the interface they run on in rc.conf (or other config files)

.. code-block:: shell

    # bastille rdr --help
    Usage: bastille rdr TARGET [clear] | [list] | [tcp <host_port> <jail_port>] | [udp <host_port> <jail_port>]
    # bastille rdr dev1 tcp 2001 22
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    # bastille rdr dev1 udp 2053 53
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    # bastille rdr dev1 clear
    nat cleared
