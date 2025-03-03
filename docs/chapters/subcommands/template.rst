template
========

Run preconfigured template files inside targeted jail(s).

.. code-block:: shell

  ishmael ~ # bastille template azkaban project/template

Templates should be structured in `project/template/Bastillefile` format, and placed in the template
directory, which defaults to `/usr/local/bastille/templates`. The Bastillefile should contain the template
hooks. See the chapter called Template for a list of supported hooks.

.. code-block:: shell

  ishmael ~ # bastille template help
  Usage: bastille template [option(s)] TARGET [--convert|project/template]
  
    Options:

    -a | --auto           Auto mode. Start/stop jail(s) if required.
    -x | --debug          Enable debug mode.
