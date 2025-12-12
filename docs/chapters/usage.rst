Usage
=====

.. code-block:: shell

    ishmael ~ # bastille help
    Bastille is an open-source system for automating deployment and management of
    containerized applications on FreeBSD.

  Usage:
    bastille [option(s)] command [option(s)] TARGET ARGS

  Available Commands:
    bootstrap   Bootstrap a release or template(s).
    clone       Clone an existing jail.
    cmd         Execute command(s) inside jail(s).
    config      Get, set, add or remove properties from jail(s).
    console     Console into a jail.
    convert     Convert a jail from thin to thick; convert a jail to a custom release.
    cp          Copy file(s)/directorie(s) from host to jail(s).
    create      Create a jail.
    destroy     Destroy jail(s) or release(s).
    edit        Edit jail configuration files (advanced).
    etcupdate   Update /etc for jail(s).
    export      Export a jail.
    help        Help for any command.
    htop        Interactive process viewer (requires htop).
    import      Import a jail.
    jcp         Copy file(s)/directorie(s) from jail to jail(s).
    limits      Apply resources limits to jail(s). See rctl(8) and cpuset(1).
    list        List jails, releases, templates and more...
    migrate     Migrate jail(s) to a remote system.
    monitor     Monitor and attempt to restart jail service(s).
    mount       Mount file(s)/directorie(s) inside jail(s).
    network     Add or remove interface(s) from jail(s).
    pkg         Manage packages inside jail(s). See pkg(8).
    rcp         Copy file(s)/directorie(s) from jail to host.
    rdr         Redirect host port to jail port.
    rename      Rename a jail.
    restart     Restart a jail.
    service     Manage services within jail(s).
    setup       Auto-configure network, firewall, storage and more...
    start       Start stopped jail(s).
    stop        Stop running jail(s).
    sysrc       Edit rc files inside jail(s).
    tags        Add or remove tags to jail(s).
    template    Apply templates to jail(s).
    top         Process viewer. See top(1).
    umount      Unmount file(s)/directorie(s) from jail(s).
    update      Update a jail or release.
    upgrade     Upgrade a jail to new release.
    verify      Compare release against a "known good" index.
    zfs         Manage ZFS options/attributes for jail(s).

  Use "bastille -v|--version" for version information.
  Use "bastille command -h|--help" for more information about a command.
  Use "bastille -c|--config FILE command" to specify a non-default config file.
