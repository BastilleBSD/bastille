Usage
=====

.. code-block:: shell

    ishmael ~ # bastille help
    Bastille is an open-source system for automating deployment and management of
    containerized applications on FreeBSD.

  Usage:
    bastille command [options(s)] TARGET [option(s)] [args]

  Available Commands:
    bootstrap   Bootstrap a release for jail base.
    clone       Clone an existing jail.
    cmd         Execute arbitrary command on targeted jail(s).
    config      Get, set or remove a config value for the targeted jail(s).
    console     Console into a jail.
    convert     Convert thin jail to thick jail, or convert a jail to a custom release.
    cp          cp(1) files from host to targeted jail(s).
    create      Create a jail.
    destroy     Destroy a jail or release.
    edit        Edit jail configuration files (advanced).
    export      Export a jail.
    help        Help about any command.
    htop        Interactive process viewer (requires htop).
    import      Import a jail.
    jcp         cp(1) files from a jail to jail(s).
    limits      Apply resources limits to targeted jail(s). See rctl(8) and cpuset(1).
    list        List jails, releases, templates and more...
    migrate     Migrate targeted jail(s) to a remote system.
    mount       Mount a volume inside targeted jail(s).
    network     Add or remove interfaces from targeted jail(s).
    pkg         Manipulate binary packages within targeted jail(s). See pkg(8).
    rcp         cp(1) files from a jail to host.
    rdr         Redirect host port to jail port.
    rename      Rename a jail.
    restart     Restart a jail.
    service     Manage services within targeted jail(s).
    setup       Attempt to auto-configure network, firewall and storage and more...
    start       Start a stopped jail.
    stop        Stop a running jail.
    sysrc       Safely edit rc files within targeted jail(s).
    tags        Add or remove tags to targeted jail(s).
    template    Apply file templates to targeted jail(s).
    top         Display and update information about the top(1) cpu processes.
    umount      Unmount a volume from targeted jail(s).
    update      Update jail base -pX release.
    upgrade     Upgrade jail release to X.Y-RELEASE.
    verify      Compare release against a "known good" index.
    zfs         Manage (get|set) ZFS attributes on targeted jail(s).

  Use "bastille -v|--version" for version information.
  Use "bastille command -h|--help" for more information about a command.
  Use "bastille -c|--config config.conf command" to specify a non-default config file.