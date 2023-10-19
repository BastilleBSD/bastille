====
tags
====

The `tags` sub-command adds, removes or lists arbitrary tags on your containers.

.. code-block:: shell

  ishmael ~ # bastille tags -h                    ## display tags help
  ishmael ~ # bastille tags TARGET add tag1,tag2  ## add the tags "tag1" and "tag2" to TARGET
  ishmael ~ # bastille tags TARGET delete tag2    ## delete tag "tag2" from TARGET
  ishmael ~ # bastille tags TARGET list           ## list tags assigned to TARGET
  ishmael ~ # bastille tags ALL list              ## list tags from ALL containers
