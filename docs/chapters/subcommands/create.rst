======
create
======

Bastille create uses any available bootstrapped release to create a
lightweight container system. To create a container simply provide a name,
bootstrapped release and a private (rfc1918) IP address.

- name
- release
- ip
- interface (optional)

.. code-block:: shell

  ishmael ~ # bastille create folsom 11.3-RELEASE 10.17.89.10 [interface]

  RELEASE: 11.3-RELEASE.
  NAME: folsom.
  IP: 10.17.89.10.

This command will create a 11.3-RELEASE container assigning the 10.17.89.10 ip
address to the new system.

.. code-block:: shell

   ishmael ~ # bastille create alcatraz 13.2-RELEASE 10.17.89.113/24


The above code will create a jail with a /24 mask.  At the time of this documentation you 
can only use CIDR notation, and not use a netmask 255.255.255.0 to accomplish this.


I recommend using private (rfc1918) ip address ranges for your container.  These
ranges include:

- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

Bastille does its best to validate the submitted ip is valid. This has not been
thouroughly tested--I generally use the 10/8 range.

A couple of notes about the created jails.  First, MOTD has been disabled inside 
of the jails because it does not give information about the jail, but about the host 
system.  This caused confusion for some users, so we implemented the .hushlogin which 
silences the MOTD at login. 

Also, uname does not work from within a jail.  Much like MOTD, it gives you the version 
information about the host system instead of the jail.  If you need to check the version
of freebsd running on the jail use the freebsd-version command to get accurate information.

