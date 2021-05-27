Usage
=====

.. code-block:: shell

    ishmael ~ # bastille help
    Bastille is an open-source system for automating deployment and management of
    containerized applications on FreeBSD.

    Usage:
      bastille command TARGET [args]

    Available Commands:
      bootstrap   Bootstrap a FreeBSD release for container base.
      cmd         Execute arbitrary command on targeted container(s).
      clone       Clone an existing container.
      config      Get or set a config value for the targeted container(s).
      console     Console into a running container.
      convert     Convert a Thin container into a Thick container.
      cp          cp(1) files from host to targeted container(s).
      create      Create a new thin container or a thick container if -T|--thick option specified.
      destroy     Destroy a stopped container or a FreeBSD release.
      edit        Edit container configuration files (advanced).
      export      Exports a specified container.
      help        Help about any command.
      htop        Interactive process viewer (requires htop).
      import      Import a specified container.
      limits      Apply resources limits to targeted container(s). See rctl(8).
      list        List containers (running and stopped).
      mount       Mount a volume inside the targeted container(s).
      pkg         Manipulate binary packages within targeted container(s). See pkg(8).
      rdr         Redirect host port to container port (non-VNET jails only).
      rename      Rename a container.
      restart     Restart a running container.
      service     Manage services within targeted container(s).
      start       Start a stopped container.
      stop        Stop a running container.
      sysrc       Safely edit rc files within targeted container(s).
      template    Apply file templates to targeted container(s).
      top         Display and update information about the top(1) cpu processes.
      umount      Unmount a volume from within the targeted container(s).
      update      Update container base -pX release.
      upgrade     Upgrade container release to X.Y-RELEASE.
      verify      Compare release against a "known good" index.
      zfs         Manage (get|set) ZFS attributes on targeted container(s).

    Use "bastille -v|--version" for version information.
    Use "bastille command -h|--help" for more information about a command.

