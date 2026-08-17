Bootstrapping Templates
-----------------------

The official templates for Bastille are all on Gthub, and mirror the directory
structure of the ports tree.  So, ``nginx`` is in the ``www`` directory in the
templates repo, just like it is in the FreeBSD ports tree.  To bootstrap the
entire set of official templates, run the following command:

.. code-block:: shell

   bastille bootstrap https://github.com/bastillebsd/templates

This will bootstrap all official templates into the templates directory at
``/usr/local/bastille/templates``. You can then use the ``bastille template``
command to apply any of the templates.

.. code-block:: shell

   bastille template TARGET www/nginx