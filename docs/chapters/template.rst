Templates
=========

Looking for ready made CI/CD validated `Bastille Templates`_?

Bastille features a template system, allowing you to automate just about anything
from executing arbitrary commands to copying files all with a simple file called a
Bastillefile. A template is applied by running ``bastille template TARGET project/template``
and can also be applied to multiple targets in one go.

Before we dive into creating templates, lets take a look at the supported hooks, as
well as a brief overview of what each one is capable of.

Template Hooks
--------------

The following table shows a list of supported template hooks, their format, and
one example of how you might use each one.

+---------------+---------------------+-----------------------------------------+
| HOOK          | format              | example                                 |
+===============+=====================+=========================================+
| ARG[+]        | ARG=VALUE           | MINECRAFT_MEMX="1024M"                  |
+---------------+---------------------+-----------------------------------------+
| CMD           | /bin/sh command     | /usr/bin/chsh -s /usr/local/bin/zsh     |
+---------------+---------------------+-----------------------------------------+
| CONFIG        | set property value  | set allow.mlock 1                       |
+---------------+---------------------+-----------------------------------------+
| CP            | path(s)             | etc root usr                            |
+---------------+---------------------+-----------------------------------------+
| INCLUDE       | template path/URL   | http?://TEMPLATE_URL or project/path    |
+---------------+---------------------+-----------------------------------------+
| LIMITS        | resource value      | memoryuse 1G                            |
+---------------+---------------------+-----------------------------------------+
| LINE_IN_FILE  | line path           | word /usr/local/word/word.conf          |
+---------------+---------------------+-----------------------------------------+
| MOUNT         | fstab syntax        | /host/path /jail/path nullfs ro 0 0     |
+---------------+---------------------+-----------------------------------------+
| PKG           | port/pkg name(s)    | vim-console zsh git-lite tree htop      |
+---------------+---------------------+-----------------------------------------+
| RDR           | tcp port port       | tcp 2200 22 (proto hostport jailport)   |
+---------------+---------------------+-----------------------------------------+
| RENDER        | /path/file.txt      | /usr/local/etc/gitea/conf/app.ini       |
+---------------+---------------------+-----------------------------------------+
| RESTART       |                     |                                         |
+---------------+---------------------+-----------------------------------------+
| SERVICE       | service command     | 'nginx start' OR 'postfix reload'       |
+---------------+---------------------+-----------------------------------------+
| SYSRC         | sysrc command(s)    | nginx_enable=YES                        |
+---------------+---------------------+-----------------------------------------+
| TAGS          | tag1 tag2 tag3      | prod web                                |
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

``ARG+``          - the ``+`` makes the ``ARG`` mandatory

``CMD``           - run the specified command

``CONFIG``        - set the specified property and value

``CP``            - copy specified files from template directory to specified path inside jail

The ``CP`` hook will recursively copy all of the specified directories from the
``project/template`` directory into the jail. If you have ``CP usr etc`` for
example, it will recursively copy ``project/template/usr`` and ``project/template/etc``
into ``/usr`` and ``/etc`` of the jail directory.

So, if you have ``project/template/usr/local/share/myapp.conf``, it will be copied into the
jail, and placed at ``/usr/local/share/myapp.conf``.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in ``/usr/local``. The few general exceptions
are the ``/etc/hosts``, ``/etc/resolv.conf``, and ``/etc/rc.conf.local``.

The above example of ``usr`` and ``etc`` will include anything under ``usr`` and
``etc`` inside the template. You do not need to list individual files. Just
include the top-level directory name. List these top-level directories one per line.

``INCLUDE``       - specify a template to include. Make sure the template is
bootstrapped, or you are using the template url

``LIMITS``        - set the specified resource value for the jail

``LINE_IN_FILE``  - add specified word to specified file if not present

``MOUNT``         - mount specified files/directories inside the jail

``PKG``           - install specified packages inside jail

``RDR``           - redirect specified ports to the jail

There are two versions of the ``RDR`` hook:

* Simple: proto hostport jailport, as shown in the table above
* Advanced: [ipv4 ip46 dual] interface source-ip dest-ip proto hostport jailport

An example of the advanced ``RDR``:

``RDR ipv4 vtnet0 192.168.0.1 any tcp 2022 22``

This forwards port 22 in the jail to port 2022 on the host, allowing only connections from 
192.168.0.1, an IP address external to the host, all other IPs will be denied.

Note that ``dual`` can only be used if both source-ip and dest-ip are ``any``.

``RENDER``        - replace ARG values inside specified files inside the jail

If a directory is specified here, ARGS will be replaced in all files underneath, or
recursively.

``RESTART``       - restart the jail

``SERVICE``       - run `service` command inside the jail with specified arguments

``SYSRC``         - run `sysrc` inside the jail with specified arguments

``TAGS``          - adds specified tags to the jail

Pro Tip: Most Bastille commands can be placed inside the Bastillefile. But only the above
listed hooks are tested and supported officially. It is also possible to formulate any
regular Bastille command to be run by the template. The following example will clarify...

.. code-block:: shell

  RDR reset
  NETWORK add vtnet1 DHCP

The above snippet, when included in a template will essentially run ``bastille rdr TARGET reset``
and ``bastille network TARGET add vtnet1 DHCP`` inside the jail respectively. Although not fully
tested and documented, they should still work as expected.

Special Hook Cases
------------------

``ARG`` will always treat an ampersand "\``&``" literally, without the need to
escape it. Escaping it will cause errors.

Bootstrapping Templates
-----------------------

The official templates for Bastille are all on Gthub, and mirror the directory
structure of the ports tree.  So, ``nginx`` is in the ``www`` directory in the
templates repo, just like it is in the FreeBSD ports tree.  To bootstrap the
entire set of official templates, run the following command:

.. code-block:: shell

   bastille bootstrap https://github.com/bastillebsd/templates

This will bootstrap all official templates into the templates directory at
``/usr/local/bastille/templates``. You can then use the ``bastille template``
command to apply any of the templates.

.. code-block:: shell

   bastille template TARGET www/nginx

Creating Templates
------------------

Templates should be created and placed inside the templates directory in the
``project/template`` format. Alternatively you can run the ``bastille template``
command from a relative path, making sure it is still in the above ``project/template``
format.

Place any uppercase template hook into ``project/template/Bastillefile`` in any
order to automate jail setup as needed.

Any files included in the ``project/template`` directory can be copied into the jail
using the ``CP`` hook. For example, if I have ``project/template/usr/local/etc/custom.conf``
I can use the following template to copy the entire contents of ``usr`` into my jail.
Bastille will not overwrite ``/usr`` inside the jail. It only copies the files in.

.. code-block:: shell

  CP usr /

See `Bastille Templates`_ for examples to get started on writing your own templates.

Applying Templates
------------------

To apply a template to a jail, run the following command.

.. code-block:: shell

  ishmael ~ # bastille template ALL project/template
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

Notice that if we choose ``ALL`` as the target, the template is applied to all jails.
See :doc:`/chapters/targeting` for more details on targeting jails.

Using Ports in Templates
------------------------

Sometimes when creating a template, we need special options for a package, or
a newer version than pkg offers. The solution for such
cases, or a case like ``minecraft-server`` which has NO compiled option, is to use
ports. A working example of this is the ``minecraft-server`` template in the
template repo.  The main lines needed to use this is first to mount the ports
directory, then compile the port.  Below is an example of the ``minecraft-server``
template where this was used.

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

The ``MOUNT`` line mounts the ports directory, then the ``CMD`` make line makes the
port. This can be modified to use any port in the ports tree.
