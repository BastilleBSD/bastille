Targeting
=========

Bastille uses a `command-target-args` syntax, meaning that each command
requires a target. Targets are usually containers, but can also be releases.

Targeting a containers is done by providing the exact containers name.

Targeting a release is done by providing the release name. (Note: do note
include the `-pX` point-release version.)

Bastille includes a pre-defined keyword ALL to target all running containers.

In the future I would like to support more options, including globbing, lists
and regular-expressions.

Examples: Containers
====================

.. code-block:: shell

  ishmael ~ # bastille ...

+-----------+--------+------------------+-------------------------------------------------------------+
| command   | target | args             | description                                                 |
+===========+========+==================+=============================================================+
| cmd       | ALL    | 'sockstat -4'    | execute `sockstat -4` in ALL containers (ip4 sockets)       |
+-----------+--------+-----+------------+-------------------------------------------------------------+
| console   | mariadb02    | ---        | console (shell) access to mariadb02                         |
+----+------+----+---------+------------+--------------+----------------------------------------------+
| pkg       | web01  | 'install nginx'  | install nginx package in web01 container                    |
+-----------+--------+------------------+-------------------------------------------------------------+
| pkg       | ALL    | upgrade          | upgrade packages in ALL containers                          |
+-----------+--------+------------------+-------------------------------------------------------------+
| pkg       | ALL    | audit            | (CVE) audit packages in ALL containers                      |
+-----------+--------+------------------+-------------------------------------------------------------+
| sysrc     | web01  | nginx_enable=YES | execute `sysrc nginx_enable=YES` in web01 container         |
+-----------+--------+------------------+-------------------------------------------------------------+
| template  | ALL    | username/base    | apply `username/base` template to ALL containers            |
+-----------+--------+------------------+-------------------------------------------------------------+
| start     | web02  | ---              | start web02 container                                       |
+-----------+--------+-----+------------+-------------------------------------------------------------+
| cp | bastion03 | /tmp/resolv.conf-cf etc/resolv.conf | copy host-path to container-path in bastion03|
+----+------+----+---+------------------+--------------+----------------------------------------------+
| create    | folsom | 12.0-RELEASE 10.17.89.10        | create 12.0 container named `folsom` with IP |
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
| update    | 11.3-RELEASE | ---          | update 11.2-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+
| upgrade   | 11.2-RELEASE | 11.3-RELEASE | update 11.2-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+
| verify    | 11.3-RELEASE | ---          | update 11.2-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+
