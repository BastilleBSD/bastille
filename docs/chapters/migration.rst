=========
Migration
=========

iocage
------

Stop the running jail and export it:

.. code-block:: shell

     iocage stop jailname
     iocage export jailname

Move the backup files (.zip and .sha256) into Bastille backup dir (default:
/usr/local/bastille/backups/):

.. code-block:: shell

     mv /iocage/images/jailname_$(date +%F).* /usr/local/bastille/backups/

for remote systems you can use rsync:

.. code-block:: shell

     rsync -avh /iocage/images/jailname_$(date +%F).* root@10.0.1.10:/usr/local/bastille/backups/

     
Import the iocage backup file (use zip file name)

.. code-block:: shell

     bastille import jailname_$(date +%F).zip

Bastille will attempt to configure your interface and IP from the
``config.json`` file, but if you have issues you can configure it manully.

.. code-block:: shell

  bastille edit jailname
  ip4.addr = bastille0|192.168.0.1/24;

You can use your primary network interface instead of the virtual ``bastille0``
interface as well if you know what you’re doing.
