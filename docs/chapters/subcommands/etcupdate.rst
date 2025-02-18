=========
etcupdate
=========

This command will update the contents of `/etc` inside a jail. It should be run after a jail upgrade

First we need to bootstrap a release for `etcupdate` to use.

.. code-block:: shell

  ishmael ~ # bastille etcupdate bootstrap 14.1-RELEASE
  bastille_bootstrap_archives: base -> src
  /usr/local/bastille/cache/14.1-RELEASE/MANIFES        1046  B 1134 kBps    00s
  /usr/local/bastille/cache/14.1-RELEASE/src.txz         205 MB 2711 kBps 01m18s
  bastille_bootstrap_archives: src -> base
  Building tarball, please wait...
  Etcupdate bootstrap complete: 14.1-RELEASE

Next we can use the `update` command to apply the update to the jail.

.. code-block:: shell

  ishmael ~ # bastille etcupdate ishmael update 14.1-RELEASE

The output will show you which files were added, updated, changed, deleted, or have conflicts.
To automatically resolve the conflicts, run the `resolve` command.
            
.. code-block:: shell

  ishmael ~ # bastille etcupdate ishmael resolve

To show only the differences between the releases, use the `diff` command.

.. code-block:: shell

  ishmael ~ # bastille etcupdate ishmael diff 14.1-RELEASE

.. code-block:: shell

  ishmael ~ # bastille etcupdate help
  Usage: bastille etcupdate [option(s)] [bootstrap|TARGET] [diff|resolve|update RELEASE]
    Options:

    -d | --dry-run          Show output, but do not apply.
    -f | --force            Force a re-bootstrap of a RELEASE.
    -x | --debug            Enable debug mode.
