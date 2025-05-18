verify
======

This command scans a bootstrapped release or template and validates that
everything looks in order. This is not a 100% comprehensive check, but it
compares the release or template against a "known good" index.

If you see errors or issues here, consider deleting and re-bootstrapping the
release or template .

.. code-block:: shell

  ishmael ~ # bastille verify 11.2-RELEASE
  Looking up update.FreeBSD.org mirrors... 2 mirrors found.
  Fetching metadata signature for 11.2-RELEASE from update1.freebsd.org... done.
  Fetching metadata index... done.
  Fetching 1 metadata patches. done.
  Applying metadata patches... done.
  Fetching 1 metadata files... done.
  Inspecting system... done.

  ishmael ~ # bastille verify bastillebsd-templates/jellyfin
  Detected Bastillefile hook.
  [Bastillefile]:
  CMD mkdir -p /usr/local/etc/pkg/repos
  CMD echo 'FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }' > 
  /usr/local/etc/pkg/repos/FreeBSD.conf
  CONFIG set allow.mlock=1;
  CONFIG set ip6=inherit;
  RESTART
  PKG jellyfin
  SYSRC jellyfin_enable=TRUE
  SERVICE jellyfin start
  Template ready to use.

.. code-block:: shell

  ishmael ~ # bastille verify help
  Usage: bastille verify [option(s)] RELEASE|TEMPLATE
    Options:

    -x | --debug          Enable debug mode.
