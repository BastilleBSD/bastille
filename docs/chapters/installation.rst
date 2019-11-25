Installation
============
Bastille is available in the official FreeBSD ports tree at
`sysutils/bastille`. Binary packages available in `quarterly` and `latest`
repositories.

Current version is `0.5.20191125`.

To install from the FreeBSD package repository:

* quarterly repository may be older version
* latest repository will match recent ports


PKG
---

.. code-block:: shell

  pkg install bastille


To install from source (don't worry, no compiling):

ports
-----

.. code-block:: shell

  make -C /usr/ports/sysutils/bastille install clean
