Networking Limitations
======================

VNET Jail Interface Names
-------------------------

* FreeBSD has certain limitations when it comes to interface names. One
  of these is that interface names cannot be longer than 15 characters.
  Because of this, Bastille uses a generic name for any epairs created
  whose corresponding jail name exceeds the maximum length. See below...

  ``e0a_jailname`` and ``e0b_jailname`` are the default epair interfaces for every
  jail. The ``e0a`` side is on the host, while the ``e0b`` is in the jail. Due
  to the above mentioned limitations, Bastille will name any epairs whose
  jail names exceed the maximum length, to ``e0b_bastilleX`` and ``e0b_bastilleX``
  with the ``X`` starting at ``1`` and incrementing by 1 for each new epair.
  So, ``mylongjailname`` will be ``e0a_bastille2`` and ``e0b_bastille2``.

Netgraph and Proxmox VE
-----------------------

* When running a FreeBSD VM on Proxmox VE, you might encounter crashes when using
  Netraph. This bug is being tracked at
  https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=238326

  One workaround is to add the following line to the ``jail.conf`` file of the affected
  jail(s).

.. code-block:: shell

  exec.prestop += "jng shutdown JAILNAME";

local_unbound
-------------

If you are running "local_unbound" on your server, you will probably have issues
with DNS resolution.

To resolve this, add the following configuration to local_unbound:

.. code-block:: shell

  server:
  interface: 0.0.0.0
  access-control: 192.168.0.0/16 allow
  access-control: 10.17.90.0/24 allow

Also, change the nameserver to the servers IP instead of 127.0.0.1 inside
/etc/rc.conf

Adjust the above "access-control" strings to fit your network.
