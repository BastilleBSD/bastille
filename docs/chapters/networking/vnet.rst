VNET Configuration
------------------

VNET Configuration
^^^^^^^^^^^^^^^^^^

(Added in 0.6.x) VNET is supported on FreeBSD 12+ only.

Virtual Network (VNET) creates a private network interface for a container. This
includes a unique hardware address. This is required for VPN, DHCP, and similar
containers.

To create a VNET based container use the ``-V|--vnet`` option, an IP/netmask and
external interface.

.. code-block:: shell

  bastille create -V azkaban 13.2-RELEASE 192.168.1.50/24 em0

Bastille will automagically create the bridge interface and connect /
disconnect containers as they are started and stopped. A new interface will be
created on the host matching the pattern ``interface0bridge``. In the example
here, ``em0bridge``.

The ``em0`` interface will be attached to the bridge along with the unique
container interfaces as they are started and stopped. These interface names
match the pattern ``eXb_bastilleX``. Internally to the containers these
interfaces are presented as ``vnet0``.

If you do not specify a subnet mask, you might have issues with jail to jail
networking, especially VLAN to VLAN. We recommend always adding a subnet to
VNET jail IPs when creating them to avoid these issues.

VNET also requires a custom devfs ruleset. Create the file as needed on the
host system:

.. code-block:: shell

  ## /etc/devfs.rules (NOT .conf)

  [bastille_vnet=13]
  add include $devfsrules_hide_all
  add include $devfsrules_unhide_basic
  add include $devfsrules_unhide_login
  add include $devfsrules_jail
  add include $devfsrules_jail_vnet
  add path 'bpf*' unhide

Lastly, you may want to consider these three ``sysctl`` values:

.. code-block:: shell

  net.link.bridge.pfil_bridge=0
  net.link.bridge.pfil_onlyip=0
  net.link.bridge.pfil_member=0

Below is the definition of what these three parameters are used for and mean:


       net.link.bridge.pfil_onlyip  Controls  the  handling  of	non-IP packets
				    which are not passed to pfil(9).  Set to 1
				    to only allow IP packets to	pass  (subject
				    to	firewall  rules), set to 0 to uncondi-
				    tionally pass all non-IP Ethernet frames.

       net.link.bridge.pfil_member  Set	to 1 to	enable filtering on the	incom-
				    ing	and outgoing member interfaces,	set to
				    0 to disable it.

       net.link.bridge.pfil_bridge  Set	to 1 to	enable filtering on the	bridge
				    interface, set to 0	to disable it.

VNET - Manual Bridge Configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To create a VNET based container and attach it to an external, already existing
bridge, use the ``-B`` option, an IP/netmask and external bridge.

.. code-block:: shell

  bastille create -B azkaban 13.2-RELEASE 192.168.1.50/24 bridge0

Bastille will automagically create the needed interface(s), attach it to the
specified bridge and connect/disconnect containers as they are started and stopped.
The bridge needs to be created/enabled before creating and starting the jail.

Below are the steps to creating a bridge for this purpose.

The first thing you have to do is to create a bridge
interface on your system.  This is done with the ifconfig command and will
create a bridged interface named bridge0:

.. code-block:: shell

   ifconfig bridge create

Then you need to add your system's network interface to the bridge and bring it
up (substitute your interface for em0).

.. code-block:: shell

   ifconfig bridge0 addm em0 up

Optionally you can rename the interface if you wish to make it obvious that it
is for bastille:

.. code-block:: shell

   ifconfig bridge0 name bastille0bridge

To create a bridged container you use the ``-B`` option, an IP or DHCP, and the
bridge interface.

.. code-block:: shell

   bastille create -B folsom 14.2-RELEASE DHCP bastille0bridge

All the epairs and networking other than the manually created bridge will be
created for you automagically. Now if you want this to persist after a reboot
then you need to add some lines to your ``/etc/rc.conf`` file.  Add the
following lines, again, obviously change em0 to whatever your network interface
on your system is.

.. code-block:: shell

   cloned_interfaces="bridge0"
   ifconfig_bridge0_name="bastille0bridge"
   ifconfig_bastille0bridge="addm vtnet0 up"
