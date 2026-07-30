# shellcheck shell=sh
#
# Unit spec for validate_ip() in lib/network.sh.
#
# validate_ip is a hot spot for regressions: it parses IPv4/IPv6, applies a
# default subnet for VNET jails, accepts the special values (DHCP/inherit/...),
# and exits non-zero on anything malformed. It exports IP4_ADDR / IP6_ADDR as
# a side effect.
#
#   * Valid cases use `When call` so we can inspect the exported variable.
#   * Malformed cases use `When run` because the function calls exit(1); a
#     subshell lets shellspec capture that as a failing status.
#
# Signature: validate_ip <ip> <vnet_jail>   (vnet_jail: 1 = VNET, 0 = not)

Describe 'lib/network.sh validate_ip()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/network.sh"

  # Clear exported results before each example so we never read a stale value.
  reset_ip() { unset IP4_ADDR IP6_ADDR 2>/dev/null || true; }
  BeforeEach 'reset_ip'

  Describe 'valid IPv4'
    It 'accepts a plain address (non-VNET)'
      When call validate_ip "192.168.1.10" 0
      The status should be success
      The variable IP4_ADDR should equal "192.168.1.10"
      The stdout should include "Valid IP"
    End

    It 'accepts an explicit CIDR for a VNET jail'
      When call validate_ip "10.0.0.5/24" 1
      The status should be success
      The variable IP4_ADDR should equal "10.0.0.5/24"
      The stdout should include "Valid IP"
    End

    It 'applies the default /24 subnet for a VNET jail with no CIDR'
      When call validate_ip "10.0.0.5" 1
      The status should be success
      The variable IP4_ADDR should equal "10.0.0.5/24"
      The stdout should include "Valid IP"
    End
  End

  Describe 'special addresses'
    It 'accepts DHCP'
      When call validate_ip "DHCP" 0
      The status should be success
      The variable IP4_ADDR should equal "DHCP"
      The stdout should include "Valid IP"
    End

    It 'maps inherit onto both IPv4 and IPv6'
      When call validate_ip "inherit" 0
      The status should be success
      The variable IP4_ADDR should equal "inherit"
      The variable IP6_ADDR should equal "inherit"
      The stdout should include "Valid IP"
    End
  End

  Describe 'valid IPv6'
    It 'accepts an address and applies the default /64 for a VNET jail'
      When call validate_ip "2001:db8::1" 1
      The status should be success
      The variable IP6_ADDR should equal "2001:db8::1/64"
      The stdout should include "Valid IP"
    End
  End

  Describe 'malformed input exits non-zero'
    Parameters:value "999.1.1.1" "256.0.0.1" "not-an-ip"

    It "rejects '$1'"
      When run validate_ip "$1" 0
      The status should be failure
      The stderr should be present
    End
  End

  Describe 'subnet validation'
    It 'rejects an out-of-range VNET subnet'
      When run validate_ip "10.0.0.5/99" 1
      The status should be failure
      The stderr should include "subnet"
    End
  End
End
