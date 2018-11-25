=====
Usage
=====

.. code-block:: shell

    ishmael ~ # bastille -h
    Usage:
      bastille command [ALL|glob] [args]
    
    Available Commands:
      bootstrap   Bootstrap a FreeBSD release for jail base.
      cmd         Execute arbitrary command on targeted jail(s).
      console     Console into a running jail.
      cp          cp(1) files from host to targeted jail(s).
      create      Create a new jail.
      destroy     Destroy a stopped jail.
      help        Help about any command
      htop        Interactive process viewer (requires htop).
      list        List jails (running and stopped).
      pkg         Manipulate binary packages within targeted jail(s). See pkg(8).
      restart     Restart a running jail.
      start       Start a stopped jail.
      stop        Stop a running jail.
      sysrc       Safely edit rc files within targeted jail(s).
      template    Apply Bastille template to running jail(s).
      top         Display and update information about the top(1) cpu processes.
      update      Update jail base -pX release.
      upgrade     Upgrade jail release to X.Y-RELEASE.
    
    Use "bastille -v|--version" for version information.
    Use "bastille command -h|--help" for more information about a command.
