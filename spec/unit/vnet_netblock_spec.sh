# shellcheck shell=sh
#
# Unit spec for generate_vnet_jail_netblock() and generate_static_mac().
#
# These emit the jail.conf VNET stanza -- the surface where networking
# regressions hurt most. They shell out to the host (ifconfig, sha256), so
# this file also demonstrates the pattern for the whole suite: shadow the
# external commands with shell functions ("mocks") and the logic becomes
# testable on macOS/Linux/FreeBSD with no NIC, no root, no jail.
#
# Signature:
#   generate_vnet_jail_netblock <jail_name> <interface_type> <external_if> <static_mac>
#     interface_type: standard | bridge | passthrough
#     static_mac:     1 = generate a deterministic MAC, 0 = none

Describe 'lib/network.sh generate_vnet_jail_netblock()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/network.sh"

  # Deterministic stand-ins for the host commands generate_static_mac calls.
  # sha256 is fixed so the derived MAC suffix is stable and assertable.
  mock_host_commands() {
    ifconfig() { echo "        ether 00:11:22:33:44:55"; }
    # Drain stdin (as the real sha256 does) so the upstream `sed` in the pipe
    # isn't hit with EPIPE -- GNU sed reports that on stderr and fails the run.
    sha256()   { cat >/dev/null 2>&1; echo "abcde"; }
  }
  BeforeEach 'mock_host_commands'

  Describe 'passthrough'
    It 'hands the external interface straight into the jail'
      # if_bridge is the default vnet type from the fixture config.
      When call generate_vnet_jail_netblock myjail passthrough eth0 0
      The status should be success
      The line 1 of output should equal "  vnet;"
      The output should include "vnet.interface = eth0;"
      The output should include 'exec.prestop += "ifconfig eth0 -vnet myjail";'
    End
  End

  Describe 'standard (if_bridge), no static MAC'
    It 'derives host/jail epair names from a short jail name'
      When call generate_vnet_jail_netblock myjail standard eth0 0
      The status should be success
      The output should include "vnet.interface = e0b_myjail;"
      The output should include 'exec.prestart += "jib addm myjail eth0";'
      The output should include "e0a_myjail destroy"
      # Without static MAC there must be no explicit ether line.
      The output should not include "ether 58:9c:fc"
    End
  End

  Describe 'standard (if_bridge), static MAC'
    It 'emits a deterministic FreeBSD-prefixed MAC (mocked sha256)'
      When call generate_vnet_jail_netblock myjail standard eth0 1
      The status should be success
      # prefix 58:9c:fc + suffix from sha256("...")="abcde" -> "ab:cd:e"
      The output should include "ether 58:9c:fc:ab:cd:ea"
      The output should include "ether 58:9c:fc:ab:cd:eb"
    End
  End
End
