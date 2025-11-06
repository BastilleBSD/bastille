Comparing
=========

Most jail managers have a table showing what they and their competitors are
capable of. While this is a good idea, the maintainers and developers of each
jail manger do not regulary visit each others projects to update these tables.

Below is a table of what we feel is most important for a jail manager, as well
as a list of popular managers and their status on each option.

+--------------+-------------+--------------+-----------+-----------+-----------+
| Feature      | BastilleBSD | Appjail      | pot       | ezjail    | iocage    |
+==============+=============+==============+===========+===========+===========+
| OCI          | No          | Yes          | No        | No        | No        |
| Compliant    |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Writen In    | Bourne      | Bourne       | Bourne    | Bourne    | Bourne    |
|              | Shell       | Shell, C     | Shell,    | Shell     | Shell,    |
|              |             |              | Rust      |           | Python    |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Dep          | None        | C            | Rust      | None      | Python    |
| endencies    |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Jail         | vnet,       | clone,       | thick     | basejail  | clone,    |
| Types        | bridged     | copy,        |           |           | basejail, |
|              | vnet,       | tiny,        |           |           | template, |
|              | thin,       | thin,        |           |           | empty,    |
|              | thick,      | thick,       |           |           | thick     |
|              | empty,      | empty,       |           |           |           |
|              | clone,      | linux+de     |           |           |           |
|              | Linux       | bootstrap    |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Jail         | Yes         | Yes          | Yes       | No        | Yes       |
| Dependency   |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Impo         | Yes         | Yes          | Yes       | Yes       | Yes       |
| rt/Export    |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Boot         | Yes         | Yes          | No        | Yes using | Yes       |
| Order        |             |              |           | 'rcorder' |           |
| Priorities   |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Linux        | Yes         | Yes          | No        | No        | Yes       |
| c            |             |              |           |           |           |
| ontainers    |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Automation   | Templates   | Makejail,    | Flavours, | Flavours  | Plugins   |
|              |             | Initscripts, | Images    |           |           |
|              |             | Images       |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Cloning      | Yes         | No           | No        | No        | No        |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Package      | Yes         | No           | No        | No        | No        |
| Management   |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| ZFS          | Yes         | Yes          | Yes       | No        | Yes       |
| Support      |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Volume       | Basic       | Yes          | Basic     | No        | Basic     |
| Management   |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| VNET         | Yes         | Yes          | Yes       | No        | Yes       |
| Support      |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| IPv6         | Yes         | Yes          | Yes       | Yes       | Yes       |
| Support      |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Dual         | Yes         | Yes          | Yes       | No        | No        |
| Network      |             |              |           |           |           |
| Stack        |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Netgraph     | Yes         | Yes          | No        | No        | No        |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Dynamic      | Yes         | Yes          | Yes       | No        | No        |
| Firewall     |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Dynamic      | No          | Yes          | No        | No        | No        |
| DEVFS        |             |              |           |           |           |
| Ruleset      |             |              |           |           |           |
| Management   |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Resource     | Yes         | Yes          | CPU and   | No        | Legacy    |
| Control      |             |              | Memory    |           | Only      |
+--------------+-------------+--------------+-----------+-----------+-----------+
| CPU Sets     | Yes         | Yes          | Yes       | Yes       | Yes       |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Parallel     | Yes         | Yes          | No        | No        | No        |
| Startup      |             | (Health      |           |           |           |
|              |             | checkers,    |           |           |           |
|              |             | jails &      |           |           |           |
|              |             | NAT)         |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| PkgBase      | Yes         | Yes          | No        | No        | No        |
| Support      |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Multi-target | Yes         | No           | No        | No        | No        |
| Commands     |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Log          | Basic       | Yes          | No        | No        | No        |
| Management   | (console    |              |           |           |           |
|              | logs)       |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Copy         | Yes         | No           | No        | No        | No        |
| Files        |             |              |           |           |           |
| Between      |             |              |           |           |           |
| Jails        |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Automated    | Yes         | No           | No        | No        | No        |
| Jail         |             |              |           |           |           |
| Migration    |             |              |           |           |           |
| Between      |             |              |           |           |           |
| Servers      |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+
| Top/Htop     | Yes         | No           | No        | No        | No        |
| Support      |             |              |           |           |           |
+--------------+-------------+--------------+-----------+-----------+-----------+

We do our best to stay true and honest as to what other jail managers do and
don't do.
If you see an error, you can open a PR on the BastillBSD github repo.

We also realize that each jail manger does certain things better than other, and
perhaps certain things worse. Some do this, others do that. They are all
different, and each user should choose the one they want to use based on their
needs.

Thanks for using BastilleBSD!
