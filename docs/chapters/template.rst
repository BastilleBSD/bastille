Template
========
Looking for ready made CI/CD validated `Bastille Templates`_?

Bastille supports a templating system allowing you to apply files, pkgs and
execute commands inside the containers automatically.

Currently supported template hooks are: ``ARG``, ``CMD``, ``CONFIG``, ``CP``,
``INCLUDE``, ``LIMITS``, ``MOUNT``, ``OVERLAY``, ``PKG``, ``RDR``, ``RENDER``,
``RESTART``, ``SERVICE``, ``SYSRC``.

Templates are created in ``${bastille_prefix}/templates`` and can leverage any
of the template hooks.

Bastille 0.7.x+
---------------
Bastille 0.7.x introduces a template syntax that is more flexible and allows
any-order scripting. Previous versions had a hard template execution order and
instructions were spread across multiple files. The new syntax is done in a
``Bastillefile`` and the template hook (see below) files are replaced with
template hook commands.

Template Automation Hooks
-------------------------

+---------------+---------------------+-----------------------------------------+
| HOOK          | format              | example                                 |
+===============+=====================+=========================================+
| ARG           | ARG=VALUE           | MINECRAFT_MEMX="1024M"                  |
+---------------+---------------------+-----------------------------------------+
| CMD           | /bin/sh command     | /usr/bin/chsh -s /usr/local/bin/zsh     |
+---------------+---------------------+-----------------------------------------+
| CONFIG        | set property value  | set allow.mlock 1                       |
+---------------+---------------------+-----------------------------------------+
| CP/OVERLAY    | path(s)             | etc root usr (one per line)             |
+---------------+---------------------+-----------------------------------------+
| INCLUDE       | template path/URL   | http?://TEMPLATE_URL or project/path    |
+---------------+---------------------+-----------------------------------------+
| LIMITS        | resource value      | memoryuse 1G                            |
+---------------+---------------------+-----------------------------------------+
| LINE_IN_FILE  | line file_path      | word /usr/local/word/word.conf          |
+---------------+---------------------+-----------------------------------------+
| MOUNT         | fstab syntax        | /host/path container/path nullfs ro 0 0 |
+---------------+---------------------+-----------------------------------------+
| OVERLAY       | path(s)             | etc root usr (one per line)             |
+---------------+---------------------+-----------------------------------------+
| PKG           | port/pkg name(s)    | vim-console zsh git-lite tree htop      |
+---------------+---------------------+-----------------------------------------+
| RDR           | tcp port port       | tcp 2200 22 (hostport jailport)         |
+---------------+---------------------+-----------------------------------------+
| RENDER        | /path/file.txt      | /usr/local/etc/gitea/conf/app.ini       |
+---------------+---------------------+-----------------------------------------+
| RESTART       |                     | (restart jail)                          |
+---------------+---------------------+-----------------------------------------+
| SERVICE       | service command     | 'nginx start' OR 'postfix reload'       |
+---------------+---------------------+-----------------------------------------+
| SYSRC         | sysrc command(s)    | nginx_enable=YES                        |
+---------------+---------------------+-----------------------------------------+

Template Hook Descriptions
--------------------------

``ARG``       - set an ARG value to be used in the template

ARGS will default to the value set inside the template, but can be changed by
including ``--arg ARG=VALUE`` when running the template.

Multiple ARGS can also be specified as seen below. If no ARG value is given,
Bastille will show a warning, but continue on with the rest of the template.

.. code-block:: shell

  ishmael ~ # bastille template azkaban sample/template --arg ARG=VALUE --arg ARG1=VALUE

The ``ARG`` hook has a wide range of functionality, including passing KEY=VALUE
pairs to any templates called with the ``INCLUDE`` hook. See the following example...

.. code-block:: shell

  ARG JAIL
  ARG IP

  INCLUDE other/template --arg JAIL=${JAIL} --arg IP=${IP}

If the above template is called with ``--arg JAIL=myjail --arg IP=10.3.3.3``,
these values will be passed along to ``other/template`` as well, with the
matching variable. So ``${JAIL}`` will be ``myjail`` and ``${IP}`` will be
``10.3.3.3``.

The ARG hook has three values that are built in, and will differ for every jail.
The values are ``JAIL_NAME``, ``JAIL_IP``, and ``JAIL_IP6``. These can be used
inside any template without setting the values at the top of the Bastillefile.
The values are automatically retrieved from the targeted jails configuration.

``CMD``           - run the specified command

``CONFIG``        - set the specified property and value

``CP/OVERLAY``    - copy specified files from template directory to specified path inside jail

``INCLUDE``       - specify a template to include. Make sure the template is
bootstrapped, or you are using the template url

``LIMITS``        - set the specified resource value for the jail

``LINE_IN_FILE``  - add specified word to specified file if not present

``MOUNT``         - mount specified files/directories inside the jail

``PKG``           - install specified packages inside jail

``RDR``           - redirect specified ports to the jail

``RENDER``        - replace ARG values inside specified files inside the jail. If a
directory is specified, ARGS will be replaced in all files underneath

``RESTART``       - restart the jail

``SERVICE``       - run `service` command inside the jail with specified arguments

``SYSRC``         - run `sysrc` inside the jail with specified arguments

Special Hook Cases
------------------

SYSRC requires that NO quotes be used or that quotes (``"``) be escaped ie;
(``\\"``)

ARG will always treat an ampersand "\``&``" literally, without the need to
escape it. Escaping it will cause errors.

Bootstrapping Templates
-----------------------

The official templates for Bastille are all on Gthub, and mirror the directory 
structure of the ports tree.  So, ``nginx`` is in the ``www`` directory in the
templates, just like it is in the FreeBSD ports tree.  To bootstrap the
entire set of official predefined templates run the following command:

.. code-block:: shell

   bastille bootstrap https://github.com/bastillebsd/templates

This will install all official templates into the templates directory at
``/usr/local/bastille/templates``. You can then use the ``bastille template``
command to apply any of the templates.

.. code-block:: shell

   bastille template TARGET www/nginx

Creating Templates
------------------

Templates can be created and placed inside the templates directory in the
``project/template`` format. Alternatively you can run the ``bastille template``
command from a relative path, making sure it is still in the above format.
 
Template Examples
-----------------

Place these uppercase template hook commands into a ``Bastillefile`` in any
order and automate container setup as needed.

In addition to supporting template hooks, Bastille supports overlaying files
into the container. This is done by placing the files in their full path, using
the template directory as "/".

An example here may help. Think of ``bastille/templates/username/template``, our
example template, as the root of our filesystem overlay. If you create an
``/etc/hosts`` or ``/etc/resolv.conf`` *inside* the template directory, these
can be overlayed into your container.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in ``/usr/local``. The few general exceptions
are the ``/etc/hosts``, ``/etc/resolv.conf``, and ``/etc/rc.conf.local``.

After populating ``/usr/local`` with custom config files that your container
will use, be sure to include ``/usr`` in the template OVERLAY definition. eg;

.. code-block:: shell

  echo "CP /usr /" >> /usr/local/bastille/templates/username/template/Bastillefile

The above example ``/usr`` will include anything under ``/usr`` inside the
template.
You do not need to list individual files. Just include the top-level directory
name. List these top-level directories one per line.

Applying Templates
------------------

Containers must be running to apply templates.

Bastille includes a ``template`` command. This command requires a target and a
template name. As covered in the previous section, template names correspond to
directory names in the ``bastille/templates`` directory.

.. code-block:: shell

  ishmael ~ # bastille template ALL username/template
  [proxy01]:
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  Updating bastillebsd.org repository catalogue...
  [cdn] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [cdn] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  bastillebsd.org repository update completed. 499 packages processed.
  All repositories are up to date.
  Checking integrity... done (0 conflicting)
  The most recent version of packages are already installed
  Updating services.
  cron_flags: -J 60 -> -J 60
  sendmail_enable: NONE -> NONE
  syslogd_flags: -ss -> -ss
  Executing final command(s).
  chsh: user information updated
  Template Complete.

  [web01]:
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  Updating pkg.bastillebsd.org repository catalogue...
  [poudriere] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [poudriere] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 499 packages processed.
  Updating bastillebsd.org repository catalogue...
  [poudriere] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [poudriere] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  bastillebsd.org repository update completed. 499 packages processed.
  All repositories are up to date.
  Checking integrity... done (0 conflicting)
  The most recent version of packages are already installed
  Updating services.
  cron_flags: -J 60 -> -J 60
  sendmail_enable: NONE -> NONE
  syslogd_flags: -ss -> -ss
  Executing final command(s).
  chsh: user information updated
  Template Complete.

.. _Bastille Templates: https://gitlab.com/BastilleBSD-Templates

Using Ports in Templates
------------------------

Sometimes when you make a template you need special options for a package, or
you need a newer version than what is in the pkgs.  The solution for these
cases, or a case like minecraft server that has NO compiled option, is to use
the ports.  A working example of this is the minecraft server template in the
template repo.  The main lines needed to use this is first to mount the ports
directory, then compile the port.  Below is an example of the minecraft template
where this was used.

.. code-block:: shell

  ARG MINECRAFT_MEMX="1024M"
  ARG MINECRAFT_MEMS="1024M"
  ARG MINECRAFT_ARGS=""
  CONFIG set enforce_statfs=1;
  CONFIG set allow.mount.fdescfs;
  CONFIG set allow.mount.procfs;
  RESTART
  PKG dialog4ports tmux openjdk17
  MOUNT /usr/ports usr/ports nullfs ro 0 0
  CP etc /
  CP var /
  CMD make -C /usr/ports/games/minecraft-server install clean
  CP usr /
  SYSRC minecraft_enable=YES
  SYSRC minecraft_memx=${MINECRAFT_MEMX}
  SYSRC minecraft_mems=${MINECRAFT_MEMS}
  SYSRC minecraft_args=${MINECRAFT_ARGS}
  SERVICE minecraft restart
  RDR tcp 25565 25565

The MOUNT line mounts the ports directory, then the CMD make line makes the
port.  This can be modified to use any port in the port tree.
