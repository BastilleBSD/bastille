Installation
============

Bastille is not (yet) in the official ports tree, but I have built and
verified binary packages.

To install using one of the BETA binary packages, copy the URL for the
latest release here (TXZ file):
https://github.com/bastillebsd/bastille/releases

Then, install via pkg. 
Example:

.. code-block:: shell

  pkg add https://github.com/BastilleBSD/bastille/releases/download/0.3.20181124/bastille-0.3.20181124.txz

BETA binary packages are signed. These can be verified with this pubkey:

.. code-block:: shell

  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq28OLDhJ12JmsKKcJpnn
  pCW3fFYBNI1BtdvTvFx57ZXvQ2qecBvnR9+XWi83hKS9ALTKZI6CLC2uTv1fIsZl
  u6rDRRNZwZFfITACSfwI+7UObMXz3oBZjk94J3rIegk49EyjDswKdVWv5k1EiVXF
  SAwXSl2kA2hGfQJkj5NS4nrfoRBc0z6fm+BGdNuHKSTmeZh1dbLEHt9EArD20DJ7
  HIr8vUSPLwONeqJCBFA/MeDO+GpwtwA/ldc2ZZy1RCPctdC2NeiGW7oy1yVDu6wp
  mHCq8qDfmCx5Aex84rWUf9iH8TM92AWmegTaz2p+BgESctpjNRCUuSEwOCBIO6g5
  3wIDAQAB
  -----END PUBLIC KEY-----
