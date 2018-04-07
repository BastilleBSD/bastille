# Bastille
Bastille Jail Management Tool

## 0.1 alpha
This document outlines the basic usage of the Bastille jail management
framework. This release, obviously, is alpha quality. I make no guarantees of
quality, and if it screws up your system... Sorry, bro. DO NOT USE THIS IN
PRODUCTION unless you are the embodiment of The Chaos Monkey.

With all that said, here's how to use this tool in its current ALPHA state.

### bbsd-bootstrap
The first step is to "bootstrap" a release. Currently this uses ZFS, but I
would very much like to keep things flexible enough to not *require* ZFS. To
bootstrap a release use the `bbsd-bootstrap` command.

```shell
pebbles ~ # bbsd-bootstrap activate bastille 11.1-RELEASE
pebbles ~ #
```

This command creates the directory structure, fetches the specified release,
extracts and creates a ZFS snapshot. Once a system is "activated" it should
have everything it needs to create a jail.

```shell
pebbles ~ # ll /usr/local/bastille
total 27
drwxr-xr-x  2 root  wheel     3B Mar 17 15:34 downloads
drwxr-xr-x  2 root  wheel     8B Apr  6 18:52 fstab
drwxr-xr-x  8 root  wheel     8B Mar 31 08:35 jails
drwxr-xr-x  2 root  wheel     8B Mar 30 20:50 logs
drwxr-xr-x  3 root  wheel     3B Mar 17 15:37 releases
pebbles ~ #
```

### bbsd-create
Bastille creates jails using pre-defined templates (which are generally stored
in GitHub), and the concept of basejails. The general workflow requires three
things:

- Jail name
- Git repo / template
- FreeBSD release (ie; 11.1-RELEASE)

```shell
pebbles ~ # bbsd-create unbound0 https://github.com/bastillebsd/local_unbound.git 11.1-RELEASE
...[snip]...
pebbles ~ #
```

This command will create a 11.1-based basejail, and pre-populate the root
file system with the required configuration. At creation time the following is
done:

- 11.1-RELEASE directories created
- Git repo / template contents fetched
- Any required pkgs are installed

By default it uses the basejail concept, but I don't want it to be limited to
_just_ that in the long-term. The other jail-type that I envision is simply
ZFS-snapshots of pre-created profiles.

### bbsd-start
To start a jail you can use the `bbsd-start` command.

```shell
pebbles ~ # bbsd-start unbound0
unbound0: created
pebbles ~ #
```

This command can also take a space-separated list of jails to start.

```shell
pebbles ~ # bbsd-start unbound0 unbound1 unbound2
unbound0: created
unbound1: created
unbound2: created
pebbles ~ #
```

### bbsd-stop
To stop a jail you can use the `bbsd-stop` command.

```shell
ishmael ~ # bbsd-stop unbound0
unbound0: removed
pebbles ~ #
```

This command can also take a space-separated list of jails to stop.

```shell
pebbles ~ # bbsd-stop unbound0 unbound1 unbound2
unbound0: removed
unbound1: removed
unbound2: removed
pebbles ~ #
```

### bbsd-restart
You can probably guess what this one does. It takes the same options as
`bbsd-start` or `bbsd-stop`.

### bbsd-cmd
This tool is an extension of a tiny set of scripts I have been using personally
to manage my jails. It started out as a simple for-loop and have now evolved
into something a _little_ more mature.

```shell
pebbles ~ # bbsd-cmd ALL 'sockstat -4'
```

This command will execute the "$2" argument (note the use of quotes to
encapsulate longer commands) inside the targeted jail(s). Yes, I said
targeting, but I will admit it is VERY rudimentary. It has all the flexibility
of a simple `grep "$1"` within the list of jails, with a built-in for `ALL`.
This could/should be expanded to use PCRE and any other targeting method people
want (think SaltStack targeting options). For now, it's simple.

Remember, `bbsd-cmd TARGET "QUOTED COMMAND INCLUDING OPTIONS"` will execute the
command on *ALL* systems matching the target. Here is an example from a dev
system.

```shell
pebbles ~ # jls
 JID             IP Address      Hostname                      Path
 unbound0        10.0.0.10       unbound0                      /usr/local/bastille/jails/unbound0/root
 unbound1        10.0.0.20       unbound1                      /usr/local/bastille/jails/unbound1/root
 unbound2        10.0.0.30       unbound2                      /usr/local/bastille/jails/unbound2/root
 beastie         10.0.0.79       beastie                       /usr/local/bastille/jails/beastie/root
 xmakaba         10.0.0.137      xmakaba                       /usr/local/bastille/jails/xmakaba/root
pebbles ~ #
pebbles ~ #
pebbles ~ # bbsd-cmd unbound 'sockstat -4'
Targeting specified containers.
unbound0
unbound1
unbound2

unbound0:
USER     COMMAND    PID   FD PROTO  LOCAL ADDRESS         FOREIGN ADDRESS
unbound  unbound    9639  3  udp4   10.0.0.10:53          *:*
unbound  unbound    9639  4  tcp4   10.0.0.10:53          *:*

unbound1:
USER     COMMAND    PID   FD PROTO  LOCAL ADDRESS         FOREIGN ADDRESS
unbound  unbound    31590 3  udp4   10.0.0.20:53          *:*
unbound  unbound    31590 4  tcp4   10.0.0.20:53          *:*

unbound2:
USER     COMMAND    PID   FD PROTO  LOCAL ADDRESS         FOREIGN ADDRESS
unbound  unbound    66761 3  udp4   10.0.0.30:53          *:*
unbound  unbound    66761 4  tcp4   10.0.0.30:53          *:*

pebbles ~ # bbsd-cmd beast 'freebsd-version'
Targeting specified containers.
beastie

beastie:
11.1-RELEASE-p9

pebbles ~ #
```

As you can see, the very basic `grep` is done and limits the targeting to the
specified machine(s). The hope here is to provide flexible targeting to N
number of arbitrary systems.

### bbsd-pkg
This component is very similar to the `bbsd-cmd` tool above, but is restricted
to the `pkg` system. If you need to install, delete, upgrade or otherwise
manage installed pkgs within a jail this is the tool to use.

In documenting this section it looks like this script might need a little love.
I'll take a look when I'm done here.

### bbsd-login
This command will log you into a jail. Current support is password-less root
login, but this will support specifying users. It will likely remain
password-less.

```shell
pebbles ~ # bbsd-login beastie
root@beastie:~ # exit
pebbles ~ #
```

### bbsd-destroy
This command will destroy a non-running jail. No, it can't destroy running
jails. You have to stop them first. It takes two arguments: jail name & path.
The path, at this point, is probably extraneous. I added it initially as kind
of a fail-safe. I just need to make the script a little more mature to make
sure it handles the file system deletions properly.

```shell
pebbles ~ # bbsd-destroy unbound0 /usr/local/bastille/jails/unbound0
Jail destroyed. RIP.
pebbles ~ #
```

### bbsd-top
This one simply runs `top` in that jail. This command is interactive, as `top`
is interactive. If you want metrics other than actually running `top`, use
`bbsd-cmd TARGET 'ps -auxwww'` or the like.

### bbsd-init-repo
This command is a convenience tool to create the template structure for a
template. The idea here is that it creates all the appropriate directories
needed for a basejail-style jail. It also includes the other required template
files such as the `jail.conf` and the `pkgs.conf`.

This command requires a path argument and then creates a bunch of directories
at that path. For example.

```shell
pebbles ~ # bbsd-init-repo ~/Projects/www_nginx.git
pebbles ~ #
```

This would create the required template structure in the pre-existing directory
of `www_nginx.git` within the `Projects` directory of the users HOME. This
script also needs a little work.

This tool should be used by template developers who want to quickly create the
required structure for a template. The customization of config files can then
be put in place within that template directory structure.

I want to evolve this tool to the point where it can help churn out templates
for much of what is in the FreeBSD ports tree. Initially I expect to build
services such as DNS, SMTP, Media (Plex), SSH, browser (Firefox) jails.

## Goals
These tools are created initially with the mindset of function over form. I
want to simply prove the concept is sound for real work. The real work is a
sort of meta-jail-port system. Instead of installing the MySQL port directly on
a system, you would use Bastille to install the MySQL port within a jail
template built for MySQL. The same goes for DNS servers, and everything else in
the ports tree.

Eventually I would like to have Bastille templates created for popular
FreeBSD-based services. From Plex Media Servers to ad-blocking DNS resolvers.
From tiny SSH jails to dynamic web servers.

I don't want to tell you what you can and can't run within this framework.
There are no arbitrary limitations based on what I think may or may not be the
best way to design systems. This is not my goal.

My goal is to provide a secure framework where processes and services can run
isolated. I want to limit the scope and reach of bad actors. I want to severely
limit the target areas available to anyone that has (or has gained!) access.
