destroy
=======

Jails can be destroyed and thrown away just as easily as they were
created.  Note: jails must be stopped before destroyed.

.. code-block:: shell

  ishmael ~ # bastille stop folsom
  [folsom]:
  folsom: removed

.. code-block:: shell

  ishmael ~ # bastille destroy folsom
  Deleting Jail: folsom.
  Note: jail console logs not destroyed.
  /usr/local/bastille/logs/folsom_console.log
