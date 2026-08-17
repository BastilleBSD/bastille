Applying Templates
==================

To apply a template to a jail, run the following command.

.. code-block:: shell

  ishmael ~ # bastille template ALL project/template
  [proxy01]:
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  Updating bastillebsd.org repository catalogue...
  [cdn] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [cdn] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  bastillebsd.org repository update completed. 499 packages processed.
  All repositories are up to date.
  Checking integrity... done (0 conflicting)
  The most recent version of packages are already installed
  Updating services.
  cron_flags: -J 60 -> -J 60
  sendmail_enable: NONE -> NONE
  syslogd_flags: -ss -> -ss
  Executing final command(s).
  chsh: user information updated
  Template Complete.

  [web01]:
  Copying files...
  Copy complete.
  Installing packages.
  pkg already bootstrapped at /usr/local/sbin/pkg
  vulnxml file up-to-date
  0 problem(s) in the installed packages found.
  Updating pkg.bastillebsd.org repository catalogue...
  [poudriere] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [poudriere] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  pkg.bastillebsd.org repository update completed. 499 packages processed.
  Updating bastillebsd.org repository catalogue...
  [poudriere] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
  [poudriere] Fetching packagesite.txz: 100%  121 KiB 124.3kB/s    00:01
  Processing entries: 100%
  bastillebsd.org repository update completed. 499 packages processed.
  All repositories are up to date.
  Checking integrity... done (0 conflicting)
  The most recent version of packages are already installed
  Updating services.
  cron_flags: -J 60 -> -J 60
  sendmail_enable: NONE -> NONE
  syslogd_flags: -ss -> -ss
  Executing final command(s).
  chsh: user information updated
  Template Complete.

Notice that if we choose ``ALL`` as the target, the template is applied to all jails.
See :doc:`/chapters/targeting` for more details on targeting jails.