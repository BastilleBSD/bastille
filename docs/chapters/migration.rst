Stop the running jail and export it:

.. code-block:: shell

     iocage stop jailname
     iocage export jailname

Move the backup files (.zip and .sha256) into Bastille backup dir (default: /usr/local/bastille/backups/):

.. code-block:: shell

     mv /iocage/images/jailname_$(date +%F).* /usr/local/bastille/backups/

for remote systems you could use rsync:

.. code-block:: shell

     rsync -avh /iocage/images/jailname_$(date +%F).* root@10.0.1.10:/usr/local/bastille/backups/

     
Import the iocage backup file (use zip file name)

.. code-block:: shell

     bastille import jailname_$(date +%F).zip

Set your new ip address and interface:

.. code-block:: shell

     vim /usr/local/bastille/jails/jailname/jail.conf
     interface = bastille0;
     ip4.addr = "192.168.0.1";


You can use you primary network interface instead of the virtual bastille0 interface as well if you know what you’re doing.
