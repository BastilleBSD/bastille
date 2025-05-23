convert
=======

Convert a thin jail to a thick jail.

Convert a thick jail to a custom release.

Converting a thin jail to a thick jail requires only the TARGET arg.

.. code-block:: shell

  ishmael ~ # bastille convert azkaban

Converting a thick jail to a custom release requires the TARGET and
RELEASE as args.

.. code-block:: shell

  ishmael ~ # bastille convert azkaban myrelease

This release can then be used to create a thick jail using the ``--no-validate`` flag.

.. code-block:: shell

  ishmael ~ # bastille create --no-validate customjail myrelease 10.0.0.1

.. code-block:: shell

  ishmael ~ # bastille convert help
  Usage: bastille convert [option(s)] TARGET [RELEASE]

      Options:
	
      -a | --auto           Auto mode. Start/stop jail(s) if required.
      -y | --yes            Do not prompt. Just convert.
      -x | --debug          Enable debug mode.