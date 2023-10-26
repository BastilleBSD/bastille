========
Template
========
Looking for ready made CI/CD validated `Bastille Templates`_?

Bastille supports a templating system allowing you to apply files, pkgs and
execute commands inside the containers automatically.

Currently supported template hooks are: `CMD`, `CP`, `INCLUDE`, `LIMITS`, `MOUNT`,
`PKG`, `RDR`, `SERVICE`, `SYSRC`.

Templates are created in `${bastille_prefix}/templates` and can leverage any of
the template hooks.

Bastille 0.7.x+
---------------
Bastille 0.7.x introduces a template syntax that is more flexible and allows
any-order scripting. Previous versions had a hard template execution order and
instructions were spread across multiple files. The new syntax is done in a
`Bastillefile` and the template hook (see below) files are replaced with
template hook commands.

Template Automation Hooks
-------------------------

+---------+-------------------+-----------------------------------------+
| HOOK    | format            | example                                 |
+=========+===================+=========================================+
| CMD     | /bin/sh command   | /usr/bin/chsh -s /usr/local/bin/zsh     |
+---------+-------------------+-----------------------------------------+
| CP      | path(s)           | etc root usr (one per line)             |
+---------+-------------------+-----------------------------------------+
| INCLUDE | template path/URL | http?://TEMPLATE_URL or project/path    |
+---------+-------------------+-----------------------------------------+
| LIMITS  | resource value    | memoryuse 1G                            |
+---------+-------------------+-----------------------------------------+
| MOUNT   | fstab syntax      | /host/path container/path nullfs ro 0 0 |
+---------+-------------------+-----------------------------------------+
| PKG     | port/pkg name(s)  | vim-console zsh git-lite tree htop      |
+---------+-------------------+-----------------------------------------+
| RDR     | tcp port port     | tcp 2200 22 (hostport jailport)         |
+---------+-------------------+-----------------------------------------+
| SERVICE | service command   | 'nginx start' OR 'postfix reload'       |
+---------+-------------------+-----------------------------------------+
| SYSRC   | sysrc command(s)  | nginx_enable=YES                        |
+---------+-------------------+-----------------------------------------+

Note: SYSRC requires that NO quotes be used or that quotes (`"`) be escaped
ie; (`\\"`)

Place these uppercase template hook commands into a `Bastillefile` in any order
and automate container setup as needed.

In addition to supporting template hooks, Bastille supports overlaying
files into the container. This is done by placing the files in their full path,
using the template directory as "/".

An example here may help. Think of `bastille/templates/username/template`, our
example template, as the root of our filesystem overlay. If you create an
`etc/hosts` or `etc/resolv.conf` *inside* the template directory, these
can be overlayed into your container.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in `usr/local`. The few general
exceptions are the `etc/hosts`, `etc/resolv.conf`, and
`etc/rc.conf.local`.

After populating `usr/local` with custom config files that your container will
use, be sure to include `usr` in the template OVERLAY definition. eg;

.. code-block:: shell

  echo "CP usr /" >> /usr/local/bastille/templates/username/template/Bastillefile

The above example "usr" will include anything under "usr" inside the template.
You do not need to list individual files. Just include the top-level directory
name. List these top-level directories one per line.

Applying Templates
------------------

Containers must be running to apply templates.

Bastille includes a `template` command. This command requires a target and a
template name. As covered in the previous section, template names correspond to
directory names in the `bastille/templates` directory.

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

Sometimes when you make a template you need special options for a package, or you need a newer version than what is in the pkgs.  The solution for these cases, or a case like minecraft server that has NO compiled option, is to use the ports.  A working example of this is the minecraft server template in the template repo.  The main lines needed to use this is first to mount the ports directory, then compile the port.  Below is an example of the minecraft template where this was used.

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

The MOUNT line mounts the ports directory, then the CMD make line makes the port.  This can be modified to use any port in the port tree.




