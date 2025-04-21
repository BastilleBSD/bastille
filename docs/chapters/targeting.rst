Targeting
=========

Bastille uses a ``subcommand TARGET ARGS`` syntax, meaning that each command
requires a target. Targets are usually containers, but can also be releases.

Targeting a container is done by providing the exact jail name, the JID of the
jail, or by typing the starting few characters of a jail. If more than one
matching jail will be found, you will see a message saying so.

Targeting a release is done by providing the exact release name. (Note: do not
include the ``-pX`` point-release version.)

Bastille includes a pre-defined keyword [ALL|all] to target all running
containers. It is also possible to target multiple jails by grouping them in
quotes, as seen below.

.. code-block:: shell

  ishmael ~ # bastille cmd "jail1 jail2 jail3" echo Hello!

Examples: Containers
--------------------

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
------------------

.. code-block:: shell

  ishmael ~ # bastille ...

+-----------+--------------+--------------+------------------------------------+
| command   | target       | args         | description                        |
+===========+==============+==============+====================================+
| bootstrap | 13.2-RELEASE | ---          | bootstrap 13.2-RELEASE release     |
+-----------+--------------+--------------+------------------------------------+
| update    | 12.4-RELEASE | ---          | update 12.4-RELEASE release        |
+-----------+--------------+--------------+------------------------------------+
| verify    | 12.4-RELEASE | ---          | verify 12.4-RELEASE release        |
+-----------+--------------+--------------+------------------------------------+

Priority
--------

The priority value determines in what order commands are executed if multiple jails are targetted, including the ALL target.

It also controls in what order jails are started and stopped on system startup and shutdown. This requires Bastille to be enabled
with ``sysrc bastille_enable=YES``. Jails will start in order starting at the lowest value, and will stop in order starting
at the highest value. So, jails with a priority value of 1 will start first, and stop last.

When jails are created with Bastille, this value defaults to ``99``, but can be overridden with ``-p|--priority VALUE`` on
creation. See ``bastille create --priority 90 TARGET...``.

This value can be changed using ``bastille config TARGET set priority VALUE``.

This value will be shown using ``bastille list all``.
