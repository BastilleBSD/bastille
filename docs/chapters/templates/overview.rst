Overview
========

Looking for ready made CI/CD validated `Bastille Templates`_?

.. _Bastille Templates: https://github.com/bastillebsd/templates

Bastille features a template system, allowing you to automate just about anything
from executing arbitrary commands to copying files all with a simple file called a
Bastillefile. A template is applied by running ``bastille template TARGET project/template``
and can also be applied to multiple targets in one go.

Before we dive into creating templates, lets take a look at the supported hooks, as
well as a brief overview of what each one is capable of.