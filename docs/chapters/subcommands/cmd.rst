cmd
===

Execute commands inside targeted jail(s).

.. code-block:: shell

  ishmael ~ # bastille cmd folsom ps -auxw
  [folsom]:
  USER   PID %CPU %MEM   VSZ  RSS TT  STAT STARTED    TIME COMMAND
  root 71464  0.0  0.0 14536 2000  -  IsJ   4:52PM 0:00.00 /usr/sbin/syslogd -ss
  root 77447  0.0  0.0 16632 2140  -  SsJ   4:52PM 0:00.00 /usr/sbin/cron -J 60 -s
  root 80591  0.0  0.0 18784 2340  1  R+J   4:53PM 0:00.00 ps -auxw

.. code-block:: shell

  ishmael ~ # bastille cmd help
  Usage: bastille cmd [option(s)] TARGET COMMAND

      Options:

      -a | --auto           Auto mode. Start/stop jail(s) if required.
      -x | --debug          Enable debug mode.
