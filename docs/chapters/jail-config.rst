Note: FreeBSD introduced container technology twenty years ago, long before the
industry standardized on the term "container". Internally, FreeBSD refers to
these containers as "jails".

jail.conf
=========
In this section we'll look at the default config for a new container. The
defaults are sane for most applications, but if you want to tweak the settings
here they are.

A `jail.conf` template is used each time a new container is created. This
template looks like this:

.. code-block:: shell

  {name} {
    devfs_ruleset = 4;
    enforce_statfs = 2;
    exec.clean;
    exec.consolelog = /usr/local/bastille/logs/{name}_console.log;
    exec.start = '/bin/sh /etc/rc';
    exec.stop = '/bin/sh /etc/rc.shutdown';
    host.hostname = {name};
    interface = {interface};
    mount.devfs;
    mount.fstab = /usr/local/bastille/jails/{name}/fstab;
    path = /usr/local/bastille/jails/{name}/root;
    securelevel = 2;

    ip4.addr = x.x.x.x;
    ip6 = disable;
  }


devfs_ruleset
-------------
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
--------------
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
----------
.. code-block:: shell

  exec.clean
    Run commands in a clean environment.  The environment is
    discarded except for HOME, SHELL, TERM and USER.  HOME and SHELL
    are set to the target login's default values.  USER is set to the
    target login.  TERM is imported from the current environment.
    The environment variables from the login class capability
    database for the target login are also set.


exec.consolelog
---------------
.. code-block:: shell

  exec.consolelog
    A file to direct command output (stdout and stderr) to.


exec.start
----------
.. code-block:: shell

  exec.start
    Command(s) to run in the jail environment when a jail is created.
    A typical command to run is "sh /etc/rc".


exec.stop
---------
.. code-block:: shell

  exec.stop
    Command(s) to run in the jail environment before a jail is
    removed, and after any exec.prestop commands have completed.  A
    typical command to run is "sh /etc/rc.shutdown".


host.hostname
-------------
.. code-block:: shell

  host.hostname
    The hostname of the jail.  Other similar parameters are
    host.domainname, host.hostuuid and host.hostid.


interface
---------
.. code-block:: shell

  interface
    A network interface to add the jail's IP addresses (ip4.addr and
    ip6.addr) to.  An alias for each address will be added to the
    interface before the jail is created, and will be removed from
    the interface after the jail is removed.


mount.devfs
-----------
.. code-block:: shell

  mount.devfs
    Mount a devfs(5) filesystem on the chrooted /dev directory, and
    apply the ruleset in the devfs_ruleset parameter (or a default of
    ruleset 4: devfsrules_jail) to restrict the devices visible
    inside the jail.


mount.fstab
-----------
.. code-block:: shell

  mount.fstab
    An fstab(5) format file containing filesystems to mount before
    creating a jail.


path
----
.. code-block:: shell

  path
    The directory which is to be the root of the jail.  Any commands
    run inside the jail, either by jail or from jexec(8), are run
    from this directory.


securelevel
-----------
By default, Bastille containers run at `securelevel = 2;`. See below for the
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
