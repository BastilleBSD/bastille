Jail Types
==========

A jail is an isolated, virtualized environment that allows for the isolation
and control of network resources for processes running within it. FreeBSD has had
jails for a very long time, even before Linux containers.

There are a few different types of jails that Bastille can create for you. We will
go through a basic outline of each one.

Thin Jail
---------

A thin jail is the default jail type for Bastille. If no options are given along
with the ``bastille create`` command, Bastille will create a thin jail.

Thin jails are called thin because most of the filesystem is mounted into the jail
from the release. This mainly includes sytem binaries, files and folders. User generated
binaries, files and folders will stay confined to the jail.

These system files are mounted read-only, so the jail is highly secure by default. You still get the full
FreeBSD base, but system files are all mounted read-only. This also means the jail is
very lightweight compared to a thick jail.

Another important thing to note about thin jails is that the release base will be shared
by all jails created using that specific release base.

When updating this release base, all jails bound to it will also be updated. After updating
a release that has child jails, it might be necessary to run ``etcupdate`` inside the jail.
See :doc:`/chapters/subcommands/etcupdate`.

A thin jail is created when no other options are specifed on jail creation.

Thick Jail
----------

A thick jail is a complete copy of a given release. All files inside stay confined to the jail, and
it does not share a release base with other jails. Once you create a thick jail, it remains
completely independant of the release it was created from.

Because a thick jail is a complete copy of a release, it consumes the same amount of space as the
release.

One of the main reasons people choose thick jails is because of their complete isolation. It is the
type of jail that is most similar to a virtual machine.

To create a thick jail, use the ``-T|--thick`` option when creating a jail.

Clone Jail
----------

A clone jail is similar to a thin jail, but is only available when usin ZFS. It uses the ``zfs clone``
command to essentially create a zfs snapshot of a given release. This also means that the only space it
consumes is the changes you make to the jail.

To create a clone jail, use the ``-C|--clone`` option when creating a jail.

Empty Jail
----------

An empty jail is a Batille specific jail, which is simply a jail path without a release. This is
for advanced use cases, and should not be used unles you know what you are doing.

To create an empty jail, use the ``-E|--empty`` option when creating a jail.

Linux Jail
----------

A Linux jail is basically a jail that contains a Linux distribution.
See :doc:`/chapters/releases/bootstrap` to learn how to bootstrap a Linux distribution.

These jails allow you to run Linux inside them, and install Linux programs. They do not support
VNET, or updating and upgrading. This has to be done inside the jail using Linux specific commands.
Linux jails are thick jails, and don't support the thin jail feature.

To create a linux jail, use the ``-L|--linux`` option when creating a jail.

Linux jails do not support VNET.

.. attention::

   Linux jails are experimental and might be removed.

OCI Jail
--------

What is OCI?
^^^^^^^^^^^^

OCI stands for "Open Container Initiative". The official definition is:
"The Open Container Initiative is an open governance structure for the express purpose of creating open
industry standards around container formats and runtimes."

FreeBSD is part of the OCI, and there are already many containers available based on FreeBSD.
The priciple is similar to docker containers, but on FreeBSD these images are deployed
inside jails.

.. attention::

   OCI jails are experimental and might be removed.

Getting Started
^^^^^^^^^^^^^^^

To get started with OCI jails, make sure you have ``bastille_volumesdir="${bastille_prefix}/volumes"`` in
your config file. Alternatively, you can choose to use a ``bastille-compose.yml`` file, or pass any needed
volumes using the ``--volume`` flag during creation.

You will also need to install the ``buildah`` and ``jq`` packages. Run ``pkg install buildah jq``.
These packages help us fetch the images and extract the necessary arguements to run it, such as
the ``entrypoint``, ``volumes``, ``cmd`` and ``stop signal``. The images are stored
in ``${bastille_cachedir}/oci``.

Creating an OCI Jail
^^^^^^^^^^^^^^^^^^^^

An OCI jail is deployed from an OCI compatibale image. For compatible images
visit `Daemonless Images <https://daemonless.io>`_ or `Appjail Makejails <https://github.com/appjail-makejails>`_.
These images are prebuilt, and include everything needed to run the application it targets.

It is not necessary to run ``bastille bootstrap`` to obtain any kind of release
for an OCI jail. OCI jails simply start the image using its ``entrypoint``. We
simply use an image URL instead of a release base when creating a jail.

To install navidrome from daemonless.io, we can the following command:

.. code-block:: shell

  bastille create -O navidrome-jail ghcr.io/daemonless/navidrome 10.1.1.2 bastille0``
  
This will fetch the latest image, copy the contents to the jail root, and start it inside the jail.

It is also possible to run these images inside a VNET jail, in which case you will not need
to forward any ports. Simply supply ``-V|--vnet`` or ``-B|--bridge`` as a create flag.

If no volumes are passed to ``bastille create``, Bastille will automatically mount any necessary
volumes at ``${bastille_volumesdir}/${jail}`` for you. For ``navidrome``, if we want to manually
specify them, we can run the following command:

.. code-block:: shell

  bastille create -O \
                  --volume /host/navidrome/music /music \
				  --volume /host/navidrome/config /config \
				  navidrome ghcr.io/daemonless/navidrome:latest \
				  15.1-RELEASE \
				  10.1.1.2 \
				  bastille0

This will mount the volumes into the jail, using the specified host path. Be sure to check image
documenttion to see which volumes need to be mounted if you choose to mount them manually.

How it Works
^^^^^^^^^^^^

Bastille handles OCI jails by first pulling the image using ``buildah``, then extracting every necessary
piece of information using ``jq``. This includes the entrypoint, cmd, stop signal, env variables, volumes,
labels and others. These are all stored inside ``${bastille_jailsdir}${jail}/container`` for future reference.
The ``env`` file used for the jail environment however, is stored at ``${bastille_jailsdir}/${jail}/env``.

Bastille then builds an ``exec.poststart`` command that will start the image (after the jail is started) using
its entrypoint, cmd, and working directory. It also builds an ``exec.prestop`` command that will stop the
image before stopping the actual jail containg the image.

Any volumes specified are added to the jails ``fstab`` file. 

If you need to forward any ports, you must run ``bastille rdr`` for the given port, or use ``bastille up``.
See :doc:`/chapters/subcommand/up`

Supported container repositories are currently ``ghcr.io`` and ``docker.io``.

Environment
^^^^^^^^^^^

Like most docker containers, OCI images mostly run based on ``env`` variables. Some images require certain
variables to be set, or they won't run. Opencloud is a good example, which requires the ``OC_URL`` to
be set. Bastille is also able to work with ``env`` variables using the ``-e|--env`` flag.
For example, to deploy Opencloud, we can run the following command:

.. code-block:: shell

  bastille create -O \
                  -e OC_URL=https://my.opencloud.xyz \
                  opencloud ghcr.io/daemonless/opencloud \
                  10.1.1.3 \
                  bastille0

This will create our jail, copy the image to the root, and start it using our supplied variables (in addition
to any variable the image itself supplied).

If you need to add more, you can run ``bastille edit myjail env`` to edit the ``env`` file used for that specific jail.

The ``env`` file at the root of the jail is sourced before staring the jail, so any variables get passed into
it and will apply to the OCI image.

Volumes
^^^^^^^

Most images have volumes that need to be mounted into the jail in order to store persistent data. IF YOU DO NOT
SPECIFY any volumes using the ``--volume`` flag, Bastille will extract the list of volumes to mount from the
image config, and mount them at ``${bastille_volumesdir}/${jail}``. It is important to remember that
if you let Bastille automatically mount the volumes in ``${bastille_volumesdir}``, they will still be there
when the jail is destroyed. The same applies to volumes mounted using the ``--volumes`` flag.

Updating an Image
^^^^^^^^^^^^^^^^^

Since OCI jails is in an experimental stage, updating is not supported yet. If you need an update for an image, simply
destory and rebuild your jail. Save any ``env`` vars you might need.

Console into an OCI Jail
^^^^^^^^^^^^^^^^^^^^^^^^

The ``bastille console`` command will not work on the majority of OCI images. If you need to enter an OCI jail, a
workaround is to run ``bastille cmd TARGET`` without any args. This will open a shell inside the jail. To exit,
simply run ``exit``.

Linux Containers
^^^^^^^^^^^^^^^^

While it is technically possible to run a Linux container, it is really not supported. Some do work, but because
Linux containers run off of an entirely different mindset, most will not. In order to create a jail from a Linux
image, it is necessary to run the command using ``--os linux`` flage. See below:

.. code-block:: shell

  bastille create -O \
                  --os linux \
                  filebrowser-linux \
                  docker.io/filebrowser/filebrowser \
                  10.12.12.14 \
                  bastille0

This particular image works without issue.

Logging
^^^^^^^

Bastille saves OCI image logs to ``${bastille_logsdir}/${jail}/oci.log``. Use ``bastille logs jailname oci``
to view them.

See also :doc:`/chapters/subcommands/up`
