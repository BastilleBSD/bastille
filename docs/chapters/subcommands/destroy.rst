destroy
=======

Jails can be destroyed and thrown away just as easily as they were created.
Note: containers must be stopped before destroyed. Using the ``-a|--auto``
option will automatically stop the jail before destroying it.

.. code-block:: shell

  ishmael ~ # bastille destroy -a folsom
  [folsom]:
  folsom: removed
  Deleting Container: folsom.
  Note: containers console logs not destroyed.
  /usr/local/bastille/logs/folsom_console.log

Release can be destroyed provided there are no child jails. The `-c|--no-cache`
option will retain the release cache directory, if you choose to keep it.

.. code-block:: shell

  ishmael ~ # bastille destroy help
  Usage: bastille destroy [option(s)] [JAIL|RELEASE]
    Options:

    -a | --auto              Auto mode. Start/stop jail(s) if required.
    -c | --no-cache          Do no destroy cache when destroying a release.
    -f | --force             Force unmount any mounted datasets when destroying a jail or release (ZFS only).
    -x | --debug             Enable debug mode.
