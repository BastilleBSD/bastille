config
======

Getting a property that *is* defined in jail.conf:

.. code-block:: shell

  ishmael ~ # bastille config azkaban get ip4.addr
  bastille0|192.168.2.23

Getting a property that *is not* defined in jail.conf

.. code-block:: shell

  ishmael ~ # bastille config azkaban get notaproperty
  not set

Getting several properties at once (comma-separated). A single property
still prints only its value; multiple properties print a table:

.. code-block:: shell

  ishmael ~ # bastille config alcatraz get name,securelevel,osrelease
  PROPERTY     VALUE
  name         alcatraz
  securelevel  2
  osrelease    15.1-RELEASE

Getting a property from every jail. Multiple jails always print a
``JID JAIL PROPERTY VALUE`` table (stopped jails show ``-`` in the
``JID`` column):

.. code-block:: shell

  ishmael ~ # bastille config ALL get securelevel
  JID  JAIL         PROPERTY     VALUE
  2    alcatraz     securelevel  2
  3    bella        securelevel  2
  1    gorgona      securelevel  2

Several properties across every jail use the same four columns, one
row per jail and property:

.. code-block:: shell

  ishmael ~ # bastille config ALL get name,securelevel
  JID  JAIL         PROPERTY     VALUE
  2    alcatraz     name         alcatraz
  2    alcatraz     securelevel  2
  3    bella        name         bella
  3    bella        securelevel  2
  1    gorgona      name         gorgona
  1    gorgona      securelevel  2

Setting a property:

.. code-block:: shell

  ishmael ~ # bastille config azkaban set allow.mlock 1
  A restart is required for the changes to be applied. See 'bastille restart azkaban'.

The restart message will appear every time a property is set.

Removing a property:

.. code-block:: shell

  ishmael ~ # bastille config azkaban remove allow.mlock
  A restart is required for the changes to be applied. See 'bastille restart azkaban'.

The restart message will appear every time a property is removed.

JSON output
-----------

The ``get`` action supports JSON output via the global ``-j|--json`` flag
(add ``-p|--pretty`` for indented output). Each targeted jail is emitted as an
object in a ``jail`` array:

.. code-block:: shell

  ishmael ~ # bastille -j config ALL get securelevel
  {"bastille": {"type":"jail", "jail": [{"jid":1,"name":"alcatraz","securelevel":"2"}, {"jid":null,"name":"bella","securelevel":"2"}, {"jid":2,"name":"gorgona","securelevel":"2"}]}}

Each record leads with its ``jid`` — a native number when the jail is running,
or ``null`` when it is not (as with ``bella`` above) — followed by the jail
``name`` and then the queried property as a field named after the property
itself (``securelevel`` here). The sibling ``type`` repeats the array key
(``jail``) so a consumer can read ``.bastille.type`` and index into
``.bastille[.type]`` without knowing the command.

A request-level failure (unknown jail, unsupported property, missing
arguments) still prints on stderr and also emits a sibling ``error``
object so an API client can read ``.bastille.error.message`` instead of
scraping stderr. The process exits 1:

.. code-block:: shell

  ishmael ~ # bastille -j config nosuch get ip4.addr
  {"bastille": {"type":"error", "error": {"message":"[ERROR]: Jail not found: nosuch"}}}

.. code-block:: shell

  ishmael ~ # bastille -p config alcatraz get securelevel
  {
    "bastille": {
      "type": "jail",
      "jail": [
        {
          "jid": 1,
          "name": "alcatraz",
          "securelevel": "2"
        }
      ]
    }
  }

Multiple properties become extra fields on the same jail object
(``name`` is not duplicated when it is also queried):

.. code-block:: shell

  ishmael ~ # bastille -j config alcatraz get name,securelevel,osrelease
  {"bastille": {"type":"jail", "jail": [{"jid":1,"name":"alcatraz","securelevel":"2","osrelease":"15.1-RELEASE"}]}}

.. code-block:: shell

  ishmael ~ # bastille config help
  Usage: bastille config [option(s)] TARGET set|add PROPERTY [VALUE]
                                            get PROPERTY[,PROPERTY...]
                                            remove PROPERTY