Release Management
==================

Once we have bootstrapped a release, it can be used to create jails. But what if
we have updated all our jails to a newer release, and the old release is no longer
needed?

To list available releases, run ``bastille list releases``. This will show you
all the releases Bastille has already bootstrapped.

Destroy a Release
-----------------

To destroy a release, run ``bastille destroy RELEASE``. For legacy releases, we can
include ``--no-cache`` if we want to keep the ``.txz`` archive for some reason.


Update a Release
----------------

If a release starts getting some age behind it, it becomes necessary to update it
to the latest patches and security updates.

To update a release, simply run ``bastille update RELEASE``. This will fetch and
install the latest updates for the given release.

It is not possible to upgrade a release to a new minor or major version. Bastille
keeps each version in its own directory, so if you need the next minor version
of a release, use the ``bastille bootstrap`` command to bootstrap it.

Converting a Legacy Release to Pkgbase
--------------------------------------

If you want to convert a legacy release to a pkgbase release, we recommend destroying
it, the using ``--pkgbase`` to bootstrap it again. Otherwise you can use
the ``pkgbasify`` script created by the FreeBSD Foundation.

To do so, fetch the ``pkgbasify`` script, and run it with the ``--rootdir`` flag:

.. code-block:: shell

     fetch https://github.com/FreeBSDFoundation/pkgbasify/raw/refs/heads/main/pkgbasify.lua
     chmod +x pkgbasify.lua
     ./pkgbasify.lua --rootdir /usr/local/bastille/releases/15.0-RELEASE

Custom Release
--------------

Bastille supports creating a customized release from any thick jail. After creating your
jail, installing the necessary packages and making the necessary changes, we can
run ``bastille convert JAIL RELEASE`` to convert our jail to a release template. Try not
to name it after an already existing release though. It can then be used to create
more jails.
See :doc:`/chapters/advanced/centralized-assets`.

Because Bastille validates release names when creating jails, you will have to
use the ``--no-validate`` flag when creating a jail from your newly created release.
