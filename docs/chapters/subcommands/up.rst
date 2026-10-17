up
==

Bastille supports a highly experimental ``up`` subcommand, which parses a ``bastille-compose.yml`` file and deploys an
OCI jail in ``${PWD}``. Lets use audiobookshelf from daemonless.io as an example:

.. code-block:: shell

  services:
    audiobookshelf:
      name: audiobookshelf
      image: "ghcr.io/daemonless/audiobookshelf:latest"
      network:
        - mode: nat
        - interface: bastille0
        - ip: 10.1.1.2
      environment:
        - PUID=1000  # User ID for the application process
        - PGID=1000  # Group ID for the application process
        - TZ=UTC  # Timezone for the container
      volumes:
        - "/host/path/audiobookshelf:/config"
        - "/host/path/audiobookshelf/metadata:/metadata"
        - "/host/path/audiobookshelf/audiobooks:/audiobooks"
      ports:
        - "13378:13378"

Bastille will use ``image`` as the image base, ``name`` as the jail name, save all
the ``environment`` variables, and forward the ports under ``ports`` (if ``mode: nat``).
Volumes will be mounted in the specified places. If no ``volumes`` annotaion is suppled,
Bastille will mount them at ``${bastille_volumesdir}/${jail}``.

The network annotaion has three available options for each service. These
are ``mode``, ``interface``, and ``ip``.

* only ``nat`` or ``host`` is supported for the ``mode`` option. If
  ``host`` is set, ``ip`` and ``interface`` are not required.
* the ``interface`` is simply the interface the service will be bound to
* the ``ip`` is the IP that will be assigned to the jail

For the ``up`` sub-command, Bastille will look for a ``.env`` file in ``${PWD}``, and if present, will
use any environment variables inside it for the deployment of the OCI image.

.. attention::

   The ``up`` sub-command is highly experimental and might be removed in a future
   version of Bastille.

See also :doc:`/chapters/jails/jail-types`

Supported Annotations
---------------------

Bastille supports the following annotations, including their indentation level.
The indentations levels are important. Bastille will not detect any indents beyond
0, 2, 4 and 6.

.. code-block:: shell

  project: generic_project_name
  services:
    generic_service_1:
      name: generic_service_1
      image: image_url
      network:
        - mode: nat # only supports nat for now
        - interface: INTERFACE
        - ip: IP
      ports:
        - host_port:jail_port
      environment:
        - KEY=VALUE
        - KEY2=VALUE2
      volumes:
        - /host:/jail
      depend:
        - generic_service_2

The ``depend`` annotation must include service names that are part of
the ``bastille-compose.yml`` stack.

Bastille will create a jail for each ``service``, named after the
service name. If ports are specified, and mode is set to ``nat``, Bastille
will also forward them to that service.

.. code-block:: shell

  ishmael ~ # bastille up help
  Usage: bastille up [option(s)]"	
