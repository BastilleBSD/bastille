Configuration
=============

Bastille is configured using a default config file located at
``/usr/local/etc/bastille/bastille.conf``. When first installing bastille, you
should run ``bastille setup``. This will ask if you want to copy the sample
config file to the above location. The defaults are sensible for UFS, but
if you use ZFS, ``bastille setup`` will configure it for you. If you have
multiple zpools, Bastille will ask which one you want to use. See also 
:doc:`/chapters/zfs-support`.

This is the default `bastille.conf` file.

.. code-block:: shell

  #####################
  ## [ BastilleBSD ] ##
  #####################

  ## default paths
  bastille_prefix="/usr/local/bastille"                                 ## default: "/usr/local/bastille"
  bastille_backupsdir="${bastille_prefix}/backups"                      ## default: "${bastille_prefix}/backups"
  bastille_cachedir="${bastille_prefix}/cache"                          ## default: "${bastille_prefix}/cache"
  bastille_jailsdir="${bastille_prefix}/jails"                          ## default: "${bastille_prefix}/jails"
  bastille_releasesdir="${bastille_prefix}/releases"                    ## default: "${bastille_prefix}/releases"
  bastille_templatesdir="${bastille_prefix}/templates"                  ## default: "${bastille_prefix}/templates"
  bastille_logsdir="/var/log/bastille"                                  ## default: "/var/log/bastille"

  ## pf configuration path
  bastille_pf_conf="/etc/pf.conf"                                       ## default: "/etc/pf.conf"

  ## bastille scripts directory (assumed by bastille pkg)
  bastille_sharedir="/usr/local/share/bastille"                         ## default: "/usr/local/share/bastille"

  ## bootstrap archives, which components of the OS to install.
  ## base  - The base OS, kernel + userland
  ## lib32 - Libraries for compatibility with 32 bit binaries
  ## ports - The FreeBSD ports (3rd party applications) tree
  ## src   - The source code to the kernel + userland
  ## test  - The FreeBSD test suite
  ## this is a whitespace separated list:
  ## bastille_bootstrap_archives="base lib32 ports src test"
  bastille_bootstrap_archives="base"                                    ## default: "base"

  ## pkgbase package sets (used for FreeBSD 15+)
  ## Any set with [-dbg] can be installed with debugging
  ## symbols by adding '-dbg' to the package set
  ## base[-dbg]          - Base system
  ## base-jail[-dbg]     - Base system for jails
  ## devel[-dbg]         - Development tools
  ## kernels[-dbg]       - Base system kernels
  ## lib32[-dbg]         - 32-bit compatability libraries
  ## minimal[-dbg]       - Basic multi-user system
  ## minimal-jail[-dbg]  - Basic multi-user jail system
  ## optional[-dbg]      - Optional base system software
  ## optional-jail[-dbg] - Optional base system software for jails
  ## src                 - System source code
  ## tests               - System test suite
  ## Whitespace separated list:
  ## bastille_pkgbase_packages="base-jail lib32-dbg src"
  bastille_pkgbase_packages="base-jail"                                 ## default: "base-jail"

  ## default timezone
  bastille_tzdata=""                                                    ## default: empty to use host's time zone

  ## default jail resolv.conf
  bastille_resolv_conf="/etc/resolv.conf"                               ## default: "/etc/resolv.conf"

  ## bootstrap urls
  bastille_url_freebsd="http://ftp.freebsd.org/pub/FreeBSD/releases/"          ## default: "http://ftp.freebsd.org/pub/FreeBSD/releases/"
  bastille_url_hardenedbsd="https://installers.hardenedbsd.org/pub/" ## default: "https://installer.hardenedbsd.org/pub/HardenedBSD/releases/"
  bastille_url_midnightbsd="https://www.midnightbsd.org/ftp/MidnightBSD/releases/"          ## default: "https://www.midnightbsd.org/pub/MidnightBSD/releases/"

  ## ZFS options
  bastille_zfs_enable="NO"                                              ## default: "NO"
  bastille_zfs_zpool=""                                                 ## default: ""
  bastille_zfs_prefix="bastille"                                        ## default: "bastille"
  bastille_zfs_options="-o compress=lz4 -o atime=off"                   ## default: "-o compress=lz4 -o atime=off"

  ## Export/Import options
  bastille_compress_xz_options="-0 -v"                                  ## default "-0 -v"
  bastille_decompress_xz_options="-c -d -v"                             ## default "-c -d -v"
  bastille_compress_gz_options="-1 -v"                                  ## default "-1 -v"
  bastille_decompress_gz_options="-k -d -c -v"                          ## default "-k -d -c -v"
  bastille_export_options=""                                            ## default "" predefined export options, e.g. "--safe --gz"

  ## Networking
  bastille_network_loopback="bastille0"                                 ## default: "bastille0"
  bastille_network_pf_ext_if="ext_if"                                   ## default: "ext_if"
  bastille_network_pf_table="jails"                                     ## default: "jails"
  bastille_network_shared=""                                            ## default: ""
  bastille_network_gateway=""                                           ## default: ""
  bastille_network_gateway6=""                                          ## default: ""

  ## Default Templates
  bastille_template_base="default/base"                                 ## default: "default/base"
  bastille_template_empty=""                                            ## default: "default/empty"
  bastille_template_thick="default/thick"                               ## default: "default/thick"
  bastille_template_clone="default/clone"                               ## default: "default/clone"
  bastille_template_thin="default/thin"                                 ## default: "default/thin"
  bastille_template_vnet="default/vnet"                                 ## default: "default/vnet"
  bastille_template_vlan="default/vlan"                                 ## default: "default/vlan"

  ## Monitoring
  bastille_monitor_cron_path="/usr/local/etc/cron.d/bastille-monitor"                           ## default: "/usr/local/etc/cron.d/bastille-monitor"
  bastille_monitor_cron="*/5 * * * * root /usr/local/bin/bastille monitor ALL >/dev/null 2>&1"  ## default: "*/5 * * * * root /usr/local/bin/bastille monitor ALL >/dev/null 2>&1"
  bastille_monitor_logfile="${bastille_logsdir}/monitor.log"                                    ## default: "${bastille_logsdir}/monitor.log"
  bastille_monitor_healthchecks=""                                                              ## default: ""


Notes
-----

The options here are fairly self-explanitory, but there are some things to note.

* If you use ZFS, DO NOT create the bastille dataset. You must only create the
  parent. Bastille must be allowed to create the ``bastille`` child dataset, or
  you will have issues. So, if you want bastille to live at
  ``zroot/data/bastille`` you should set ``bastille_zfs_zpool`` to ``zroot`` and
  ``bastille_zfs_prefix`` to ``data/bastille`` but you should only create
  ``zroot/data`` before running bastille for the first time.

* Bastille will mount the dataset it creates at ``bastille_prefix`` which
  defaults to ``/usr/local/bastille``. So if you want to navigate to your jails,
  you will use the ``bastille_prefix`` as the location because this is where the
  will be mounted.

Custom Configuration
--------------------

Bastille supports using a custom config in addition to the default one. This
is nice if you have multiple users, or want to store different
jails at different locations based on your needs.

The customized config file MUST BE PLACED INSIDE THE BASTILLE CONFIG FOLDER at
``/usr/local/etc/bastille`` or it will not work.

Simply copy the default config file and edit it according to your new
environment or user. Then, it can be used in a couple of ways.

1. Run Bastille using ``bastille --config config.conf bootstrap 14.2-RELEASE``
   to bootstrap the release using the new config.

2. As a specific user, export the ``BASTILLE_CONFIG`` variable using ``export
   BASTILLE_CONFIG=config.conf``. This config will then always be used when
   running Bastille with that user. See notes below...

- Exporting the ``BASTILLE_CONFIG`` variable will only export it for the current session. If you want to persist the export, see documentation for the shell that you use.

- If you use sudo, you will need to run it with ``sudo -E bastille bootstrap...`` to preserve your users environment. This can also be persisted by editing the sudoers file.

- If you do set the ``BASTILLE_CONFIG`` variable, you do not need to specify the config file when running Bastille as that specified user.

Note: FreeBSD introduced container technology twenty years ago, long before the
industry standardized on the term "container". Internally, FreeBSD refers to
these containers as "jails".

Jail Startup Configuration
--------------------------

Bastille can start jails on system startup, and stop them on system shutdown.
To enable this functionality, we must first enable Bastille as a service using
``sysrc bastille_enable=YES``. Once you reboot your host, all jails with
``boot=on`` will be started when the host boots.

If you have certain jails that must be started before other jails, you can use
the priority option. Jails will start in order starting at the lowest value, and
will stop in order starting at the highest value. So, jails with a priority value
of 1 will start first, and stop last.

See :doc:`/chapters/targeting` for more info.

Boot
^^^^

The boot setting controls whether a jail will be started on system startup. If
you have enabled bastille with ``sysrc bastille_enable=YES``, all jails with
``boot=on`` will start on system startup. Any jail(s) with ``boot=off`` will not
be started on system startup.

By default, when jails are created with Bastille, the boot setting is set to ``on``
by default. This can be overridden using the ``--no-boot`` flag.
See ``bastille create --no-boot TARGET...``.

You can also use ``bastille start --boot TARGET`` to make Bastille respect the
boot setting. If ``-b|--boot`` is not used, the targeted jail(s) will start,
regardless of the boot setting.

Jails will still shut down on system shutdown, regardless of this setting.

The ``-b|--boot`` can also be used with the ``stop`` command. Any jails with
``boot=off`` will not be touched if ``stop`` is called with ``-b|--boot``. Same
goes for the ``restart`` command.

This value can be changed using ``bastille config TARGET set boot [on|off]``.

This value will be shown using ``bastille list all``.

Depend
^^^^^^

Bastille supports configuring jails to depend on each other when started and
stopped. If jail1 "depends" on jail2, then jail2 will be started if it is not
running when ``bastille start jail1`` is called. Any jail that jail1 "depends"
on will first be verified running (started if stopped) before jail1 is started.

For example, I have 3 jails called nginx, mariadb and nextcloud. I want to
ensure that nginx and mariadb are running before nextcloud is started.

First we must add both jails to nextcloud's depend property with
``bastille config nextcloud set depend "mariadb nginx"``.
Then, when we start nextcloud with ``bastille start nextcloud`` it will verify
that nginx and mariadb are running (start if stopped) before starting nextcloud.

When stopping a jail, any jail that "depends" on it will first be stopped.
For example, if we run ``bastille stop nginx``, then nextcloud will first be
stopped because it "depends" on nginx.

Note that if we do a ``bastille restart nginx``, however, nextcloud will be
stopped, because it "depends" on nginx, but will not be started again, because
the jail we just restarted, nginx, does not depend on nextcloud.

Parallel Startup
^^^^^^^^^^^^^^^^

Bastille supports starting, stopping and restarting jails in parallel mode using
the ``rc`` service script. To enable this functionality, set
``bastille_parallel_limit`` to a numeric value.

For example, if you run ``sysrc bastille_parallel_limit=4``, then Bastille will
start 4 jails at a time on system startup, as well as stop or restart 4 jails at
a time when ``service bastille...`` is called.

This value is set to 1 by default, to only start/stop/restart jails one at a time.

Startup Delay
^^^^^^^^^^^^^

Sometimes it is necessary to let a jail start fully before continuing to the
next jail.

We can do this with another sysrc value called ``bastille_startup_delay``.
Setting ``bastille_startup_delay=5`` will tell Bastille to wait 5 seconds between
starting each jail.

You can also use ``bastille start -d|--delay 5 all`` or
``bastille restart -d|--delay 5 all`` to achieve the same thing.

jail.conf
---------

In this section we'll look at the default config for a new container. The
defaults are sane for most applications, but if you want to tweak the settings
here they are.

A ``jail.conf`` template is used each time a new container is created. This
template looks like this:

.. code-block:: shell

  {name} {
    devfs_ruleset = 4;
    enforce_statfs = 2;
    exec.clean;
    exec.consolelog = /var/log/bastille/{name}_console.log;
    exec.start = '/bin/sh /etc/rc';
    exec.stop = '/bin/sh /etc/rc.shutdown';
    host.hostname = {name};
    interface = {interface};
    mount.devfs;
    mount.fstab = /usr/local/bastille/jails/{name}/fstab;
    path = /usr/local/bastille/jails/{name}/root;
    securelevel = 2;

    ip4.addr = interface|x.x.x.x;
    ip6 = disable;
  }


devfs_ruleset
^^^^^^^^^^^^^

.. code-block:: shell

  devfs_ruleset
    The number of the devfs ruleset that is enforced for mounting
    devfs in this jail.  A value of zero (default) means no ruleset
    is enforced.  Descendant jails inherit the parent jail's devfs
    ruleset enforcement.  Mounting devfs inside a jail is possible
    only if the allow.mount and allow.mount.devfs permissions are
    effective and enforce_statfs is set to a value lower than 2.
    Devfs rules and rulesets cannot be viewed or modified from inside
    a jail.

    NOTE: It is important that only appropriate device nodes in devfs
    be exposed to a jail; access to disk devices in the jail may
    permit processes in the jail to bypass the jail sandboxing by
    modifying files outside of the jail.  See devfs(8) for
    information on how to use devfs rules to limit access to entries
    in the per-jail devfs.  A simple devfs ruleset for jails is
    available as ruleset #4 in /etc/defaults/devfs.rules.


enforce_statfs
^^^^^^^^^^^^^^

.. code-block:: shell

  enforce_statfs
    This determines what information processes in a jail are able to
    get about mount points.  It affects the behaviour of the
    following syscalls: statfs(2), fstatfs(2), getfsstat(2), and
    fhstatfs(2) (as well as similar compatibility syscalls).  When
    set to 0, all mount points are available without any
    restrictions.  When set to 1, only mount points below the jail's
    chroot directory are visible.  In addition to that, the path to
    the jail's chroot directory is removed from the front of their
    pathnames.  When set to 2 (default), above syscalls can operate
    only on a mount-point where the jail's chroot directory is
    located.


exec.clean
^^^^^^^^^^

.. code-block:: shell

  exec.clean
    Run commands in a clean environment.  The environment is
    discarded except for HOME, SHELL, TERM and USER.  HOME and SHELL
    are set to the target login's default values.  USER is set to the
    target login.  TERM is imported from the current environment.
    The environment variables from the login class capability
    database for the target login are also set.


exec.consolelog
^^^^^^^^^^^^^^^

.. code-block:: shell

  exec.consolelog
    A file to direct command output (stdout and stderr) to.


exec.start
^^^^^^^^^^

.. code-block:: shell

  exec.start
    Command(s) to run in the jail environment when a jail is created.
    A typical command to run is "sh /etc/rc".


exec.stop
^^^^^^^^^

.. code-block:: shell

  exec.stop
    Command(s) to run in the jail environment before a jail is
    removed, and after any exec.prestop commands have completed.  A
    typical command to run is "sh /etc/rc.shutdown".


host.hostname
^^^^^^^^^^^^^

.. code-block:: shell

  host.hostname
    The hostname of the jail.  Other similar parameters are
    host.domainname, host.hostuuid and host.hostid.


mount.devfs
^^^^^^^^^^^

.. code-block:: shell

  mount.devfs
    Mount a devfs(5) filesystem on the chrooted /dev directory, and
    apply the ruleset in the devfs_ruleset parameter (or a default of
    ruleset 4: devfsrules_jail) to restrict the devices visible
    inside the jail.


mount.fstab
^^^^^^^^^^^

.. code-block:: shell

  mount.fstab
    An fstab(5) format file containing filesystems to mount before
    creating a jail.


path
^^^^

.. code-block:: shell

  path
    The directory which is to be the root of the jail.  Any commands
    run inside the jail, either by jail or from jexec(8), are run
    from this directory.


securelevel
^^^^^^^^^^^

By default, Bastille containers run at ``securelevel = 2;``. See below for the
implications of kernel security levels and when they might be altered.

Note: Bastille does not currently have any mechanism to automagically change
securelevel settings. My recommendation is this only be altered manually on a
case-by-case basis and that "Highly secure mode" is a sane default for most use
cases.

.. code-block:: shell

  The kernel runs with five different security levels.  Any super-user
  process can raise the level, but no process can lower it.  The security
  levels are:

  -1    Permanently insecure mode - always run the system in insecure mode.
        This is the default initial value.

  0     Insecure mode - immutable and append-only flags may be turned off.
        All devices may be read or written subject to their permissions.

  1     Secure mode - the system immutable and system append-only flags may
        not be turned off; disks for mounted file systems, /dev/mem and
        /dev/kmem may not be opened for writing; /dev/io (if your platform
        has it) may not be opened at all; kernel modules (see kld(4)) may
        not be loaded or unloaded.  The kernel debugger may not be entered
        using the debug.kdb.enter sysctl.  A panic or trap cannot be forced
        using the debug.kdb.panic and other sysctl's.

  2     Highly secure mode - same as secure mode, plus disks may not be
        opened for writing (except by mount(2)) whether mounted or not.
        This level precludes tampering with file systems by unmounting
        them, but also inhibits running newfs(8) while the system is multi-
        user.

        In addition, kernel time changes are restricted to less than or
        equal to one second.  Attempts to change the time by more than this
        will log the message "Time adjustment clamped to +1 second".

  3     Network secure mode - same as highly secure mode, plus IP packet
        filter rules (see ipfw(8), ipfirewall(4) and pfctl(8)) cannot be
        changed and dummynet(4) or pf(4) configuration cannot be adjusted.
