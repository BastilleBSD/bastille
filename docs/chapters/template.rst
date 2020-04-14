========
Template
========
Looking for ready made CI/CD validated [Bastille
Templates](https://gitlab.com/BastilleBSD-Templates)?

Bastille supports a templating system allowing you to apply files, pkgs and
execute commands inside the containers automatically.

Currently supported template hooks are: `LIMITS`, `INCLUDE`, `PRE`, `FSTAB`,
`PKG`, `OVERLAY`, `SYSRC`, `SERVICE`, `CMD`.
Planned template hooks include: `PF`, `LOG`.

Templates are created in `${bastille_prefix}/templates` and can leverage any of
the template hooks. Simply create a new directory named after the template. eg;

.. code-block:: shell

  mkdir -p /usr/local/bastille/templates/username/base

To leverage a template hook, create an UPPERCASE file in the root of the
template directory named after the hook you want to execute. eg;

.. code-block:: shell

  echo "zsh vim-console git-lite htop" > /usr/local/bastille/templates/username/base/PKG
  echo "/usr/bin/chsh -s /usr/local/bin/zsh" > /usr/local/bastille/templates/username/base/CMD
  echo "usr" > /usr/local/bastille/templates/username/base/OVERLAY

Template hooks are executed in specific order and require specific syntax to
work as expected. This table outlines those requirements:


+---------+-------------------+-----------------------------------------+
| HOOK    | format            | example                                 |
+=========+===================+=========================================+
| LIMITS  | resource value    | memoryuse 1G                            |
+---------+-------------------+-----------------------------------------+
| INCLUDE | template path/URL | http?://TEMPLATE_URL or project/path    |
+---------+-------------------+-----------------------------------------+
| PRE     | /bin/sh command   | mkdir -p /usr/local/my_app/html         |
+---------+-------------------+-----------------------------------------+
| FSTAB   | fstab syntax      | /host/path container/path nullfs ro 0 0 |
+---------+-------------------+-----------------------------------------+
| PKG     | port/pkg name(s)  | vim-console zsh git-lite tree htop      |
+---------+-------------------+-----------------------------------------+
| OVERLAY | path(s)           | etc root usr (one per line)             |
+---------+-------------------+-----------------------------------------+
| SYSRC   | sysrc command(s)  | nginx_enable=YES                        |
+---------+-------------------+-----------------------------------------+
| SERVICE | service command   | 'nginx start' OR 'postfix reload'       |
+---------+-------------------+-----------------------------------------+
| CMD     | /bin/sh command   | /usr/bin/chsh -s /usr/local/bin/zsh     |
+---------+-------------------+-----------------------------------------+

Note: SYSRC requires that NO quotes be used or that quotes (`"`) be escaped
ie; (`\\"`)

In addition to supporting template hooks, Bastille supports overlaying
files into the container. This is done by placing the files in their full path,
using the template directory as "/".

An example here may help. Think of `bastille/templates/username/base`, our
example template, as the root of our filesystem overlay. If you create an
`etc/hosts` or `etc/resolv.conf` *inside* the base template directory, these
can be overlayed into your container.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in `usr/local`. The few general
exceptions are the `etc/hosts`, `etc/resolv.conf`, and
`etc/rc.conf.local`.

After populating `usr/local` with custom config files that your container will
use, be sure to include `usr` in the template OVERLAY definition. eg;

.. code-block:: shell

  echo "usr" > /usr/local/bastille/templates/username/base/OVERLAY

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

  ishmael ~ # bastille template ALL username/base
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
