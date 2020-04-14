Usage
=====

.. code-block:: shell

    ishmael ~ # bastille -h
    Bastille is an open-source system for automating deployment and management of
    containerized applications on FreeBSD.

    Usage:
      bastille command [ALL|glob] [args]

    Available Commands:
      bootstrap   Bootstrap a FreeBSD release for container base.
      cmd         Execute arbitrary command on targeted container(s).
      console     Console into a running container.
      cp          cp(1) files from host to targeted container(s).
      create      Create a new thin container or a thick container if -T|--thick option specified.
      destroy     Destroy a stopped container or a FreeBSD release.
      help        Help about any command
      htop        Interactive process viewer (requires htop).
      list        List containers, releases, templates, or logs.
      pkg         Manipulate binary packages within targeted container(s). See pkg(8).
      restart     Restart a running container.
      service     Manage services within targeted containers(s).
      start       Start a stopped container.
      stop        Stop a running container.
      sysrc       Safely edit rc files within targeted container(s).
      template    Apply file templates to targeted container(s).
      top         Display and update information about the top(1) cpu processes.
      update      Update container base -pX release.
      upgrade     Upgrade container release to X.Y-RELEASE.
      verify      Compare release against a "known good" index.
      zfs         Manage (get|set) zfs attributes on targeted container(s).

    Use "bastille -v|--version" for version information.
    Use "bastille command -h|--help" for more information about a command.
