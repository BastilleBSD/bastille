convert
=======

Convert a thin jail to a thick jail.

.. code-block:: shell

  ishmael ~ # bastille convert azkaban
  [azkaban]:
  ...

Syntax requires only the target jail to convert.

.. code-block:: shell

  ishmael ~ # bastille convert help
  Usage: bastille convert [option(s)] TARGET
    Options:
	
    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.
