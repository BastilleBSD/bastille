Plugins
=======

Bastille added support for running custom plugins in version 1.5.0. Some basic
things need to be in place in order to run a plugin.

First, only Github is supported for now. Create your repo, then create
a ``plugin.conf`` file in the following format:

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

Once you have the above file, start creating your plugin command files. Each command must follow the same
naming convention as Bastille already does. Your command files should be called ``cmd.sh`` including
the ``.sh`` suffix.

Once the command files have been created and placed inside your repository, we can bootstrap
the plugin with ``bastille plugin https://github.com/myuser/myplugin``. This will validate the
manifest file we created (``plugin.conf``) and install the plugin at ``${bastille_sharedir}/plugins/${name}``.
It will name the plugin after the ``name`` variable in ``plugin.conf``, load any kernel
modules, and install any pkgs included in the manifest file.

Once that is done, you can run your plugin using ``bastille plugin myplugin mycmd...``. If your plugin
does not interfere with any of the Bastille commands, you can also do ``bastille p myplugin mycmd...`` as
a shorthand version of the command above.

When the plugin is bootstrapped, the directory structure should be as follows:

.. code-block:: shell

  /usr/local/share/bastille/plugins/myplugin
  /usr/local/share/bastille/plugins/myplugin/plugin.conf
  /usr/local/share/bastille/plugins/myplugin/cmd1.sh
  /usr/local/share/bastille/plugins/myplugin/cmd2.sh
  /usr/local/share/bastille/plugins/myplugin/cmd3.sh

If you want to use any of the Bastille functions, make sure to add the following line to the top
of your command files"

.. code-block:: shell
  
  . /usr/local/share/bastille/common.sh

These include ``info``, ``warn``, ``error_exit`` and more. See the code for details.

You can also develop your own plugin by simply creating a directory
inside ``${bastille_sharedir}/plugins`` and building it out from there. Only
keep in mind the above mentioned requirements.
