upgrade
=======

The ``upgrade`` command targets a thick or thin jail. Thin jails will be updated
by changing the release mount point that it is based on. Thick jails will be
upgraded normally.

.. code-block:: shell

  ishmael ~ # bastille upgrade help
  Usage: bastille upgrade [option(s)] TARGET NEW_RELEASE
                                      TARGET install

      Options:

      -a | --auto      Auto mode. Start/stop jail(s) if required.
      -f | --force     Force upgrade a release (FreeBSD legacy releases).
      -x | --debug     Enable debug mode.