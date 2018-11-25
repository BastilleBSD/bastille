======
verify
======

This command scans a bootstrapped release and validates that everything looks
in order. This is not a 100% comprehensive check, but it compares the release
against a "known good" index.

If you see errors or issues here, consider deleting and re-bootstrapping
the release.

.. code-block:: shell

  ishmael ~ # bastille verify 11.2-RELEASE
  Looking up update.FreeBSD.org mirrors... 2 mirrors found.
  Fetching metadata signature for 11.2-RELEASE from update1.freebsd.org... done.
  Fetching metadata index... done.
  Fetching 1 metadata patches. done.
  Applying metadata patches... done.
  Fetching 1 metadata files... done.
  Inspecting system... done.
