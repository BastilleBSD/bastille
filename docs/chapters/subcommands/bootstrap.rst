=========
bootstrap
=========

The bootstrap sub-command is used to download and extract releases and
templates for use with Bastille containers. A valid release is needed before
containers can be created. Templates are optional but are managed in the same
manner.

Note: your mileage may vary with unsupported releases and releases newer
than the host system likely will NOT work at all. Bastille tries to filter for
valid release names. If you find it will not bootstrap a valid release, please
let us know.

In this document we will describe using the `bootstrap` sub-command with both
releases and templates. We begin with releases.


Releases
========

Example
-------

To `bootstrap` a FreeBSD release, run the bootstrap sub-command with the
release version as the argument.

.. code-block:: shell

  ishmael ~ # bastille bootstrap 14.0-RELEASE [update]
  ishmael ~ # bastille bootstrap 13.2-RELEASE [update]

To `bootstrap` a HardenedBSD release, run the bootstrap sub-command with the
build version as the argument.

.. code-block:: shell

  ishmael ~ # bastille bootstrap 13-stable-build-latest


This command will ensure the required directory structures are in place and
download the requested release. For each requested release, `bootstrap` will
download the base.txz. These files are verified (sha256 via MANIFEST file)
before they are extracted for use.

EOL Releases
------------

It is sometimes necessary to run end-of-life releases for testing or legacy
application support. Dy default Bastille will only install supported releases
but you can bootstrap EOL / unsupported releases with a simple trick.

.. code-block:: shell

   ishmael ~ # export BASTILLE_URL_FREEBSD=http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/
   ishmael ~ # bastille bootstrap 11.2-RELEASE

By overriding the BASTILLE_URL_FREEBSD variable you can now bootstrap archived
releases from the FTP archive.

Tips
----

The `bootstrap` sub-command can now take (0.5.20191125+) an optional second
argument of "update". If this argument is used, `bastille update` will be run
immediately after the bootstrap, effectively bootstrapping and applying
security patches and errata in one motion.

Notes
-----

The bootstrap subcommand is generally only used once to prepare the system. The
only other use case for the bootstrap command is when a new FreeBSD version is
released and you want to start deploying containers on that version.

To update a release as patches are made available, see the `bastille update`
command.

Downloaded artifacts are stored in the `bastille/cache/version` directory.
"bootstrapped" releases are stored in `bastille/releases/version`.

To manually bootstrap a release (aka bring your own archive), place your
archive in bastille/cache/name and extract to bastille/releases/name. Your
mileage may vary; let me know what happens.


Templates
=========

Bastille aims to integrate container automation into the platform while
maintaining a simple, uncomplicated design. Templates are git repositories with
automation definitions for packages, services, file overlays, etc.

To download one of these templates see the example below.

Example
-------

.. code-block:: shell

  ishmael ~ # bastille bootstrap https://gitlab.com/bastillebsd-templates/nginx
  ishmael ~ # bastille bootstrap https://gitlab.com/bastillebsd-templates/mariadb-server
  ishmael ~ # bastille bootstrap https://gitlab.com/bastillebsd-templates/python3

Tips
----
See the documentation on templates for more information on how they work and
how you can create or customize your own. Templates are a powerful part of
Bastille and facilitate full container automation.

Notes
-----
If you don't want to bother with git to use templates you can create them
manually on the Bastille system and apply them.

Templates are stored in `bastille/templates/namespace/name`. If you'd like to
create a new template on your local system, simply create a new namespace
within the templates directory and then one for the template. This namespacing
allows users and groups to have templates without conflicting template names.

Once you've created the directory structure you can begin filling it with
template hooks. Once you have a minimum number of hooks (at least one) you can
begin applying your template.
