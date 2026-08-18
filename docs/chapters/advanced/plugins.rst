Plugins
=======

Bastille added support for running custom plugins in version 1.5.0. A plugin
is simply some additional files located in the plugins directory, which allow
Bastille to be extended beyond what it officially supports.

As of version 1.5.0, these files must be shell scripts, written in POSIX ``sh``.
Some basic things need to be in place in order to run a plugin.

You can either manually build a plugin, or place it on a remote repo (only
Github for now) to be easily bootstrapped to any system.

Plugin Structure
----------------

A plugin is simply a directory inside ``${bastille_sharedir}/plugins`` that include any
number of customized shell scripts. The scripts must end in the ``.sh`` suffix or Bastille
will not recognize them.

If you are planning to place the plugin in a remote repository such as Github, you should
include ``plugin.conf`` at the root of the repo. The ``plugin.conf`` must have the following
contents:

.. code-block:: shell

  name=""
  min_version=""
  depends_kmods=""
  depends_pkgs=""

* name should be the name of your plugin (this will be the directory name inside the plugins directory)
* min_version should most always be set to 1.5.0, as that is the first version to support plugins, but
  can be higher for future additional features
* depends_kmods should include any kernel modules that the plugin might need
* depends_pkgs should include any additional packages the plugin might need

If the ``name`` filed is left blank, the plugin directory will simply be named after the repo name. Also, if
the ``min_version`` is left blank, Bastille will just install the plugin without verifying the version.

The rest of the contents of the plugin directory should include any custom files you so desire. One thing to
note is that the files must end in the ``.sh`` suffix. Bastille first validates the plugin directory, then
checks if the next parameter is a file inside the directory ending in ``.sh``. If it is not, Bastille
will not run the command.

Parameter Order
^^^^^^^^^^^^^^^

Bastille follows a strict parameter order for each of its subcommands. Plugins should follow the same order
to keep things simple. The order is ``COMMAND OPTIONS TARGET ARGS``.

* COMMAND should be your custom plugin command
* OPTIONS should be any flags passed to the command
* TARGET should be the jail or release the command is to act on
* ARGS can be any other parameters passed to the command

In order to demonstrate what a command should look like, we will have a look
at the official ``cmd.sh`` file. This command runs arbitrary commands inside a jail.

.. code-block:: shell

  . /usr/local/share/bastille/common.sh
 
The first line simply sources the file that includes Bastille specific functions.

.. code-block:: shell

  usage() {
      error_notify "Usage: bastille cmd [option(s)] TARGET COMMAND"
      cat << EOF
  
      Options:
  
      -a | --auto      Auto mode. Start/stop jail(s) if required.
  
  EOF
      exit 1
  }
 
This block is a command specific ``usage`` function that can be shown when an error occurs.
 
 .. code-block:: shell
 
  # Handle options
  AUTO=0
  while [ "$#" -gt 0 ]; do
      case "${1}" in
	  -h|--help|help)
	      usage
	      ;;
	  -a|--auto)
	      AUTO=1
	      shift
	      ;;
      -*)
          error_exit "[ERROR]: Unknown Option: \"${1}\"" ;;
  
       *)
          break
          ;;
      esac
  done
  
  # Verify parameter count
  if [ $# -eq 0 ]; then
      usage
  fi

This code handles any options or flags passed to the given command. Once the flags
are parsed, an optional block checks for valid parameter counts for the command. In
the case of ``cmd.sh``, the parameter count can be fairly large, so we simply error
only when none are supplied.

Any flags that apply to the command should immediately follow the command.
Eg: ``bastille plugin myplugin command --flag1 --flag2...``

.. code-block:: shell

  TARGET="${1}"
  shift 1
  ERRORS=0

  bastille_root_check
  set_target "${TARGET}"

Next we set the ``TARGET`` variable. If a command is to target a jail or release, it should
be the next parameter. For example, if I want to target a jail named ``nextcloud`` with my
plugin, and use ``-a|--auto`` mode, we would run the
following: ``bastille plugin myplugin plugincmd --auto nextcloud...``.

The ``set_target`` function takes a single parameter and validates the target exists, then
exports it into two variable called ``TARGET`` and ``JAILS``. The reason we have two, is for
reasons shown in the following code block.

Once you have set the target, you can use ``TARGET`` and ``JAILS`` in your command.

.. code-block:: shell

  for jail in ${JAILS}; do

      # Validate jail state
      check_target_is_running "${jail}" || if [ "${AUTO}" -eq 1 ]; then
          bastille start "${jail}"
      else
          info 1 "\n[${jail}]:"
          error_notify "Jail is not running."
          error_continue "Use [-a|--auto] to auto-start the jail."
      fi
  
      info 1 "\n[${jail}]:"
  
      check_fib "${jail}"
      # Allow executing commands on linux jails
      if grep -qw "linsysfs" "${bastille_jailsdir}/${jail}/fstab"; then
          ${SETFIB} jexec -l -u root "${jail}" "$@"
      else
          ${SETFIB} jexec -l -U root "${jail}" "$@"
      fi
  
      if [ "$?" -ne 0 ]; then
          ERRORS=$((ERRORS + 1))
      fi
  
  done

  if [ "${ERRORS}" -ne 0 ]; then
      error_exit "[ERROR]: Command failed on ${ERRORS} jails."
  fi

The last block of code in the ``cmd.sh`` command runs any code inside each jail
in the ``JAILS`` variable. ``JAILS`` can contain more than one jail, which is why
we do the for loop. There is also a ``set_target_single`` function that will set
only a single target. This goes into the ``TARGET`` parameter.

The ``set_target*`` functions only apply to jails, not releases.

Building a Plugin
-----------------

Before we start buliding a plugin, we must create a directory inside ``${bastille_sharedir}/plugins``
and name it according to our plugins desired name. For example, if my plugin is to be
called ``myplugin``, I would create ``${bastille_sharedir}/plugins/myplugin``.

For this guide, we will assume you are building it locally. Once the directory is in place, we
can start creating our ``*.sh`` files.

When the plugin is built, the directory structure should be as follows:

.. code-block:: shell

  /usr/local/share/bastille/plugins/myplugin
  /usr/local/share/bastille/plugins/myplugin/plugin.conf
  /usr/local/share/bastille/plugins/myplugin/cmd1.sh
  /usr/local/share/bastille/plugins/myplugin/cmd2.sh
  /usr/local/share/bastille/plugins/myplugin/cmd3.sh

The ``plugin.conf`` file will really only be necessary when bootstrapping a plugin from
a remote repo, but its best to include it anyway.

If you decide to create your plugin in a remote repo such as Github, you can bootstrap
the plugin with ``bastille plugin https://github.com/myuser/myplugin``. This will validate the
manifest file we created (``plugin.conf``) and install the plugin at ``${bastille_sharedir}/plugins/${name}``.
It will name the plugin after the ``name`` variable in ``plugin.conf``, load any kernel
modules, and install any pkgs included in the manifest file. If the ``name`` variable
is empty, it will default to the repo name.

Running a Plugin
----------------

Once bootstrapped, you can run your plugin using ``bastille plugin myplugin cmd1.sh``. You
can also do ``bastille p myplugin mycmd...`` as a shorthand version of the command above.

Any options and parameters passed to the plugin should be validate and parsed by the plugin
commands. Bastille is only responsible for passing the plugin name and additional parameters
to whichever plugin command is given.

Functions
---------

If you want to use any of the official Bastille functions, you can add the following
line to the top of your commands.

.. code-block:: shell

  . /usr/local/share/bastille/include

Some functions that might be helpful to use are:

.. code-block:: shell

  bastille_root_check
  info
  warn
  error_exit
  error_continue
  error_notify
  check_target_exists
  check_target_is_running
  check_target_is_stopped

There are obviously more functions, and you will have to browse through the code to discover
how each on is meant to be used.

You can also create you own functions and files and include them inside your plugin in the
same way Bastille does.

Example Plugin
--------------

An example plugin is provided here. We will call this plugin ``custom-restart``.

Inside ``${bastille_sharedir}/plugins/custom-restart`` we have a single file called ``restart.sh`` which
contains the following code:

.. code-block:: shell

  #!/bin/sh

  TARGET="${1}"
  set_target "${TARGET}"

  for jail in ${JAILS}; do
    bastille restart ${jail}
	info 1 "\nSuccessfully restarted ${jail}, moving to the next one..."
  done

I can this command with ``bastille plugin custom-restart ALL``. ``ALL`` here is the target, and
Bastille will target all jail in this case. To target only select jails, we can
run ``bastille plugin custom-restart 'jail1 jail2 jail3'``.

One of the first plugins Bastille supports is found at ``https://github.com/usenix17/bastille-vm-plugin``.

Try bootstrapping it, and see how it was built.

Notes
-----

When uninstalling Bastille, all plugins will be removed also. Make sure to back them up, or
store them remotely if you so choose.
