======
create
======

Bastille create uses any available bootstrapped release to create a
lightweight jailed system. To create a jail simply provide a name,
bootstrapped release and a private (rfc1918) IP address.

- name
- release
- ip

.. code-block:: shell

  ishmael ~ # bastille create folsom 11.2-RELEASE 10.8.62.1
  
  RELEASE: 11.2-RELEASE.
  NAME: folsom.
  IP: 10.8.62.1.

This command will create a 11.2-RELEASE jail assigning the 10.8.62.1 ip
address to the new system.

I recommend using private (rfc1918) ip address ranges for your jails.
These ranges include:

- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

Bastille does its best to validate the submitted ip is valid. This has not
been thouroughly tested--I generally use the 10/8 range.
