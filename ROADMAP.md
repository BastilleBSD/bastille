Bastille Roadmap
================
This is the general roadmap for the next nine months. I would like the
near-term done by the end of 2018. The mid-term should be done by March 2019.
The long-term by summer 2019.

At that point, if the templating is mature, and the top 50 is complete, the
platform is ready for general purpose use. 


near-term
---------
1. zfs support (configurable)
2. bastille-dev template (see below):
```shell
## jail -c name=foo host.hostname=foo allow.raw_sockets children.max=99 
## ip4.addr=10.20.12.68 persist
## jexec foo /bin/csh
## foo# jail -c name=bar host.hostname=bar allow.raw_sockets 
## ip4.addr=10.20.12.68 persist
## foo# jexec bar /bin/csh
## bar# ping gritton.org
```
3. branding


mid-term
--------
1. templating
2. ssh-to-jail demo (ie; ldap + .authorized_keys + command)
```shell
## TODO: .ssh/authorized_keys auto-launch into user jail
## jail_create_login_hook() {
##     echo "permit nopass ${user} cmd /usr/sbin/jexec args ${name} /usr/bin/login -f ${user}" >> /usr/local/etc/doas.conf
##     echo "command='/usr/local/bin/doas /usr/sbin/jexec ${name} /usr/bin/login -f ${user}' ${pubkey}" >> $HOME/.ssh/authorized_keys
## }
```
3. additional modules: ps, sockstat, pf, fstab.


long-term
---------
1. top 50
2. monitoring
3. rctl
