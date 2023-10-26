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

I recommend using private (rfc1918) ip address ranges for your container.  These
ranges include:

- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

Bastille does its best to validate the submitted ip is valid. This has not been
thouroughly tested--I generally use the 10/8 range.

One point to be made about jails.  If you run uname inside a jail you will not
get the information about the jail, but about the host system.  If you want accurate 
information about  the jail please use freebsd-version inside the jail.

Also, the MOTD also was reporting the host system instead of the jail.  This 
caused a lot of confusion for users, so the MOTD was disabled by the use of 
the .hushlogin file.  This prevents confusing contradictory information to be 
shown to the user.  
