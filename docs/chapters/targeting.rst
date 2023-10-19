Targeting
=========

Bastille uses a `command target arguments` syntax, meaning that each command
requires a target. Targets are usually containers, but can also be releases.

Targeting a container is done by providing the exact containers name.

Targeting a release is done by providing the release name. (Note: do not
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
+----+------+--------+-----+------------+-------------------------------------------------------------+
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
+----+------+----+---+------------------+--------------+----------------------------------------------+
| cp | bastion03 | /tmp/resolv.conf-cf etc/resolv.conf | copy host-path to container-path in bastion03|
+----+------+----+---+---------------------------------+----------------------------------------------+
| create    | folsom | 13.2-RELEASE 10.17.89.10        | create 13.2 container named `folsom` with IP |
+-----------+--------+---------------------------------+----------------------------------------------+


Examples: Releases
==================

.. code-block:: shell

  ishmael ~ # bastille ...

+-----------+--------------+--------------+-------------------------------------------------------------+
| command   | target       | args         | description                                                 |
+===========+==============+==============+=============================================================+
| bootstrap | 13.2-RELEASE | ---          | bootstrap 13.2-RELEASE release                              |
+-----------+--------------+--------------+-------------------------------------------------------------+
| update    | 12.4-RELEASE | ---          | update 12.4-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+
| verify    | 12.4-RELEASE | ---          | verify 12.4-RELEASE release                                 |
+-----------+--------------+--------------+-------------------------------------------------------------+
