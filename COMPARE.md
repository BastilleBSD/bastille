
| Feature | BastilleBSD | Appjail | pot | ezjail | iocage |
| ---     | ---         | ---     | --- | ---    | ---    |
| OCI Compliant | No | Yes | No | No | No |
| Writen In | Bourne Shell | Bourne Shell, C | Bourne Shell | Bourne Shell | Bourne Shell, Rust |
| Dependencies | None | C | None | None | Rust|
| Jail Types | vnet, bridged vnet, thin, thick, empty, clone, Linux | clone, copy, tiny thin, thick, empty, linux+debootstrap | thick | basejail | clone, basejail, template, empty, thick |
| Jail dependency | Yes | Yes | Yes | No | Yes |
| Import/Export | Yes | Yes | Yes | Yes | Yes |
| Support Boot Order Priorities| Yes | Yes | No | Yes using `rcorder` | Yes |
| Linux containers | Yes  | Yes | No | No | Yes |
| Automation | Templates | Makejail, Initscripts, Images | Flavors, Images | Flavours | Plugins |
| Package Management | Yes | No | No | No | No |
| ZFS Support | Yes | Yes | Yes | No | No |
| Volume management | No | Yes | Basic | No | Basic |
| VNET Support | Yes | Yes | Yes | No | Yes |
| IPv6 Support| Yes | Yes | Yes | Yes | Yes |
| Dual Network Stack | Yes | ?? | Yes | No | No |
| Netgraph | Yes  | Yes | No | No | No | Netgraph |
| Dynamic Firewall | Yes | Yes | Yes  | No | No|
| Network Management | VLANS, Bridges | Virtual Networks, Bridges | Subnet, requires `sysutils/potnet` | No | No |
| Dynamic DEVFS Ruleset Management | No | Yes | No | No | No |
| Resource Control | Yes | Yes | CPU and Memory | No | Legacy Only |
| CPU Sets | No | Yes | Yes | Yes | Yes |
| Parallel startup | Yes | Yes (Healthcheckers, jails & NAT) | No | No | No |
| Log Management | No | Yes | No | No | No |
| Copy Files Between Jails | Yes | No | No | No | No |
| Top Support | Yes | No | No | No | No|
| HTop Support | Yes | No | No | No | No |
| X11 support | No  | Yes | No | No | No |
