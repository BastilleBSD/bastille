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
| [H]PKG        | port/pkg name(s)    | vim-console zsh git-lite tree htop      |
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

Note: Due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in ``/usr/local``. The few general exceptions
are the ``/etc/hosts``, ``/etc/resolv.conf``, and ``/etc/rc.conf.local``.

The above example of ``usr`` and ``etc`` will include anything under ``usr`` and
``etc`` inside the template. You do not need to list individual files. Just
include the top-level directory name. List these top-level directories one per line.

Note also: If the path starts with ``/`` it will copy exactly ``/usr`` into the jail, and
not ``project/template/usr``.

``INCLUDE``       - specify a template to include. Make sure the template is
bootstrapped, or you are using the template url

``LIMITS``        - set the specified resource value for the jail

``LINE_IN_FILE``  - add specified word to specified file if not present

``MOUNT``         - mount specified files/directories inside the jail

``PKG``           - install specified packages inside jail

``HPKG``           - install specified packages inside jail using the host pkg

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

Passing ARG Values From a File
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When a template declares a lot of ``ARG`` values, listing them all on the
command line with repeated ``--arg NAME=VALUE`` flags becomes unwieldy. The
``template`` sub-command accepts a ``--arg-file`` option that points at a
plain-text file containing the values.

.. code-block:: shell

  ishmael ~ # bastille template TARGET project/template --arg-file /path/to/args.env

The file must already exist; Bastille will exit with
``[ERROR]: File not found: <path>`` otherwise.

Each line in the file is a ``NAME=VALUE`` pair, one ``ARG`` per line. The
``NAME`` portion must start at the beginning of the line (Bastille looks up
each ``ARG`` with an anchored match on ``^NAME=``), and ``VALUE`` is
everything that follows the first ``=``.

.. code-block:: shell

  # /path/to/args.env
  MINECRAFT_MEMX=2048M
  MINECRAFT_MEMS=2048M

Lines that do not begin with ``NAME=`` (for example blank lines or shell-style
comments) are ignored because they cannot match the anchored lookup, so they
are safe to include for readability. An ``ARG`` whose name does not appear in
the file simply falls through to its default.

For any given ``ARG NAME`` referenced inside the Bastillefile, the value is
resolved in this order:

1. ``--arg NAME=VALUE`` passed on the command line (highest priority).
2. A ``^NAME=`` line found in the ``--arg-file``.
3. The default value supplied next to the ``ARG`` declaration in the
   Bastillefile (lowest priority).

This means you can keep a baseline of values in a file and selectively
override any of them on the command line without editing the file:

.. code-block:: shell

  ishmael ~ # bastille template azkaban games/minecraft-server \
      --arg-file /etc/bastille/minecraft.env \
      --arg MINECRAFT_MEMX=4096M

In the example above every ``ARG`` is sourced from ``minecraft.env`` except
``MINECRAFT_MEMX``, which is taken from the explicit ``--arg`` flag.

* Only the first ``--arg-file`` on the command line is honored; subsequent
  occurrences are ignored.
* The path is read on each ``ARG`` lookup, so the file must remain readable
  for the duration of the template run.
* Values are passed through the same escaping logic as ``--arg``, so the
  rule from `Special Hook Cases`_ applies — an ampersand "\``&``" in a value
  is treated literally and must not be escaped.