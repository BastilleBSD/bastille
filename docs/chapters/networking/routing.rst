Regarding Routes
----------------

Bastille will attempt to auto-detect the default route from the host system and
assign it to the VNET container. This auto-detection may not always be accurate
for your needs for the particular container. In this case you'll need to add a
default route manually or define the preferred default route in the
``bastille.conf``.

.. code-block:: shell

  bastille sysrc TARGET defaultrouter=aa.bb.cc.dd
  bastille service TARGET routing restart

To define a default route / gateway for all VNET containers define the value in
``bastille.conf``:

.. code-block:: shell

  bastille_network_gateway=aa.bb.cc.dd

This config change will apply the defined gateway to any new containers.
Existing containers will need to be manually updated.