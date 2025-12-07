tags
====

.. code-block:: shell

  ishmael ~ # bastille tags help                  ## display tags help
  ishmael ~ # bastille tags TARGET add tag1,tag2  ## add the tags "tag1" and "tag2" to TARGET
  ishmael ~ # bastille tags TARGET delete tag2    ## delete tag "tag2" from TARGET
  ishmael ~ # bastille tags TARGET list           ## list tags assigned to TARGET
  ishmael ~ # bastille tags ALL list              ## list tags from ALL containers

.. code-block:: shell

  ishmael ~ # bastille tags help
  Usage: bastille tags [option(s)] TARGET add|delete TAG1,TAG2
                                   TARGET list [TAG]

      Options:

      -x | --debug     Enable debug mode.