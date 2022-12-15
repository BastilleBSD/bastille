=========
bootstrap
=========

The `bootstrap` sub-command is used to download and extract releases and
templates for use with Bastille containers.   First, some background. 

Background
============

A release is a version of the operating system used in jails and shared by one or more Bastille containers. It is mounted in a container as a non-writable  (nullfs) file system. 
A valid release is needed before containers can be created.  

Note: Bastille does error checking on release names, so your mileage 
may vary with unsupported releases and releases newer
than the host system likely will NOT work at all.

Templates facilitate full container automation.
A template installs sofware into containers on top of the nullfs base layer.
Multiple templates can install different software into a single container.   
Templates are optional.  
Existing templates can be downloaded like releases, or they can be developed in place. 
See the documentation on templates for more information on how they work and
how you can create or customize your own.

If you install the same templates into multiple containers,  then it may make sense to create a new release with the shared tools and libraries.  The way to do this is to create a basic container, install the required software and then create a tar extract (extemded-base.txz) of that entire container.  That will be your new release.    
Put that tar extract in the 
cache directory /usr/local/bastille/cache, and 
the Bastille bootstrap command will find it. 
But Basille `does error checking on legal release names < https://github.com/BastilleBSD/bastille/blob/0ee17be875633da58ae2397aca77bc13b1213993/usr/local/share/bastille/bootstrap.sh#L475>`_, so you may have to first edit or disable that error checking code. 
Your mileage may vary.  Please let us know what happens. 
 
Releases
========
The bootstrap sub-command downloads releases. 

Example
-------

To `bootstrap` a FreeBSD release, run the bootstrap sub-command with the
release version as the argument.

.. code-block:: shell

  ishmael ~ # bastille bootstrap 12.3-RELEASE [update]
  ishmael ~ # bastille bootstrap 13.1-RELEASE

To `bootstrap` a HardenedBSD release, run the bootstrap sub-command with the
build version as the argument.

.. code-block:: shell

  ishmael ~ # bastille bootstrap 13-stable-build-latest


This command will ensure the required directory structures are in place and
download the requested release. For each requested release, `bootstrap` will
download the base.txz. These files are verified (sha256 via MANIFEST file)
before they are extracted for use.

Tips
----

The `bootstrap` sub-command can  take an optional second
argument of "update". If this argument is used, `bastille update` will be run
immediately after the bootstrap, effectively bootstrapping and applying
security patches and errata in all at once.

Notes
-----
You need to bootstrap a release before creating a container with that release.
The bootstrap command is also used when a new FreeBSD version is
released and you want to ownload it for creating new containers, or for upgrading existing containers.

To update a release as patches are made available, see the `bastille update`
command. To upgrade containers to a new version of the operating system, see the 
`bastille upgrade` command

Downloaded artifacts are stored in the `bastille/cache/version` directory.
"bootstrapped" releases are stored in `bastille/releases/version`.

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
 
If you don't want to bother with git to use templates you can create them
manually on the file system and apply them.

Templates are stored in `bastille/templates/namespace/name`. If you'd like to
create a new template on your local system, simply create a new namespace (directory)
within the templates directory and then a directory for the template. This namespacing
allows users and groups to have templates without conflicting template names.

Once you've created the directory structure you can begin filling it with
template hooks. Once you have a minimum number of hooks (at least one) you can
begin applying your template.
