# shellcheck shell=sh
#
# Unit spec for validate_netconf() in lib/network.sh.
#
# validate_netconf() guards two networking invariants:
#   * bastille_network_loopback and bastille_network_shared are mutually
#     exclusive, and
#   * bastille_network_vnet_type must be "if_bridge" or "netgraph".
# It reads those values from the environment (populated from bastille.conf),
# so each example just sets the relevant globals. The fixture config already
# defines bastille_network_vnet_type, so the self-healing sed branch that
# rewrites an old config file is never taken here.

Describe 'validate_netconf()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/network.sh"

  It 'accepts the fixture defaults (if_bridge, no loopback/shared)'
    When call validate_netconf
    The status should be success
  End

  It 'rejects loopback and shared being set at the same time'
    bastille_network_loopback=lo1
    bastille_network_shared=em0
    When run validate_netconf
    The status should be failure
    The stderr should include "cannot both be set"
  End

  It 'rejects an unknown vnet type'
    bastille_network_vnet_type=bogus
    When run validate_netconf
    The status should be failure
    The stderr should include "not set properly"
  End

  It 'accepts netgraph as a vnet type'
    BeforeCall 'bastille_network_vnet_type=netgraph'
    When call validate_netconf
    The status should be success
  End
End
