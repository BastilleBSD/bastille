Pkgbase
=======

Pkgbase is the new method for managing the base system on a FreeBSD host
or jail. It is considered experimental for 15.0-RELEASE, but will be
made the default for version 16.0-RELEASE and above.

Bootstrap
---------

To bootstrap a release using pkgbase, run ``bastille bootstrap --pkgbase RELEASE``.
For version 14, it is not supported. For version 15 it is optional, but
for version 16 and above, it is the default method of bootstrapping a release.

To customize the 'pkgbase package set' used for bootstrapping, change the 'bastille_pkgbase_packages'
setting located in ``/usr/local/etc/bastille/bastille.conf``. See also 
:doc:`/chapters/configuration`.

Update
------

To update a release created with pkgbase, simply run ``bastille update RELEASE`` as
you would with legacy releases.

To update a thick jail, run ``bastille update TARGET`` as you would with legacy
releases. 

To update a thin jail, you must update the release that it is based on.

Upgrade
-------

Upgrading is not supported for releases. See ``bastille bootstrap RELEASE`` to
bootstrap the required release.

Upgrading is supported for both thin and thick jails. Thin jails will have their
mount points adjusted, and you will need to run ``bastille etcupdate`` on them
when upgrading from a major release to a newer major release. For example,
15.0-RELEASE to 16.0-RELEASE.

Converting to Pkgbase
---------------------

Thick jails that are running legacy releases will have to be converted to pkgbase
before attempting to upgrade to 16.0-RELEASE. This can be done in two ways.

1. Enter the jail, fetch the ``pkgbasify`` script, and run it.

.. code-block:: shell

     fetch https://github.com/FreeBSDFoundation/pkgbasify/raw/refs/heads/main/pkgbasify.lua
     chmod +x pkgbasify.lua
     ./pkgbasify.lua

2. Fetch the ``pkgbasify`` script and run it from the host using ``--rootdir``.
   This requires using `PR 34 <https://github.com/FreeBSDFoundation/pkgbasify/pull/34>`_ in the ``pkgbasify`` repo.

.. code-block:: shell

     fetch https://github.com/FreeBSDFoundation/pkgbasify/raw/refs/heads/main/pkgbasify.lua
     chmod +x pkgbasify.lua
     ./pkgbasify.lua --rootdir /usr/local/bastille/jails/TARGET/root

Converting a release to pkgbase can be done the same way, but we recommend simply destroying
and re-bootstrapping it using pkgbase. This will not work if you are running thin jails
based on the release in question. In such a case, follow step 2 above.
