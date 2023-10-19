Bastille
========
[Bastille](https://bastillebsd.org/) is an open-source system for automating
deployment and management of containerized applications on FreeBSD.

[Bastille Documentation](https://bastille.readthedocs.io/en/latest/)

Installation
============
Bastille is available for installation from the official FreeBSD ports tree.

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
git clone https://github.com/bastillebsd/bastille.git
cd bastille
make install
```

**enable at boot**
```shell
sysrc bastille_enable=YES
sysrc bastille_list="azkaban alcatraz" # (optional whitelist of jails to start at boot; default: ALL)
```

Basic Usage
-----------
```shell
Bastille is an open-source system for automating deployment and management of
containerized applications on FreeBSD.

Usage:
  bastille command TARGET [args]

Available Commands:
  bootstrap   Bootstrap a FreeBSD release for container base.
  clone       Clone an existing container.
  cmd         Execute arbitrary command on targeted container(s).
  config      Get or set a config value for the targeted container(s).
  console     Console into a running container.
  convert     Convert a Thin container into a Thick container.
  cp          cp(1) files from host to targeted container(s).
  create      Create a new thin container or a thick container if -T|--thick option specified.
  destroy     Destroy a stopped container or a FreeBSD release.
  edit        Edit container configuration files (advanced).
  export      Exports a specified container.
  help        Help about any command.
  htop        Interactive process viewer (requires htop).
  import      Import a specified container.
  limits      Apply resources limits to targeted container(s). See rctl(8).
  list        List containers (running and stopped).
  mount       Mount a volume inside the targeted container(s).
  pkg         Manipulate binary packages within targeted container(s). See pkg(8).
  rdr         Redirect host port to container port (non-VNET jails only).
  rename      Rename a container.
  restart     Restart a running container.
  service     Manage services within targeted container(s).
  setup       Attempt to auto-configure network, firewall and storage on new installs.
  start       Start a stopped container.
  stop        Stop a running container.
  sysrc       Safely edit rc files within targeted container(s).
  tags        Add or remove tags to targeted container(s).
  template    Apply file templates to targeted container(s).
  top         Display and update information about the top(1) cpu processes.
  umount      Unmount a volume from within the targeted container(s).
  update      Update container base -pX release.
  upgrade     Upgrade container release to X.Y-RELEASE.
  verify      Compare release against a "known good" index.
  zfs         Manage (get|set) ZFS attributes on targeted container(s).

Use "bastille -v|--version" for version information.
Use "bastille command -h|--help" for more information about a command.

```

## 0.10-beta
This document outlines the basic usage of the Bastille container management
framework. This release is still considered beta.

Setup Requirements
==================
Bastille can now (attempt) to configure the networking, firewall and storage
automatically. This feature is new since version 0.10.20231013.

**bastille setup**

```shell
ishmael ~ # bastille setup -h
ishmael ~ # Usage: bastille setup [pf|bastille0|zfs|vnet]
```

On fresh installations it is likely safe to run `bastille setup` with no
arguments. This will configure the firewall, the loopback interface and attempt
to determine ZFS vs UFS storage.

If you have an existing firewall, or customized network design, you may want to
run individual options; eg `bastille setup zfs` or `bastille setup vnet`.

The `rdr-anchor "rdr/*"` enables dynamic rdr rules to be setup using the
`bastille rdr` command at runtime - eg.

```
  bastille rdr <jail> tcp 2001 22 # Redirects tcp port 2001 on host to 22 on jail
  bastille rdr <jail> udp 2053 53 # Same for udp
  bastille rdr <jail> list        # List dynamic rdr rules
  bastille rdr <jail> clear       # Clear dynamic rdr rules
```

  Note that if you are redirecting ports where the host is also listening
  (eg. ssh) you should make sure that the host service is not listening on
  the cloned interface - eg. for ssh set sshd_flags in rc.conf

  Also note that this feature only applies to non-VNET jails.

## Enable pf rules

```shell
ishmael ~ # sysrc pf_enable="YES"
ishmael ~ # service pf restart
```

At this point you'll likely be disconnected from the host. Reconnect the ssh
session and continue.

This step only needs to be done once in order to prepare the host.


ZFS support


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
bastille_prefix="/bastille"                             ## default: "/usr/local/bastille". ${bastille_zfs_prefix} gets mounted here
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
release.  Current supported releases are 11.4-RELEASE, 12.2-RELEASE and
13.0-RELEASE.

**Important: If you need ZFS support see the above section BEFORE
bootstrapping.**

To `bootstrap` a release, run the bootstrap sub-command with the
release version as the argument.

**FreeBSD 11.4-RELEASE**
```shell
ishmael ~ # bastille bootstrap 11.4-RELEASE
```

**FreeBSD 12.2-RELEASE**
```shell
ishmael ~ # bastille bootstrap 12.2-RELEASE
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

** Ubuntu Linux [new since 0.9] **

The bootstrap process for Linux containers is very different from the BSD process.
You will need the package debootstrap and some kernel modules for that.
But don't worry, Bastille will do that for you.

```shell
ishmael ~ # bastille bootstrap focal
sysrc: unknown variable 'linprocfs_load'
sysrc: unknown variable 'linsysfs_load'
sysrc: unknown variable 'tmpfs_load'
linprocfs_load, linsysfs_load, tmpfs_load not enabled in /boot/loader.conf or linux_enable not active. Should I do that for you?  (N|y)
#y
Loading modules
Persisting modules
linux_enable:  -> YES
linprocfs_load:  -> YES
linsysfs_load:  -> YES
tmpfs_load:  -> YES
Debootstrap not found. Should it be installed? (N|y)
#y
FreeBSD repository is up to date.
All repositories are up to date.
Checking integrity... done (0 conflicting)
The following 1 package(s) will be affected (of 0 checked):

New packages to be INSTALLED:
        debootstrap: 1.0.123_4
[...]
```
As of 0.9.20210714 Bastille supports Ubuntu 18.04 (bionic) and Ubuntu 20.04 (focal).

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
ishmael ~ # bastille create folsom 12.2-RELEASE 10.17.89.10
Valid: (10.17.89.10).

NAME: folsom.
IP: 10.17.89.10.
RELEASE: 12.2-RELEASE.

syslogd_flags: -s -> -ss
sendmail_enable: NO -> NONE
cron_flags:  -> -J 60
```

This command will create a 12.2-RELEASE container assigning the 10.17.89.10 ip
address to the new system.

**ip6**
```shell
ishmael ~ # bastille create folsom 12.2-RELEASE fd35:f1fd:2cb6:6c5c::13
Valid: (fd35:f1fd:2cb6:6c5c::13).

NAME: folsom.
IP: fd35:f1fd:2cb6:6c5c::13
RELEASE: 12.1-RELEASE.

syslogd_flags: -s -> -ss
sendmail_enable: NO -> NONE
cron_flags:  -> -J 60
```

This command will create a 12.2-RELEASE container assigning the
fd35:f1fd:2cb6:6c5c::13  ip address to the new system.

**VNET**
```shell
ishmael ~ # bastille create -V vnetjail 12.2-RELEASE 192.168.87.55/24 em0
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

This command will create a 12.2-RELEASE container assigning the
192.168.87.55/24 ip address to the new system.

VNET-enabled containers are attached to a virtual bridge interface for
connectivity. This bridge interface is defined by the interface argument in the
create command (in this case, em0).

VNET also requires a custom `devfs` ruleset. Create the file as needed on the host system:

**/etc/devfs.rules**
```
[bastille_vnet=13]
add path 'bpf*' unhide
```

Optionally `bastille create [ -T | --thick ]` will create a container with a
private base. This is sometimes referred to as a "thick" container (whereas the
shared base container is a "thin").

```shell
ishmael ~ # bastille create -T folsom 12.2-RELEASE 10.17.89.10
```

**Linux**
```shell
ishmael ~ # bastille create folsom focal 10.17.89.10
```

Systemd is not supported due to the missing boot process.



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

Currently supported template hooks are: `ARG`, `LIMITS`, `INCLUDE`,
 `MOUNT`, `PKG`, `CP`, `SYSRC`, `SERVICE`, `RDR`, `CMD`, `RENDER`.

Templates are created in `${bastille_prefix}/templates` and can leverage any of
the template hooks. Simply create a new directory in the format project/repo,
ie; `username/base-template`

```shell
mkdir -p /usr/local/bastille/templates/username/base-template
```

To leverage a template hook, create an UPPERCASE file in the root of the
template directory named after the hook you want to execute. eg;

```shell
echo "PKG zsh vim-console git-lite htop" >> /usr/local/bastille/templates/username/base-template/Bastillefile
echo "CMD /usr/bin/chsh -s /usr/local/bin/zsh" >> /usr/local/bastille/templates/username/base-template/Bastillefile
echo "CP usr" > /usr/local/bastille/templates/username/base-template/Bastillefile
```

Template hooks are executed in specific order and require specific syntax to
work as expected. This table outlines that order and those requirements:

| SUPPORTED | format                | example                                        |
|-----------|-----------------------|------------------------------------------------|
| ARG       | name=value (one/line) | domain=example.com (omit value for no default) |
| LIMITS    | resource value        | memoryuse 1G                                   |
| INCLUDE   | template path/URL     | http?://TEMPLATE_URL or username/base-template |
| PRE       | /bin/sh command       | mkdir -p /usr/local/path                       |
| FSTAB     | fstab syntax          | /host/path container/path nullfs ro 0 0        |
| PKG       | port/pkg name(s)      | vim-console zsh git-lite tree htop             |
| OVERLAY   | paths (one/line)      | etc usr                                        |
| SYSRC     | sysrc command(s)      | nginx_enable=YES                               |
| SERVICE   | service command(s)    | nginx restart                                  |
| CMD       | /bin/sh command       | /usr/bin/chsh -s /usr/local/bin/zsh            |
| RENDER    | paths (one/line)      | /usr/local/etc/nginx                           |
| RDR       | protocol port port    | tcp 2200 22                                    |

Note: SYSRC requires NO quotes or that quotes (`"`) be escaped. ie; `\"`)

Any name provided in the ARG file can be used as a variable in the other hooks.
For example, `name=value` in the ARG file will cause instances of `${name}`
to be replaced with `value`. The `RENDER` hook can be used to specify existing files or
directories inside the jail whose contents should have the variables replaced. Values can be
specified either through the command line when applying the template or as a default in the ARG
file.

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
echo "CP etc" >> /usr/local/bastille/templates/username/base/Bastillefile
echo "CP usr" >> /usr/local/bastille/templates/username/base/Bastillefile
```

The above example will include anything under "etc" and "usr" inside
the template. You do not need to list individual files. Just include the
top-level directory name.

For more control over the order of operations when applying a template,
create a `Bastillefile` inside the base template directory. Each line in
the file should begin with an uppercase reference to a Bastille command
followed by its arguments (omitting the target, which is deduced from the
`template` arguments). Lines beginning with `#` are treated as comments.
Variables can also be defined using `ARG` with one `name=value` pair per
line. Subsequent references to `${name}` would be replaced by `value`.
Note that argument values are not available for use until after the point
at which they are defined in the file. Both `${JAIL_NAME}` and `${JAIL_IP}`
are made available in templates without having to define them as args.

Bastillefile example:

```shell
LIMITS memoryuse 1G

# This value can be overridden when the template is applied.
ARG domain=example.com

# Replace all argument variables inside the nginx config.
RENDER /usr/local/etc/nginx

# Install and start nginx.
PKG nginx
SYSRC nginx_enable=YES
SERVICE nginx restart

# Copy files to nginx.
CP www/ usr/local/www/nginx-dist/

# Use the "domain" arg to create a file on the server containing the domain.
CMD echo "${domain}" > /usr/local/www/nginx-dist/domain.txt

# Create a file on the server containing the jail's hostname.
CMD hostname > /usr/local/www/nginx-dist/hostname.txt

# Forward TCP port 80 on the host to port 80 in the container.
RDR tcp 80 80
```

Use the following command to convert a hook-based template into the Bastillefile format:
```shell
bastille template --convert my-template
```

Applying Templates
------------------

Containers must be running to apply templates.

Bastille includes a `template` sub-command. This sub-command requires a target
and a template name. As covered in the previous section, template names
correspond to directory names in the `bastille/templates` directory.

To provide values for arguments defined by `ARG` in the template, pass the
optional `--arg` parameter as many times as needed. Alternatively, use
`--arg-file <fileName>` with one `name=value` pair per line.

```shell
ishmael ~ # bastille template folsom username/base --arg domain=example.com
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
as described in the Networking section). This feature only applies to non-VNET
jails.

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

To update all containers based on the 11.4-RELEASE `release`:

Up to date 11.4-RELEASE:
```shell
ishmael ~ # bastille update 11.4-RELEASE
Targeting specified release.
11.4-RELEASE

Looking up update.FreeBSD.org mirrors... 2 mirrors found.
Fetching metadata signature for 11.4-RELEASE from update4.freebsd.org... done.
Fetching metadata index... done.
Inspecting system... done.
Preparing to download files... done.

No updates needed to update system to 11.4-RELEASE-p4.
No updates are available to install.
```

To be safe, you may want to restart any containers that have been updated live.


bastille upgrade
----------------
This sub-command lets you upgrade a release to a new release. Depending on the
workflow this can be similar to a `bootstrap`.

For standard containers you need to upgrade the shared base jail:
```shell
ishmael ~ # bastille upgrade 12.1-RELEASE 12.2-RELEASE
...
```

For thick jails you need to upgrade every single container (according the freebsd-update procedure):
```shell
ishmael ~ # bastille upgrade folsom 12.2-RELEASE
ishmael ~ # bastille upgrade folsom install
...
ishmael ~ # bastille restart folsom
ishmael ~ # bastille upgrade folsom install
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
This sub-command allows managing ZFS attributes for the targeted container(s).
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
Sending ZFS data stream...
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
Receiving ZFS data stream...
/usr/local/bastille/jails/backups/folsom_2020-01-26-19:22:23.xz (1/1)
  100 %      626.4 KiB / 9231.5 KiB = 0.068                   0:02
Container 'folsom' imported successfully.
```

bastille clone
---------------
`bastille clone` will duplicate an existing container.
Please be aware that no host specific keys or hashes will be regenerated.
E. g. remove OpenSSH host keys to avoid duplicate host keys `rm /etc/ssh/ssh_host_*`

Usage: `bastille clone [TARGET] [NEWJAIL] [NEW_IPADRRESS]`

```shell
ishmael ~ # bastille clone sourcejail targetjail 10.17.89.11
```

bastille mount
---------------
`bastille mount` will nullfs mount a path from the host inside the container.
Uses the same format as an fstab entry.
Filesystem type, options, dump, and pass number are optional and default to: nullfs ro 0 0

Usage: `bastille mount [TARGET] [HOST_PATH] [CONTAINER_PATH] [FILESYSTEM_TYPE] [OPTIONS] [DUMP] [PASS_NUMBER]`

```shell
ishmael ~ # bastille mount targetjail /host/path container/path
[targetjail]:
Added: /host/path container/path nullfs ro 0 0
```

bastille umount
---------------
`bastille umount` will unmount a volume from inside the container.

Usage: `bastille umount [TARGET] [CONTAINER_PATH]`

```shell
ishmael ~ # bastille umount targetjail container/path
[targetjail]:
Unmounted: container/path
```

=======
Note: The `bastille setup` command can configure and enable PF but it does not
automatically reload the firewall. You will still need to manually `service pf
start`.  At that point you'll likely be disconnected if configuring a remote
host. Simply reconnect the ssh session and continue.

This step only needs to be done once in order to prepare the host.

Example (create, start, console)
================================
This example creates, starts and consoles into the container.

```shell
ishmael ~ # bastille create alcatraz 13.2-RELEASE 10.17.89.10
```

```shell
ishmael ~ # bastille start alcatraz
[alcatraz]:
alcatraz: created
```

```shell
ishmael ~ # bastille console alcatraz
[alcatraz]:
FreeBSD 13.2-RELEASE-p4 GENERIC

Welcome to FreeBSD!

Release Notes, Errata: https://www.FreeBSD.org/releases/
Security Advisories:   https://www.FreeBSD.org/security/
FreeBSD Handbook:      https://www.FreeBSD.org/handbook/
FreeBSD FAQ:           https://www.FreeBSD.org/faq/
Questions List:        https://www.FreeBSD.org/lists/questions/
FreeBSD Forums:        https://forums.FreeBSD.org/

Documents installed with the system are in the /usr/local/share/doc/freebsd/
directory, or can be installed later with:  pkg install en-freebsd-doc
For other languages, replace "en" with a language code like de or fr.

Show the version of FreeBSD installed:  freebsd-version ; uname -a
Please include that output and any error messages when posting questions.
Introduction to manual pages:  man man
FreeBSD directory layout:      man hier

To change this login announcement, see motd(5).
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

Community Support
=================
If you've found a bug in Bastille, please submit it to the [Bastille Issue
Tracker](https://github.com/bastillebsd/bastille/issues/new).
