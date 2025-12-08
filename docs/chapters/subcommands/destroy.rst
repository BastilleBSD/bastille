destroy
=======

Bastille will normally ask if you are sure you want to delete targeted jail(s).
Use the ``-y|--yes`` option to bypass this prompt.

.. code-block:: shell

  ishmael ~ # bastille destroy -a folsom
  [folsom]:
  folsom: removed
  Deleting Jail: folsom.
  Note: jail console logs archived.
  /var/log/bastille/folsom_console.log-YYYY-MM-DD

Release can be destroyed provided there are no child jails. The ``-c|--no-cache``
option will retain the release cache (*.txz file), if you choose to keep it.

.. code-block:: shell

  ishmael ~ # bastille destroy help
  Usage: bastille destroy [option(s)] JAIL
                                      RELEASE

      Options:

      -a | --auto         Auto mode. Start/stop jail(s) if required.
      -c | --no-cache     Do not destroy cache when destroying a release (legacy releases).
      -f | --force        Force unmount any mounted datasets when destroying a jail or release (ZFS only).
      -y | --yes          Do not prompt. Assume always yes.
      -x | --debug        Enable debug mode.
