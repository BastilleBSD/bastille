Jailing a Dataset
=================

It is possible to "jail" a dataset. This means mounting a datset into a jail,
and being able to fully manage it from within the jail.

To add a dataset to a jail, we can run
``bastille zfs TARGET jail pool/dataset /path/inside/jail``.
This will assign ``pool/dataset`` to the jail and mount it
at ``/path/inside/jail``.

You can manually change the path where the dataset will be mounted by
``bastille edit TARGET zfs.conf`` and adjusting the path after you have added it,
bearing in mind the warning below.

WARNING: Adding or removing datasets to the ``zfs.conf`` file can result in
permission errors with your jail. It is important that the jail is first stopped
before attempting to manually configure this file. The format inside the file is
simple.

.. code-block:: shell

  pool/dataset /path/in/jail
  pool/other/dataset /other/path/in/jail

To remove a dataset from being jailed, we can run
``bastille zfs TARGET unjail pool/dataset``.

NOTE: You must unjail any jailed datasets before attempting to destroy
a jail.
