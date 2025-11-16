Centralized Assets
==================

Sometimes it is preferable to share applications, libraries, packages or even
directories and files across multiple jails.

Or perhaps we just want to avoid all the time it takes to create a jail, and
manually configure it with the packages we normally use.

Bastille offers a number of ways to do the above.

Templates
---------

A template is a predefined file containing instructions to execute on a targeted
jail. This is one of the easiest ways to create a repeatable environment for your
Bastille jails. Simply create your template, the execute it on as many jails as
you prefer.

.. code-block:: shell

  ishmael ~ # bastille template "jail1 jail2" project/template

See :doc:`/chapters/template` for more details on templates.

Mounting
--------

On of the fastest ways to share directories and files across multiple jails is
with the ``bastille mount`` command.

The following command will mount ``/my/host/directory`` into ``jail1`` and ``jail2``
at ``/my/jail/directory`` with read and write access. To mount with read only
access, simply use ``ro`` instead of ``rw`` as the option.

.. code-block:: shell

  ishmael ~ # bastille mount "jail1 jail2" /my/host/directory /my/jail/directory nullfs rw 0 0

Cloning
-------

Bastille allows you to create duplicate of your jail using ``bastille clone``.
To clone your jail, use the following command.

.. code-block:: shell

  ishmael ~ # bastille clone myjail mynewjail 10.0.0.3

This will create an exact duplicate of ``myjail`` at ``mynewjail``.

Custom Releases
---------------

Bastille allows creating custom releases from jails, then using those releases to
create more jails.

To start, we must first create our jail. Make sure it is a thick jail, as this
process will not work with any other jail types.

.. code-block:: shell

  ishmael ~ # bastille create -T myjail 14.2-RELEASE 10.0.0.1

Once the jail is up and running, configure it to your liking, then run the
following commmand to create a custom release based on your jail.

.. code-block:: shell

  ishmael ~ # bastille convert myjail myrelease

Once this process completes, you will be able to run the following command to
create a jail based off your newly created release.

Please note that using this approach is experimental. It will be up to the end
user to keep track of which official FreeBSD release their custom release is
based on. The ``osrelease`` config variable will be set to your custom release
name inside the ``jail.conf`` file.

.. code-block:: shell

  ishmael ~ # bastille create -T --no-validate myjail myrelease 10.0.0.2
