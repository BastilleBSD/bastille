# shellcheck shell=sh
#
# Unit spec for check_rdr_ip_validity() in lib/network.sh (used by the 'rdr'
# subcommand). Accepts IPv4 (optionally with a /CIDR), IPv6, and SLAAC;
# rejects malformed addresses and out-of-range octets. Invalid inputs call
# error_exit (which calls exit), so those cases use `When run`.

Describe 'check_rdr_ip_validity()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/network.sh"

  Describe 'valid addresses'
    It 'accepts a dotted-quad IPv4 address'
      When call check_rdr_ip_validity "192.168.1.10"
      The status should be success
      The stdout should include "Valid"
    End

    It 'accepts an IPv4 address with a CIDR suffix'
      When call check_rdr_ip_validity "10.0.0.1/24"
      The status should be success
      The stdout should include "Valid"
    End

    It 'accepts an IPv6 address'
      When call check_rdr_ip_validity "2001:db8::1"
      The status should be success
      The stdout should include "Valid"
    End

    It 'accepts SLAAC'
      When call check_rdr_ip_validity "SLAAC"
      The status should be success
      The stdout should include "Valid"
    End
  End

  Describe 'invalid addresses'
    It 'rejects a malformed address'
      When run check_rdr_ip_validity "not.an.ip"
      The status should be failure
      The stderr should include "Invalid"
    End

    It 'rejects an out-of-range octet'
      When run check_rdr_ip_validity "192.168.1.999"
      The status should be failure
      The stderr should include "Invalid"
    End
  End
End
