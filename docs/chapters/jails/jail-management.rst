Jail Management
===============

Bastille allows users to have full control over a host of jail management tools.
For a full list of commands and what they can do, See :doc:`/chapters/subcommands`.

Creating a Jail
---------------

Creating a jail is done with ``bastille create``. There are many options included
that allow you to specify jail type, networking option, and much more.

Jails can be renamed, cloned, exported, imported, started, stopped, restarted, and
basically anything you can think a jail would need.

Destroying a Jail
-----------------

Once you no longer have need of a jail, you can use the ``bastille destroy`` command
to completey remove it from your system. The destroy command will ask if you are sure
you want to destroy it, unless you specify the ``-y|--yes`` flag.

Auto Mode
---------

Most, is not all Bastille commands require a jail to be in a certain state (running or stopped)
before the command can be executed. This is sometimes a bit of a hinderance, so we
include an ``-a|--auto`` flag. If a jail needs to be running/stopped before a command can
continue, Bastille will first start/stop it if the ``-a|--auto`` flag is given.