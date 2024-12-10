===
rdr
===

`bastille rdr` allows you to configure dynamic rdr rules for your containers
without modifying pf.conf (assuming you are using the `bastille0` interface
for a private network and have enabled `rdr-anchor 'rdr/*'` in /etc/pf.conf
as described in the Networking section).

Note: you need to be careful if host services are configured to run
on all interfaces as this will include the jail interface - you should
specify the interface they run on in rc.conf (or other config files)

.. code-block:: shell

    # bastille rdr --help
    Usage: bastille rdr TARGET [clear] | [list] | [<interface> tcp <host_port> <jail_port>] | [<interface> udp <host_port> <jail_port>]
    # bastille rdr dev1 tcp 2001 22
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    # bastille rdr dev1 udp 2053 53
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    # bastille rdr dev1 clear
    nat cleared

If you have a host with multiple interfaces, and you want to specify which
one to use, `bastille rdr` allows you to pass any interface to the command.
If you do not specify an interface, the default one will be used.

.. code-block:: shell

    # bastille rdr em0 dev1 tcp 2001 22
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    # bastille rdr dev1 vtnet0 udp 2053 53
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr on vtnet0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
