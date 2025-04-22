convert
=======

Convert allows converting a thin jail to a thick jail.
It also allows converting a thick jail to a customized release.

Converting a thin jail to a thick jail requires only the target jail.

.. code-block:: shell

  ishmael ~ # bastille convert azkaban

Converting a thick jail to a custom release requires a target jail as 
well as custom release name.

.. code-block:: shell

  ishmael ~ # bastille convert azkaban myrelease

This release can then be used to create a thick jail using the ``--no-validate`` flag.

.. code-block:: shell

  ishmael ~ # bastille create --no-validate customjail myrelease 10.0.0.1

.. code-block:: shell

  ishmael ~ # bastille convert help
  Usage: bastille convert [option(s)] TARGET
    Options:
	
    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.
