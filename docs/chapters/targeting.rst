=========
Targeting
=========

Bastille uses a `command-target-args` syntax, meaning that each command
requires a target. Targets are usually jails, but can also be releases.

Targeting a jail is done by providing the exact jail name.

Targeting a release is done by providing the release name. (Note: do note
include the `-pX` point-release version.)

Bastille includes a pre-defined keyword ALL to target all running jails.

In the future I would like to support more options, including globbing, lists
and regular-expressions.

Examples: Jails
===============

.. code-block:: shell

  ishmael ~ # bastille ...


+-----------+--------+------------------+-------------------------------------------------------------+
| command   | target | args             | description                                                 |
+===========+========+==================+=============================================================+
| cmd       | ALL    | 'sockstat -4'    | execute `sockstat -4` in ALL jails (listening ip4 sockets)  |
+-----------+--------+-----+------------+-------------------------------------------------------------+ 
| console   | mariadb02    | ---        | console (shell) access to mariadb02                         |
+----+------+----+---------+------------+--------------+----------------------------------------------+ 
| pkg       | web01  | 'install nginx'  | install nginx package in web01 jail                         |
+-----------+--------+------------------+-------------------------------------------------------------+
| pkg       | ALL    | upgrade          | upgrade packages in ALL jails                               |
+-----------+--------+------------------+-------------------------------------------------------------+ 
| pkg       | ALL    | audit            | (CVE) audit packages in ALL jails                           |
+-----------+--------+------------------+-------------------------------------------------------------+ 
| sysrc     | web01  | nginx_enable=YES | execute `sysrc nginx_enable=YES` in web01 jail              |
+-----------+--------+------------------+-------------------------------------------------------------+ 
| template  | ALL    | base             | apply `base` template to ALL jails                          |
+-----------+--------+------------------+-------------------------------------------------------------+ 
| start     | web02  | ---              | start web02 jail                                            |
+-----------+--------+-----+------------+-------------------------------------------------------------+ 
| cp | bastion03 | /tmp/resolv.conf-cf etc/resolv.conf | copy host-path to jail-path in bastion03     |
+----+------+----+---+------------------+--------------+----------------------------------------------+ 
| create    | folsom | 12.0-RELEASE 10.10.10.10        | create v12.0 jail named `folsom` with IP     |
+-----------+--------+------------------+--------------+----------------------------------------------+


Examples: Releases
==================

.. code-block:: shell

  ishmael ~ # bastille ...


+-----------+--------------+--------------+-------------------------------------------------------------+
| command   | target       | args         | description                                                 |
+===========+==============+==============+=============================================================+
| bootstrap | 12.0-RELEASE | ---          | bootstrap 12.0-RELEASE release                              |
+-----------+--------------+--------------+-------------------------------------------------------------+ 
| update    | 11.2-RELEASE | ---          | update 11.2-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+ 
| upgrade   | 11.1-RELEASE | 11.2-RELEASE | update 11.2-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+ 
| verify    | 11.2-RELEASE | ---          | update 11.2-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+ 
