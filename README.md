Bastille
========
[Bastille](https://bastillebsd.org/) is an open-source system for automating
deployment and management of containerized applications on FreeBSD.

Looking for [Bastille Templates](https://gitlab.com/BastilleBSD-Templates/)?

Installation
============
Bastille is available in the official FreeBSD ports tree.

**pkg**
```shell
pkg install bastille
```

**ports**
```shell
portsnap fetch auto
make -C /usr/ports/sysutils/bastille install clean
```

**Git** (bleeding edge / unstable -- primarily for developers)
```shell
git clone https://github.com/BastilleBSD/bastille.git
cd bastille
make install
```

**enable at boot**
```shell
sysrc bastille_enable=YES
```

Basic Usage
-----------
```shell
Bastille is an open-source system for automating deployment and management of
containerized applications on FreeBSD.

Usage:
  bastille command TARGET args

Available Commands:
  bootstrap   Bootstrap a FreeBSD release for container base.
  cmd         Execute arbitrary command on targeted container(s).
  clone       Clone an existing container.
  console     Console into a running container.
  convert     Convert a thin container into a thick container.
  cp          cp(1) files from host to targeted container(s).
  create      Create a new thin or thick container.
  destroy     Destroy a stopped container or a bootstrapped release.
  edit        Edit container configuration files (advanced).
  export      Exports a container archive or image.
  help        Help about any command
  htop        Interactive process viewer (requires htop).
  import      Import a container archive or image.
  limits      Apply resources limits to targeted container(s). See rctl(8).
  list        List containers, releases, templates, logs, limits or backups.
  pkg         Manipulate binary packages within targeted container(s). See pkg(8).
  rdr         Redirect host port to container port.
  restart     Restart a running container.
  service     Manage services within targeted container(s).
  start       Start a stopped container.
  stop        Stop a running container.
  sysrc       Safely edit rc files within targeted container(s).
  template    Apply automation templates to targeted container(s).
  top         Display and update information about the top(1) cpu processes.
  update      Update container base -pX release.
  upgrade     Upgrade container release to X.Y-RELEASE.
  verify      Verify bootstrapped release or automation template.
  zfs         Manage (get|set) zfs attributes on targeted container(s).

Use "bastille -v|--version" for version information.
Use "bastille command -h|--help" for more information about a command.

```

## 0.6-beta
This document outlines the basic usage of the Bastille container management
framework. This release is still considered beta.

Network Requirements
====================
Several networking options can be performed regarding the user needs.  Basic
containers can support IP alias networking, where the IP address is assigned to
the host interface and used by the container, generally known as "shared IP"
based containers.

If you administer your own network and can assign and remove unallocated IP
addresses, then "shared IP" is a simple method to get started. If this is the
case, skip ahead to ZFS Support.

If you are not the administator of the network, or perhaps you're in "the
cloud" someplace and are only provided a single IP4 address. In this situation
Bastille can create and attach containers to a private loopback interface. The
host system then acts as the firewall, permitting and denying traffic as
needed. (This method has been my primary method for years.)

**bastille0**

First, create the loopback interface:

```shell
ishmael ~ # sysrc cloned_interfaces+=lo1
ishmael ~ # sysrc ifconfig_lo1_name="bastille0"
ishmael ~ # service netif cloneup
```

Create the firewall config, or merge as necessary.

/etc/pf.conf
------------
```
ext_if="vtnet0"

set block-policy return
scrub in on $ext_if all fragment reassemble
set skip on lo

table <jails> persist
nat on $ext_if from <jails> to any -> ($ext_if)

## static rdr example
# rdr pass inet proto tcp from any to any port {80, 443} -> 10.17.89.45

## Enable dynamic rdr (see below)
rdr-anchor "rdr/*"

block in all
pass out quick modulate state
antispoof for $ext_if inet
pass in inet proto tcp from any to any port ssh flags S/SA keep state

## make sure you also open up ports that you are going to use for dynamic rdr
# pass in inet proto tcp from any to any port <rdr-start>:<rdr-end> flags S/SA keep state
# pass in inet proto udp from any to any port <rdr-start>:<rdr-end> flags S/SA keep state

```

* Make sure to change the `ext_if` variable to match your host system interface.
* Make sure to include the last line (`port ssh`) or you'll end up locked
out of a remote system.

Note: if you have an existing firewall, the key lines for in/out traffic to
containers are:

```
table <jails> persist
nat on $ext_if from <jails> to any -> ($ext_if)

## rdr example
## rdr pass inet proto tcp from any to any port {80, 443} -> 10.17.89.45
```

The `nat` routes traffic from the loopback interface to the external interface
for outbound access.

The `rdr pass ...` will redirect traffic from the host firewall on port X to
the ip of container Y. The example shown redirects web traffic (80 & 443) to the
container at `10.17.89.45`.

Finally, enable and (re)start the firewall:

## dynamic rdr 

The `rdr-anchor "rdr/*"` enables dynamic rdr rules to be setup using the 
`bastille rdr` command at runtime - eg.

```
  bastille rdr <jail> tcp 2001 22 # Redirects tcp port 2001 on host to 22 on jail
  bastille rdr <jail> udp 2053 53 # Same for udp
  bastille rdr <jail> list        # List dynamic rdr rules
  bastille rdr <jail> clear       # Clear dynamic rdr rules
```

  Note that if you are rediirecting ports where the host is also listening
  (eg. ssh) you should make sure that the host service is not listening on 
  the cloned interface - eg. for ssh set sshd_flags in rc.conf

## Enable pf rules

```shell
ishmael ~ # sysrc pf_enable="YES"
ishmael ~ # service pf restart
```

At this point you'll likely be disconnected from the host. Reconnect the ssh
session and continue.

This step only needs to be done once in order to prepare the host.


ZFS support
===========

![BastilleBSD Twitter Poll](/docs/images/bastillebsd-twitter-poll.png)

Bastille 0.4 added initial support for ZFS. `bastille bootstrap` and `bastille
create` will generate ZFS volumes based on settings found in the
`bastille.conf`. This section outlines how to enable and configure Bastille for
ZFS.

Two values are required for Bastille to use ZFS. The default values in the
`bastille.conf` are empty. Populate these two to enable ZFS.

```shell
## ZFS options
bastille_zfs_enable=""                                  ## default: ""
bastille_zfs_zpool=""                                   ## default: ""
bastille_zfs_prefix="bastille"                          ## default: "${bastille_zfs_zpool}/bastille"
bastille_zfs_mountpoint=${bastille_prefix}              ## default: "${bastille_prefix}"
bastille_zfs_options="-o compress=lz4 -o atime=off"     ## default: "-o compress=lz4 -o atime=off"
```

**Example**

```shell
ishmael ~ # sysrc -f /usr/local/etc/bastille/bastille.conf bastille_zfs_enable=YES
ishmael ~ # sysrc -f /usr/local/etc/bastille/bastille.conf bastille_zfs_zpool=ZPOOL_NAME
```

Replace `ZPOOL_NAME` with the zpool you want Bastille to use. Tip: `zpool list`
and `zpool status` will help. If you get 'no pools available' you are likely
not using ZFS and can safely ignore these settings.


bastille bootstrap
------------------
Before you can begin creating containers, Bastille needs to "bootstrap" a
release.  Current supported releases are 11.3-RELEASE, 12.0-RELEASE and
12.1-RELEASE.

**Important: If you need ZFS support see the above section BEFORE
bootstrapping.**

To `bootstrap` a release, run the bootstrap sub-command with the
release version as the argument.

**FreeBSD 11.3-RELEASE**
```shell
ishmael ~ # bastille bootstrap 11.3-RELEASE
```

**FreeBSD 12.1-RELEASE**
```shell
ishmael ~ # bastille bootstrap 12.1-RELEASE
```

**HardenedBSD 11-STABLE-BUILD-XX**
```shell
ishmael ~ # bastille bootstrap 11-STABLE-BUILD-XX
```

**HardenedBSD 12-STABLE-BUILD-XX**
```shell
ishmael ~ # bastille bootstrap 12-STABLE-BUILD-XX
```

> `bastille bootstrap RELEASE update` to apply updates automatically at bootstrap.

This command will ensure the required directory structures are in place and
download the requested release. For each requested release, `bootstrap` will
download the base.txz. If you need more than base (eg; ports, lib32, src) you
can configure the `bastille_bootstrap_archives` in the configuration file. By
default this value is set to "base". Additional components are added, space
separated, without file extension.

Bastille will attempt to fetch the required archives if they are not found in
the `cache/$RELEASE` directory. 

Downloaded artifacts are stored in the `cache/RELEASE` directory. "bootstrapped"
releases are stored in `releases/RELEASE`.

Advanced: If you want to create your own custom base.txz, or use an unsupported
variant of FreeBSD, drop your own base.txz in `cache/RELEASE/base.txz` and
`bastille bootstrap` will attempt to extract and use it.

The bootstrap subcommand is generally only used once to prepare the system. The
other use cases for the bootstrap command are when a new FreeBSD version is
released and you want to start building containers on that version, or
bootstrapping templates from GitHub or GitLab.

See `bastille update` to ensure your bootstrapped releases include the latest
patches.


bastille create
---------------
`bastille create` uses a bootstrapped release to create a lightweight container
system. To create a container simply provide a name, release and a private
(rfc1918) IP address. Optionally provide a network interface name to attach the
IP at container creation.

- name
- release (bootstrapped)
- ip (ip4 or ip6)
- interface (optional)


**ip4**
```shell
ishmael ~ # bastille create folsom 12.1-RELEASE 10.17.89.10
Valid: (10.17.89.10).

NAME: folsom.
IP: 10.17.89.10.
RELEASE: 12.1-RELEASE.

syslogd_flags: -s -> -ss
sendmail_enable: NO -> NONE
cron_flags:  -> -J 60
```

This command will create a 12.1-RELEASE container assigning the 10.17.89.10 ip
address to the new system.

**ip6**
```shell
ishmael ~ # bastille create folsom 12.1-RELEASE fd35:f1fd:2cb6:6c5c::13
Valid: (fd35:f1fd:2cb6:6c5c::13).

NAME: folsom.
IP: fd35:f1fd:2cb6:6c5c::13
RELEASE: 12.1-RELEASE.

syslogd_flags: -s -> -ss
sendmail_enable: NO -> NONE
cron_flags:  -> -J 60
```

This command will create a 12.1-RELEASE container assigning the
fd35:f1fd:2cb6:6c5c::13  ip address to the new system.

**VNET**
```shell
ishmael ~ # bastille create -V vnetjail 12.1-RELEASE 192.168.87.55/24 em0
Valid: (192.168.87.55/24).
Valid: (em0).

NAME: vnettest0.
IP: 192.168.87.55/24.
INTERFACE: em0.
RELEASE: 12.1-RELEASE.

syslogd_flags: -s -> -ss
sendmail_enable: NO -> NONE
cron_flags:  -> -J 60
ifconfig_e0b_bastille0_name:  -> vnet0
ifconfig_vnet0:  -> inet 192.168.87.55/24
```

This command will create a 12.1-RELEASE container assigning the
192.168.87.55/24 ip address to the new system.

VNET-enabled containers are attached to a virtual bridge interface for
connectivity. This bridge interface is defined by the interface argument in the
create command (in this case, em0).

VNET also requires a custom `devfs` ruleset. Create the file as needed on the host system:

**/etc/devfs.rules**
```
[bastille_vnet=13]
add include $devfsrules_hide_all
add include $devfsrules_unhide_basic
add include $devfsrules_unhide_login
add include $devfsrules_jail
add path 'bpf*' unhide
```

Optionally `bastille create [ -T | --thick ]` will create a container with a
private base. This is sometimes referred to as a "thick" container (whereas the
shared base container is a "thin").

```shell
ishmael ~ # bastille create -T folsom 12.0-RELEASE 10.17.89.10
```

I recommend using private (rfc1918) ip address ranges for your containers.
These ranges include:

- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

If your Bastille host also uses private (rfc1918) addresses, use a different
range for your containers. ie; Host uses 192.168.0.0/16, containers use 10.0.0.0/8.

Bastille does its best to validate the submitted ip is valid. I generally use
the 10.0.0.0/8 range for containers.


bastille start
--------------
To start a containers you can use the `bastille start` command.

```shell
ishmael ~ # bastille start folsom
[folsom]:
folsom: created

```


bastille stop
-------------
To stop a containers you can use the `bastille stop` command.

```shell
ishmael ~ # bastille stop folsom
[folsom]:
folsom: removed

```


bastille restart
----------------
To restart a container you can use the `bastille restart` command.

```shell
ishmael ~ # bastille restart folsom
[folsom]:
folsom: removed

[folsom]:
folsom: created

```

bastille list
-------------
This sub-command will show you the running containers on your system.

```shell
ishmael ~ # bastille list
 JID             IP Address      Hostname                      Path
 bastion         10.17.89.65      bastion                       /usr/local/bastille/jails/bastion/root
 unbound0        10.17.89.60      unbound0                      /usr/local/bastille/jails/unbound0/root
 unbound1        10.17.89.61      unbound1                      /usr/local/bastille/jails/unbound1/root
 squid           10.17.89.30      squid                         /usr/local/bastille/jails/squid/root
 nginx           10.17.89.45      nginx                         /usr/local/bastille/jails/nginx/root
 folsom          10.17.89.10      folsom                        /usr/local/bastille/jails/folsom/root
```

You can also list non-running containers with `bastille list containers`.  In
the same manner you can list archived `logs`, downloaded `templates`, and
`releases` and `backups`.  Providing the `-j` flag to list alone will result in
JSON output.


bastille service
----------------
To restart services inside a containers you can use the `bastille service`
command.

```shell
ishmael ~ # bastille service folsom postfix restart
[folsom]
postfix/postfix-script: stopping the Postfix mail system
postfix/postfix-script: starting the Postfix mail system

```


bastille cmd
------------
To execute commands within the container you can use `bastille cmd`.

```shell
ishmael ~ # bastille cmd folsom ps -auxw
[folsom]:
USER   PID %CPU %MEM   VSZ  RSS TT  STAT STARTED    TIME COMMAND
root 71464  0.0  0.0 14536 2000  -  IsJ   4:52PM 0:00.00 /usr/sbin/syslogd -ss
root 77447  0.0  0.0 16632 2140  -  SsJ   4:52PM 0:00.00 /usr/sbin/cron -s
root 80591  0.0  0.0 18784 2340  1  R+J   4:53PM 0:00.00 ps -auxw

```


bastille pkg
------------
To manage binary packages within the container use `bastille pkg`.

```shell
ishmael ~ # bastille pkg folsom install vim-console git-lite zsh
[folsom]:
Updating FreeBSD repository catalogue...
[folsom] Fetching meta.txz: 100%    944 B   0.9kB/s    00:01
[folsom] Fetching packagesite.txz: 100%    6 MiB   6.6MB/s    00:01
Processing entries: 100%
FreeBSD repository update completed. 32617 packages processed.
All repositories are up to date.
Updating database digests format: 100%
The following 10 package(s) will be affected (of 0 checked):

New packages to be INSTALLED:
	vim-console: 8.1.1954
	git-lite: 2.23.0
	zsh: 5.7.1_1
	expat: 2.2.8
	curl: 7.66.0
	libnghttp2: 1.39.2
	ca_root_nss: 3.47.1
	pcre: 8.43_2
	gettext-runtime: 0.20.1
	indexinfo: 0.3.1

Number of packages to be installed: 10

The process will require 87 MiB more space.
18 MiB to be downloaded.

Proceed with this action? [y/N]:
...[snip]...
```

The PKG sub-command can, of course, do more than just `install`. The
expectation is that you can fully leverage the pkg manager. This means,
`install`, `update`, `upgrade`, `audit`, `clean`, `autoremove`, etc.

```shell
ishmael ~ # bastille pkg ALL upgrade
[bastion]:
Updating pkg.bastillebsd.org repository catalogue...
[bastion] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
[bastion] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
Processing entries: 100%
pkg.bastillebsd.org repository update completed. 493 packages processed.
All repositories are up to date.
Checking for upgrades (1 candidates): 100%
Processing candidates (1 candidates): 100%
Checking integrity... done (0 conflicting)
Your packages are up to date.

[unbound0]:
Updating pkg.bastillebsd.org repository catalogue...
[unbound0] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
[unbound0] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
Processing entries: 100%
pkg.bastillebsd.org repository update completed. 493 packages processed.
All repositories are up to date.
Checking for upgrades (0 candidates): 100%
Processing candidates (0 candidates): 100%
Checking integrity... done (0 conflicting)
Your packages are up to date.

[unbound1]:
Updating pkg.bastillebsd.org repository catalogue...
[unbound1] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
[unbound1] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
Processing entries: 100%
pkg.bastillebsd.org repository update completed. 493 packages processed.
All repositories are up to date.
Checking for upgrades (0 candidates): 100%
Processing candidates (0 candidates): 100%
Checking integrity... done (0 conflicting)
Your packages are up to date.

[squid]:
Updating pkg.bastillebsd.org repository catalogue...
[squid] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
[squid] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
Processing entries: 100%
pkg.bastillebsd.org repository update completed. 493 packages processed.
All repositories are up to date.
Checking for upgrades (0 candidates): 100%
Processing candidates (0 candidates): 100%
Checking integrity... done (0 conflicting)
Your packages are up to date.

[nginx]:
Updating pkg.bastillebsd.org repository catalogue...
[nginx] Fetching meta.txz: 100%    560 B   0.6kB/s    00:01
[nginx] Fetching packagesite.txz: 100%  118 KiB 121.3kB/s    00:01
Processing entries: 100%
pkg.bastillebsd.org repository update completed. 493 packages processed.
All repositories are up to date.
Checking for upgrades (1 candidates): 100%
Processing candidates (1 candidates): 100%
The following 1 package(s) will be affected (of 0 checked):

Installed packages to be UPGRADED:
	nginx-lite: 1.14.0_14,2 -> 1.14.1,2

Number of packages to be upgraded: 1

315 KiB to be downloaded.

Proceed with this action? [y/N]: y
[nginx] [1/1] Fetching nginx-lite-1.14.1,2.txz: 100%  315 KiB 322.8kB/s    00:01
Checking integrity... done (0 conflicting)
[nginx] [1/1] Upgrading nginx-lite from 1.14.0_14,2 to 1.14.1,2...
===> Creating groups.
Using existing group 'www'.
===> Creating users
Using existing user 'www'.
[nginx] [1/1] Extracting nginx-lite-1.14.1,2: 100%
You may need to manually remove /usr/local/etc/nginx/nginx.conf if it is no longer needed.
```


bastille destroy
----------------
Containers can be destroyed and thrown away just as easily as they were
created.  Note: containers must be stopped before destroyed.

```shell
ishmael ~ # bastille stop folsom
[folsom]:
folsom: removed

ishmael ~ # bastille destroy folsom
Deleting Container: folsom.
Note: container console logs not destroyed.
/usr/local/bastille/logs/folsom_console.log

```

bastille template
-----------------
Looking for ready made CI/CD validated [Bastille
Templates](https://gitlab.com/BastilleBSD-Templates)?

Bastille supports a templating system allowing you to apply files, pkgs and
execute commands inside the container automatically.

Currently supported template hooks are: `LIMITS`, `INCLUDE`, `PRE`, `FSTAB`,
`PKG`, `OVERLAY`, `SYSRC`, `SERVICE`, `CMD`.
Planned template hooks include: `PF`, `LOG`

Templates are created in `${bastille_prefix}/templates` and can leverage any of
the template hooks. Simply create a new directory in the format project/repo,
ie; `username/base-template`

```shell
mkdir -p /usr/local/bastille/templates/username/base-template
```

To leverage a template hook, create an UPPERCASE file in the root of the
template directory named after the hook you want to execute. eg;

```shell
echo "zsh vim-console git-lite htop" > /usr/local/bastille/templates/username/base-template/PKG
echo "/usr/bin/chsh -s /usr/local/bin/zsh" > /usr/local/bastille/templates/username/base-template/CMD
echo "usr" > /usr/local/bastille/templates/username/base-template/OVERLAY
```

Template hooks are executed in specific order and require specific syntax to
work as expected. This table outlines that order and those requirements:

| SUPPORTED | format              | example                                        |
|-----------|---------------------|------------------------------------------------|
| LIMITS    | resource value      | memoryuse 1G                                   |
| INCLUDE   | template path/URL   | http?://TEMPLATE_URL or username/base-template |
| PRE       | /bin/sh command     | mkdir -p /usr/local/path                       |
| FSTAB     | fstab syntax        | /host/path container/path nullfs ro 0 0        |
| PKG       | port/pkg name(s)    | vim-console zsh git-lite tree htop             |
| OVERLAY   | paths (one/line)    | etc usr                                        |
| SYSRC     | sysrc command(s)    | nginx_enable=YES                               |
| SERVICE   | service command(s)  | nginx restart                                  |
| CMD       | /bin/sh command     | /usr/bin/chsh -s /usr/local/bin/zsh            |

| PLANNED | format           | example                                                        |
|---------|------------------|----------------------------------------------------------------|
| RDR     | pf rdr entry     | rdr pass inet proto tcp from any to any port 80 -> 10.17.89.80 |
| LOG     | path             | /var/log/nginx/access.log                                      |

Note: SYSRC requires NO quotes or that quotes (`"`) be escaped. ie; `\"`)

In addition to supporting template hooks, Bastille supports overlaying files
into the container. This is done by placing the files in their full path, using the
template directory as "/".

An example here may help. Think of
`/usr/local/bastille/templates/username/base`, our example template, as the
root of our filesystem overlay. If you create an `etc/hosts` or
`etc/resolv.conf` inside the base template directory, these can be overlayed
into your container.

Note: due to the way FreeBSD segregates user-space, the majority of your
overlayed template files will be in `usr/local`. The few general
exceptions are the `etc/hosts`, `etc/resolv.conf`, and `etc/rc.conf.local`.

After populating `usr/local/` with custom config files that your container will
use, be sure to include `usr` in the template OVERLAY definition. eg;

```shell
echo "etc" > /usr/local/bastille/templates/username/base/OVERLAY
echo "usr" >> /usr/local/bastille/templates/username/base/OVERLAY
```

The above example will include anything under "etc" and "usr" inside
the template. You do not need to list individual files. Just include the
top-level directory name.


Applying Templates
------------------

Containers must be running to apply templates.

Bastille includes a `template` sub-command. This sub-command requires a target
and a template name. As covered in the previous section, template names
correspond to directory names in the `bastille/templates` directory.

```shell
ishmael ~ # bastille template folsom username/base
[folsom]:
Copying files...
Copy complete.
Installing packages.
...[snip]...
Executing final command(s).
chsh: user information updated
Template Complete.

```


bastille top
------------
This one simply runs `top` in that container. This command is interactive, as
`top` is interactive.


bastille htop
-------------
This one simply runs `htop` inside the container. This one is a quick and dirty
addition. note: won't work if you don't have htop installed in the container.


bastille sysrc
--------------
The `sysrc` sub-command allows for safely editing system configuration files.
In container terms, this allows us to toggle on/off services and options at
startup.

```shell
ishmael ~ # bastille sysrc nginx nginx_enable=YES
[nginx]:
nginx_enable: NO -> YES
```

See `man sysrc(8)` for more info.


bastille console
----------------
This sub-command launches a login shell into the container. Default is
password-less root login. If you provide an additional argument of a username
you will be logged in as that user. (user must be created first)

```shell
ishmael ~ # bastille console folsom
[folsom]:
FreeBSD 11.3-RELEASE-p4 (GENERIC) #0: Thu Sep 27 08:16:24 UTC 2018

Welcome to FreeBSD!

Release Notes, Errata: https://www.FreeBSD.org/releases/
Security Advisories:   https://www.FreeBSD.org/security/
FreeBSD Handbook:      https://www.FreeBSD.org/handbook/
FreeBSD FAQ:           https://www.FreeBSD.org/faq/
Questions List: https://lists.FreeBSD.org/mailman/listinfo/freebsd-questions/
FreeBSD Forums:        https://forums.FreeBSD.org/

Documents installed with the system are in the /usr/local/share/doc/freebsd/
directory, or can be installed later with:  pkg install en-freebsd-doc
For other languages, replace "en" with a language code like de or fr.

Show the version of FreeBSD installed:  freebsd-version ; uname -a
Please include that output and any error messages when posting questions.
Introduction to manual pages:  man man
FreeBSD directory layout:      man hier

Edit /etc/motd to change this login announcement.
root@folsom:~ #
```

At this point you are logged in to the container and have full shell access.
The system is yours to use and/or abuse as you like. Any changes made inside
the container are limited to the container. 


bastille cp
-----------
This sub-command allows efficiently copying files from host to container(s).

```shell
ishmael ~ # bastille cp ALL /tmp/resolv.conf-cf etc/resolv.conf
[folsom]:
/tmp/resolv.conf-cf -> /usr/local/bastille/jails/folsom/root/etc/resolv.conf

[nginx]:
/tmp/resolv.conf-cf -> /usr/local/bastille/jails/nginx/root/etc/resolv.conf

[squid]:
/tmp/resolv.conf-cf -> /usr/local/bastille/jails/squid/root/etc/resolv.conf

[unbound0]:
/tmp/resolv.conf-cf -> /usr/local/bastille/jails/unbound0/root/etc/resolv.conf
```

bastille rdr
------------

`bastille rdr` allows you to configure dynamic rdr rules for your containers
without modifying pf.conf (assuming you are using the `bastille0` interface 
for a private network and have enabled `rdr-anchor 'rdr/*'` in /etc/pf.conf 
as described in the Networking section).

```shell
    # bastille rdr help
    Usage: bastille rdr TARGET [clear] | [list] | [tcp <host_port> <jail_port>] | [udp <host_port> <jail_port>]
    # bastille rdr dev1 tcp 2001 22
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    # bastille rdr dev1 udp 2053 53
    # bastille rdr dev1 list
    rdr on em0 inet proto tcp from any to any port = 2001 -> 10.17.89.1 port 22
    rdr on em0 inet proto udp from any to any port = 2053 -> 10.17.89.1 port 53
    # bastille rdr dev1 clear
    nat cleared
```

bastille update
---------------
The `update` command targets a release instead of a container. Because every
container is based on a release, when the release is updated all the containers
are automatically updated as well.

To update all containers based on the 11.2-RELEASE `release`:

Up to date 11.2-RELEASE:
```shell
ishmael ~ # bastille update 11.2-RELEASE
Targeting specified release.
11.2-RELEASE

Looking up update.FreeBSD.org mirrors... 2 mirrors found.
Fetching metadata signature for 11.2-RELEASE from update4.freebsd.org... done.
Fetching metadata index... done.
Inspecting system... done.
Preparing to download files... done.

No updates needed to update system to 11.2-RELEASE-p4.
No updates are available to install.
```

To be safe, you may want to restart any containers that have been updated live.


bastille upgrade
----------------
This sub-command lets you upgrade a release to a new release. Depending on the
workflow this can be similar to a `bootstrap`.

```shell
ishmael ~ # bastille upgrade 11.3-RELEASE 12.0-RELEASE
...
```


bastille verify
---------------
This sub-command scans a bootstrapped release and validates that everything
looks in order. This is not a 100% comprehensive check, but it compares the
release against a "known good" index.

If you see errors or issues here, consider deleting and re-bootstrapping the
release.

It should be noted that releases bootstrapped through Bastille are validated
using `sha256` checksum against the release manifest. Archives that fail
validation are not used.


bastille zfs
------------
This sub-command allows managing zfs attributes for the targeted container(s).
Common usage includes setting container quotas.

**set quota**
```shell
ishmael ~ # bastille zfs folsom set quota=1G
```

**built-in: df**
```shell
ishmael ~ # bastille zfs ALL df
```

**built-in: df**
```shell
ishmael ~ # bastille zfs folsom df
```

bastille export
----------------
Containers can be exported for archiving purposes easily.
Note: On UFS systems containers must be stopped before export.

```shell
ishmael ~ # bastille export folsom
Exporting 'folsom' to a compressed .xz archive.
Sending zfs data stream...
  100 %     1057.2 KiB / 9231.5 KiB = 0.115                   0:01             
Exported '/usr/local/bastille/jails/backups/folsom_2020-01-26-19:23:04.xz' successfully.

```

bastille import
----------------
Containers can be imported from supported archives easily.

```shell
ishmael ~ # bastille import folsom_2020-01-26-19:22:23.xz
Validating file: folsom_2020-01-26-19:22:23.xz...
File validation successful!
Importing 'folsom' from compressed .xz archive.
Receiving zfs data stream...
/usr/local/bastille/jails/backups/folsom_2020-01-26-19:22:23.xz (1/1)
  100 %      626.4 KiB / 9231.5 KiB = 0.068                   0:02             
Container 'folsom' imported successfully.
```

bastille clone
---------------
`bastille clone` will duplicate an existing container.
Please be aware that no host specific keys or hashes will be regenerated.
E. g. remove OpenSSH host keys to avoid duplicate host keys `rm /etc/ssh/ssh_host_*`

Usage: `bastille clone [TARGET] [NEWJAIL] [NEW_IPADRRESS]

```shell
ishmael ~ # bastille clone sourcejail targetjail 10.17.89.11
```

Example (create, start, console)
================================
This example creates, starts and consoles into the container.

```shell
ishmael ~ # bastille create alcatraz 11.2-RELEASE 10.17.89.7

RELEASE: 11.2-RELEASE.
NAME: alcatraz.
IP: 10.17.89.7.
```

```shell
ishmael ~ # bastille start alcatraz
[alcatraz]:
alcatraz: created
```

```shell
ishmael ~ # bastille console alcatraz
[alcatraz]:
FreeBSD 11.2-RELEASE-p4 (GENERIC) #0: Thu Sep 27 08:16:24 UTC 2018

Welcome to FreeBSD!

Release Notes, Errata: https://www.FreeBSD.org/releases/
Security Advisories:   https://www.FreeBSD.org/security/
FreeBSD Handbook:      https://www.FreeBSD.org/handbook/
FreeBSD FAQ:           https://www.FreeBSD.org/faq/
Questions List: https://lists.FreeBSD.org/mailman/listinfo/freebsd-questions/
FreeBSD Forums:        https://forums.FreeBSD.org/

Documents installed with the system are in the /usr/local/share/doc/freebsd/
directory, or can be installed later with:  pkg install en-freebsd-doc
For other languages, replace "en" with a language code like de or fr.

Show the version of FreeBSD installed:  freebsd-version ; uname -a
Please include that output and any error messages when posting questions.
Introduction to manual pages:  man man
FreeBSD directory layout:      man hier

Edit /etc/motd to change this login announcement.
root@alcatraz:~ #
```

```shell
root@alcatraz:~ # ps -auxw
USER   PID %CPU %MEM  VSZ  RSS TT  STAT STARTED    TIME COMMAND
root 83222  0.0  0.0 6412 2492  -  IsJ  02:21   0:00.00 /usr/sbin/syslogd -ss
root 88531  0.0  0.0 6464 2508  -  SsJ  02:21   0:00.01 /usr/sbin/cron -s
root  6587  0.0  0.0 6912 2788  3  R+J  02:42   0:00.00 ps -auxw
root 92441  0.0  0.0 6952 3024  3  IJ   02:21   0:00.00 login [pam] (login)
root 92565  0.0  0.0 7412 3756  3  SJ   02:21   0:00.01 -csh (csh)
root@alcatraz:~ #
```


Project Goals
=============
These tools are created initially with the mindset of function over form. I
want to simply prove the concept is sound for real work. The real work is a
sort of meta-container-port system. Instead of installing the MySQL port
directly on a system, you would use Bastille to install the MySQL port within a
container template built for MySQL. The same goes for DNS servers, and
everything else in the ports tree.

Eventually I would like to have Bastille templates created for popular
FreeBSD-based services. From Plex Media Servers to ad-blocking DNS resolvers.
From tiny SSH containers to dynamic web servers. [COMPLETE]

I don't want to tell you what you can and can't run within this framework.
There are no arbitrary limitations based on what I think may or may not be the
best way to design systems. This is not my goal.

My goal is to provide a secure framework where processes and services can run
isolated. I want to limit the scope and reach of bad actors. I want to severely
limit the target areas available to anyone that has (or has gained) access.

Networking Tips
===============

Tip #1: 
-------
Ports and destinations can be defined as lists. eg;
```
rdr pass inet proto tcp from any to any port {80, 443} -> {10.17.89.45, 10.17.89.46, 10.17.89.47, 10.17.89.48}
```

This rule would redirect any traffic to the host on ports 80 or 443 and
round-robin between containers with ips 45, 46, 47, and 48 (on ports 80 or
443).


Tip #2: 
-------
Ports can redirect to other ports. eg;
```
rdr pass inet proto tcp from any to any port 8080 -> 10.17.89.5 port 80
rdr pass inet proto tcp from any to any port 8081 -> 10.17.89.5 port 8080
rdr pass inet proto tcp from any to any port 8181 -> 10.17.89.5 port 443
```

Tip #3:
-------
Don't worry too much about IP assignments.

Initially I spent time worrying about what IP addresses to assign. In the end
I've come to the conclusion that it _really_ doesn't matter. Pick *any* private
address and be done with it.  These are all isolated networks. In the end, what
matters is you can map host:port to container:port reliably, and we can.


Community Support
=================
If you've found a bug in Bastille, please submit it to the [Bastille Issue
Tracker](https://github.com/bastillebsd/bastille/issues/new).
