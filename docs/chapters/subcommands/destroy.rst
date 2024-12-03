=======
destroy
=======

Containers can be destroyed and thrown away just as easily as they were
created.  Note: containers must be stopped before destroyed.

.. code-block:: shell

  ishmael ~ # bastille stop folsom
  [folsom]:
  folsom: removed

.. code-block:: shell

  ishmael ~ # bastille destroy folsom
  Deleting Container: folsom.
  Note: containers console logs not destroyed.
  /usr/local/bastille/logs/folsom_console.log

Releases can be detroyed which also deletes the related cache directory. Child
jails must be destroyed beforehand.

.. code-block:: shell

  ishmael ~ # bastille destroy 14.0-RELEASE
  Deleting base: 14.0-RELEASE
