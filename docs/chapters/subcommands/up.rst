up
==

Bastille supports a highly experimental ``up`` subcommand, which parses a ``podman-compose.yml`` file and deploys an
OCI jail in ``${PWD}``. Lets use audiobookshelf from daemonless.io as an example:

.. code-block:: shell

  services:
    audiobookshelf:
      image: "ghcr.io/daemonless/audiobookshelf:latest"
      container_name: audiobookshelf
      environment:
        - PUID=1000  # User ID for the application process
        - PGID=1000  # Group ID for the application process
        - TZ=UTC  # Timezone for the container
      volumes:
        - "/path/to/containers/audiobookshelf:/config"
        - "/path/to/containers/audiobookshelf/metadata:/metadata"
        - "/path/to/containers/audiobookshelf/audiobooks:/audiobooks"
      ports:
        - "13378:13378"
      restart: unless-stopped

First, Bastille does not use the ``volumes`` annotation. It stores its volumes at ``${bastille_volumesdir}``. It will
use ``image`` as the image base, ``container_name`` as the jail name, save all the ``environment`` variables, and
forward the ports under ``ports`` (if the jail is a NAT jail).

Notice though that there is no network option. If no network option is given, Bastille will default to ``inherit``. To
specify an IP for the jail, add the following:

.. code-block:: shell

      network: 10.0.0.3

This will create the jail with the specified IP.

For the ``up`` sub-command, Bastille will look for a ``.env`` file in ``${PWD}``, and if present, will
use any environment variables inside it for the deployment of the OCI image.

.. attention::

   The ``up`` sub-command is highly experimental and might be removed in a future
   version of Bastille.

See also :doc:`/chapters/jails/jail-types`

.. code-block:: shell

  ishmael ~ # bastille up help
  Usage: bastille up [option(s)]"

      Options:
	
      -d | --data-path PATH     Override path to persistent data.