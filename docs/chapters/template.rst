========
Template
========

Bastille supports a templating system allowing you to apply files, pkgs and
execute commands inside the jail automatically.

Currently supported template hooks are: `PRE`, `CONFIG`, `PKG`, `SYSRC`, `CMD`.
Planned template hooks include: `FSTAB`, `PF`

Templates are created in `${bastille_prefix}/templates` and can leverage any of
the template hooks. Simply create a new directory named after the template. eg;

.. code-block:: shell

  mkdir -p /usr/local/bastille/templates/base

To leverage a template hook, create an UPPERCASE file in the root of the
template directory named after the hook you want to execute. eg;

.. code-block:: shell

  echo "zsh vim-console git-lite htop" > /usr/local/bastille/templates/base/PKG
  echo "/usr/bin/chsh -s /usr/local/bin/zsh" > /usr/local/bastille/templates/base/CMD
  echo "etc root usr" > /usr/local/bastille/templates/base/CONFIG

Template hooks are executed in specific order and require specific syntax to
work as expected. This table outlines those requirements:


+---------+------------------+--------------------------------------+
| HOOK    | format           | example                              |
+=========+==================+======================================+
| PRE/CMD | /bin/sh command  | /usr/bin/chsh -s /usr/local/bin/zsh  |
+---------+------------------+--------------------------------------+
| CONFIG  | path             | etc root usr                         |
+---------+------------------+--------------------------------------+
| PKG     | port/pkg name(s) | vim-console zsh git-lite tree htop   |
+---------+------------------+--------------------------------------+
| SYSRC   | sysrc command(s) | nginx_enable=YES                     |
+---------+------------------+--------------------------------------+

Note: SYSRC requires NO quotes or that quotes (`"`) be escaped. ie; `\"`)

In addition to supporting template hooks, Bastille supports overlaying
files into the jail. This is done by placing the files in their full path,
using the template directory as "/".

An example here may help. Think of `/usr/local/bastille/templates/base`,
our example template, as the root of our filesystem overlay. If you create
an `etc/hosts` or `etc/resolv.conf` *inside* the base template directory,
these can be overlayed into your jail.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in `usr/local`. The few general
exceptions are the `etc/hosts`, `etc/resolv.conf`, and
`etc/rc.conf.local`.

After populating `usr/local/` with custom config files that your jail will
use, be sure to include `usr` in the template CONFIG definition. eg;

.. code-block:: shell

  echo "etc usr" > /usr/local/bastille/templates/base/CONFIG

The above example "etc usr" will include anything under "etc" and "usr"
inside the template. You do not need to list individual files. Just
include the top-level directory name.

Applying Templates
------------------

Jails must be running to apply templates.

Bastille includes a `template` command. This command requires a target and a
template name. As covered in the previous section, template names correspond to
directory names in the `bastille/templates` directory.

.. code-block:: shell

  ishmael ~ # bastille template ALL base
  [cdn]:
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  Updating iniquity.io repository catalogue...
  [cdn] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [cdn] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  iniquity.io repository update completed. 499 packages processed.
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
  
  [poudriere]:
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  Updating cdn.iniquity.io repository catalogue...
  [poudriere] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [poudriere] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  cdn.iniquity.io repository update completed. 499 packages processed.
  Updating iniquity.io repository catalogue...
  [poudriere] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [poudriere] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  iniquity.io repository update completed. 499 packages processed.
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

