Comparing
=========

Most jail managers have a table showing what they and their competitors are
capable of. While this is a good idea, the maintainers and developers of each
jail manger do not regulary visit each others projects to update these tables.

Below is a table of what we feel is most important for a jail manager, as well
as a list of popular managers and their status on each option.

| Feature | BastilleBSD | Appjail | pot | ezjail | iocage |
| ---     | ---         | ---     | --- | ---    | ---    |
| OCI Compliant | No | Yes | No | No | No |
| Writen In | Bourne Shell | Bourne Shell, C | Bourne Shell, Rust | Bourne Shell | Bourne Shell, Python |
| Dependencies | None | C | None | Rust | Python |
| Jail Types | vnet, bridged vnet, thin, thick, empty, clone, Linux | clone, copy, tiny, thin, thick, empty, linux+debootstrap | thick | basejail | clone, basejail, template, empty, thick |
| Jail dependency | Yes | Yes | Yes | No | Yes |
| Import/Export | Yes | Yes | Yes | Yes | Yes |
| Boot Order Priorities | Yes | Yes | No | Yes using `rcorder` | Yes |
| Linux Jails | Yes  | Yes | No | No | Yes |
| Automation | Templates | Makejail, Initscripts, Images | Flavours, Images | Flavours | Plugins |
| Cloning    | Yes | No   | No | No | No |
| Package Management | Yes | No | No | No | No |
| ZFS Support | Yes | Yes | Yes | No | Yes |
| Volume management | Basic | Yes | Basic | No | Basic |
| VNET Support | Yes | Yes | Yes | No | Yes |
| IPv6 Support| Yes | Yes | Yes | Yes | Yes |
| Dual Network Stack | Yes | Yes | Yes | No | No |
| Netgraph | Yes | Yes | No | No | No |
| Dynamic Firewall | Yes | Yes | Yes | No | No |
| Dynamic DEVFS Ruleset Management | No | Yes | No | No | No |
| Resource Control | Yes | Yes | CPU and Memory | No | Legacy Only |
| CPU Sets | Yes | Yes | Yes | Yes | Yes |
| Parallel Startup | Yes | Yes (Healthcheckers, jails & NAT) | No | No | No |
| Multi-Target Commands | Yes | No | No | No | No |
| Log Management | No | Yes | No | No | No |
| Copy Files Between Jails | Yes | No | No | No | No |
| Automated Jail Migration Between Servers | Yes | No | No | No | No |
| Top/Htop Support | Yes | No | No | No | No|

We do our best to stay true and honest as to what other jail managers do and don't do.
If you see an error, you can open a PR on the BastillBSD github repo.

We also realize that each jail manger does certain things better than other, and perhaps
certain things worse. Some do this, others do that. They are all different, and each user
should choose the one they want to use based on their needs.

Thanks for using BastilleBSD!