create
======

Create a jail uning any available bootstrapped release. To create a jail,
simply provide a name, bootstrapped release, and IP address.

The format is ``bastille create NAME RELEASE IP [INTERFACE]`` 

Note that the ``interface`` is optional. Bastille will use the default interface
that is configured when running the setup command. See ``bastille setup -l`` or
``bastille setup -s``.

.. code-block:: shell

  ishmael ~ # bastille create folsom 11.3-RELEASE 10.17.89.10 [INTERFACE]

  RELEASE: 11.3-RELEASE.
  NAME: folsom.
  IP: 10.17.89.10.

This command will create a 11.3-RELEASE jail, assigning the 10.17.89.10 ip
address to the new jail.

.. code-block:: shell

   ishmael ~ # bastille create alcatraz 13.2-RELEASE 10.17.89.113/24

The above code will create a jail with a /24 mask.  At the time of this
documentation you can only use CIDR notation, and not use a netmask
255.255.255.0 to accomplish this.

I recommend using private (rfc1918) ip address ranges for your container.  These
ranges include:

- 10.0.0.0/8 - 172.16.0.0/12 - 192.168.0.0/16

Bastille does its best to validate the submitted ip is valid. This has not been
thouroughly tested. I generally use the 10/8 range.

A couple of notes about the created jails.  First, MOTD has been disabled inside
of the jails because it does not give information about the jail, but about the
host system.  This caused confusion for some users, so we implemented the
.hushlogin which silences the MOTD at login.

Also, uname does not work from within a jail.  Much like MOTD, it gives you the
version information about the host system instead of the jail.  If you need to
check the version of freebsd running on the jail use the freebsd-version command
to get accurate information.

Bastille can create many different types of jails, along with many different
options. See the below help output.

.. code-block:: shell

  ishmael ~ # bastille create help
  Usage: bastille create [option(s)] NAME RELEASE IP [INTERFACE]"

      Options:
    
      -B | --bridge                            Enable VNET, and attach to a specified, already existing external bridge.
      -C | --clone                             Create a clone jail.
      -D | --dual                              Create jail with both IPv4 and IPv6 networking ('inherit' and 'ip_hostname' only).
      -E | --empty                             Create an empty container, intended for custom jail builds (thin/thick/linux or unsupported).
      -g | --gateway IP                        Specify a default router/gateway for the jail.
      -L | --linux                             Create a Linux jail (experimental).
      -M | --static-mac                        Generate a static MAC address for jail (VNET only).
      -n | --nameserver                        Specify a nameserver for the jail.
           --no-validate                       Do not validate the release when creating the jail.
           --no-boot                           Create jail with boot=off.
      -p | --priority VALUE                    Set priority value for jail.
      -T | --thick                             Creates a thick container, they consume more space as they are self contained and independent.
      -V | --vnet                              Enable VNET, and attach to an existing, physical interface.
      -v | --vlan VLANID                       Creates the jail with specified VLAN ID (VNET only).
      -x | --debug                             Enable debug mode.
      -Z | --zfs-opts zfs,options              Comma separated list of ZFS options to create the jail with. This overrides the defaults.
