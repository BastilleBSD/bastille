2025 Bastille Roadmap
=====================

1. Bastille CI/CD
2. Container Monitoring
3. Bastille API
4. Nomad Driver for clustering

Bastille CI/CD ~ 1.0.x-beta
---------------------------------------
While we have many of the templates validated by automatic CI/CD, we are not
validating updates to Bastille itself. This automated validation of Pull
Requests should be a priority early in the year with a full test suite designed
to validate all expected uses of Bastille sub-commands.

Container Monitoring ~ 0.15.x-beta
--------------------------------------------
The ability to monitor processes, services, mounts, sockets, etc from the host.
Auto-remediation would be simple enough to define. Notifications would probably
require a plugin system for methods/endpoints.

Possible monitoring modules: ps, sockstat, pf, fstab

Possible notification modules: pagerduty, slack, splunk, ELK, etc.

Bastille API ~ 1.0.x-beta
-----------------------------------
I have thoughts about a lightweight API for Bastille that would accept (json?)
payloads of Bastille commands. The API should be lightweight just as Bastille
is.

The API is scheduled later in the roadmap because I want to have the other
components stable before we implement an API on top of it. The addition of the
API should match up with Bastille 1.0-stable.

Bastille Nomad Driver ~ 1.0.x-beta
--------------------------------------

Nomad would require a driver (probably written in Go) to funcion with bastille.
Nomad has a driver written for POT in Go so we could fashion our driver after 
the one they did.  There is an open document on how to write drivers for Nomad.
Nomad interoperability would give us clustering abilities much like a 
kubernetes cluster.



2020 Bastille Roadmap
=====================

1. Virtual Networking
1. Bastille CI/CD
1. Template Maturity & Consolidation
1. Container Monitoring
1. Bastille API

Rough timeline and description below.

Virtual Networking ~ 0.6.x-beta
-----------------------------------------
VNET (Virtual Networking) will allow fully virtualized network stacks. This
would bring the total network options to three (loopback, LAN, VNET). The
anticipated design would use a bridge device connected to containers via epair
interfaces.

Bastille CI/CD (March-May) ~ 0.7.x-beta
---------------------------------------
While we have many of the templates validated by automatic CI/CD, we are not
validating updates to Bastille itself. This automated validation of Pull
Requests should be a priority early in the year with a full test suite designed
to validate all expected uses of Bastille sub-commands.

Template Maturity & Consolidation (June-Aug) ~ 0.8.x-beta
---------------------------------------------------------
Put the 101 templates found in GitHub's BastilleBSD-Templates repository into
GitLab CI/CD pipeline until fully covered. This is a great place for community
contribution. Templates are easy to create and verify and we'd love to
replicate as much of the FreeBSD ports tree as possible!

In addition, it would be nice to create a consolidated repository of curated
templates similar in design to the FreeBSD ports tree. This would contain all
templates in a single repository and mimick ports behavior where appropriate.

Container Monitoring (Sept-Oct) ~ 0.9.x-beta
--------------------------------------------
The ability to monitor processes, services, mounts, sockets, etc from the host.
Auto-remediation would be simple enough to define. Notifications would probably
require a plugin system for methods/endpoints.

Possible monitoring modules: ps, sockstat, pf, fstab

Possible notification modules: pagerduty, slack, splunk, ELK, etc.

Bastille API (Nov-Dec) ~ 1.0.x-beta
-----------------------------------
I have thoughts about a lightweight API for Bastille that would accept (json?)
payloads of Bastille commands. The API should be lightweight just as Bastille
is.

The API is scheduled later in the roadmap because I want to have the other
components stable before we implement an API on top of it. The addition of the
API should match up with Bastille 1.0-stable.
