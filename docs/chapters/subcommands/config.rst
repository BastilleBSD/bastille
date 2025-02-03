=======
config
=======

Gets or sets properties for a target container.

.. code-block:: shell

  Usage: bastille config TARGET get|set propertyName [newValue]

Getting a property that *is* defined in jail.conf:

.. code-block:: shell

  ishmael ~ # bastille config azkaban get ip4.addr
  192.168.2.23

Getting a property that *is not* defined in jail.conf

.. code-block:: shell

  ishmael ~ # bastille config azkaban get notaproperty
  not set

Setting a property:

.. code-block:: shell

  ishmael ~ # bastille config azkaban set ip4.addr 192.168.2.24
  A restart is required for the changes to be applied. See 'bastille restart azkaban'.

The restart message will appear every time a property is set.
