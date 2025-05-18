config
======

Get, set or remove properties from targeted jail(s).

Getting a property that *is* defined in jail.conf:

.. code-block:: shell

  ishmael ~ # bastille config azkaban get ip4.addr
  bastille0|192.168.2.23

Getting a property that *is not* defined in jail.conf

.. code-block:: shell

  ishmael ~ # bastille config azkaban get notaproperty
  not set

Setting a property:

.. code-block:: shell

  ishmael ~ # bastille config azkaban set allow.mlock 1
  A restart is required for the changes to be applied. See 'bastille restart azkaban'.

The restart message will appear every time a property is set.

Removing a property:

.. code-block:: shell

  ishmael ~ # bastille config azkaban remove allow.mlock
  A restart is required for the changes to be applied. See 'bastille restart azkaban'.

The restart message will appear every time a property is removed.

.. code-block:: shell

  ishmael ~ # bastille config help
  Usage: bastille config [option(s)] TARGET [get|(set|add)|remove] PROPERTY [VALUE]

      Options:

      -x | --debug          Enable debug mode.