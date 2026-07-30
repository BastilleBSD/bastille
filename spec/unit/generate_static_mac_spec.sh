# shellcheck shell=sh
#
# Unit spec for generate_static_mac() in lib/network.sh.
#
# The MAC is built deterministically from the FreeBSD vendor OUI (58:9c:fc)
# plus a hash of the parent interface MAC + interface name + jail name. The
# only host dependency is `ifconfig` (to read the parent MAC); `sha256` is
# stubbed too so the generated address is fully deterministic and we can assert
# the exact format a regression would disturb.

Describe 'generate_static_mac()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/network.sh"

  # Stub the two host commands the function shells out to.
  mock_host_commands() {
    ifconfig() { echo "        ether 00:11:22:33:44:55"; }
    # A fixed digest makes the suffix deterministic regardless of input.
    sha256() { echo "0123456789abcdef"; }
  }
  BeforeEach 'mock_host_commands'

  It 'builds a MAC from the FreeBSD OUI plus a hashed suffix'
    When call generate_static_mac "myjail" "em0"
    The status should be success
    # 58:9c:fc == FreeBSD vendor prefix; suffix = first 5 hex of the digest,
    # regrouped as XX:XX:X.
    The variable macaddr should equal "58:9c:fc:01:23:4"
  End

  It 'always uses the FreeBSD vendor OUI as the prefix'
    When call generate_static_mac "otherjail" "em0"
    The status should be success
    The variable macaddr should start with "58:9c:fc:"
  End
End
