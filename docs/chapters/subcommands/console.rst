console
=======

This sub-command launches a login shell into the container. Default is password-less
root login.

.. code-block:: shell

  ishmael ~ # bastille console folsom
  [folsom]:
  FreeBSD 12.1-RELEASE-p1 GENERIC

  Welcome to FreeBSD!

  Release Notes, Errata: https://www.FreeBSD.org/releases/
  Security Advisories:   https://www.FreeBSD.org/security/
  FreeBSD Handbook:      https://www.FreeBSD.org/handbook/
  FreeBSD FAQ:           https://www.FreeBSD.org/faq/
  Questions List: https://lists.FreeBSD.org/mailman/listinfo/freebsd-questions/
  FreeBSD Forums:        https://forums.FreeBSD.org/

  Documents installed with the system are in the /usr/local/share/doc/freebsd/
  directory, or can be installed later with:  pkg install en-freebsd-doc
  For other languages, replace "en" with a language code like de or fr.

  Show the version of FreeBSD installed:  freebsd-version ; uname -a
  Please include that output and any error messages when posting questions.
  Introduction to manual pages:  man man
  FreeBSD directory layout:      man hier

  Edit /etc/motd to change this login announcement.
  root@folsom:~ #

At this point you are logged in to the container and have full shell access.  The
system is yours to use and/or abuse as you like. Any changes made inside the
container are limited to the container.
