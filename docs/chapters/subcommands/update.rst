update
======

The ``update`` command targets a release or a thick jail. Because thin jails are
based on a release, when the release is updated all the thin jails are automatically
updated as well.

If no updates are available, a message will be shown:

.. code-block:: shell

  ishmael ~ # bastille update 11.4-RELEASE
  Looking up update.FreeBSD.org mirrors... 2 mirrors found.
  Fetching metadata signature for 11.4-RELEASE from update4.freebsd.org... done.
  Fetching metadata index... done.
  Inspecting system... done.
  Preparing to download files... done.

  No updates needed to update system to 11.4-RELEASE-p4.
  No updates are available to install.

The older the release or jail, however, the more updates will be available:

.. code-block:: shell

  ishmael ~ # bastille update 13.2-RELEASE
  Looking up update.FreeBSD.org mirrors... 2 mirrors found.
  Fetching metadata signature for 13.2-RELEASE from update1.freebsd.org... done.
  Fetching metadata index... done.
  Fetching 2 metadata patches.. done.
  Applying metadata patches... done.
  Fetching 2 metadata files... done.
  Inspecting system... done.
  Preparing to download files... done.

  The following files will be added as part of updating to 13.2-RELEASE-p4:
  ...[snip]...

To be safe, you may want to restart any jails that have been updated live.

If the jail is a thin jail, an error will be shown. If it is a thick jail, it will be updated just like
the release shown above.

.. code-block:: shell

  ishmael ~ # bastille update help
  Usage: bastille update [option(s)] TARGET
    Options:

    -a | --auto             Auto mode. Start/stop jail(s) if required.
    -f | --force            Force update a release.
    -x | --debug            Enable debug mode.