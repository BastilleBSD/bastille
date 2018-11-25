=========
bootstrap
=========

The first step is to "bootstrap" a release. Current supported release is
11.2-RELEASE, but you can bootstrap anything in the ftp.FreeBSD.org
RELEASES directory. 

Note: your mileage may vary with unsupported releases and releases newer
than the host system likely will NOT work at all.

To `bootstrap` a release, run the bootstrap sub-command with the
release version as the argument.

.. code-block:: shell
    
  ishmael ~ # bastille bootstrap 11.2-RELEASE
  ishmael ~ # bastille bootstrap 12.0-RELEASE

This command will ensure the required directory structures are in place
and download the requested release. For each requested release,
`bootstrap` will download the base.txz and lib32.txz. These are both
verified (sha256 via MANIFEST file) before they are extracted for use.

Downloaded artifacts are stored in the `cache` directory. "bootstrapped"
releases are stored in `releases/version`.

The bootstrap subcommand is generally only used once to prepare the
system. The only other use case for the bootstrap command is when a new
FreeBSD version is released and you want to start building jails on that
version.

To update a release as patches are made available, see the `bastille
update` command.
