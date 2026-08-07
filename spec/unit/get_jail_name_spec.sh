# shellcheck shell=sh
#
# Unit spec for get_jail_name() in lib/target.sh, which maps a JID to a jail name
# via `jls -j <jid> name` and returns non-zero when the JID is unknown.

Describe 'get_jail_name()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/target.sh"

  # Stub jls: JID 42 resolves to "myjail"; anything else prints nothing (as the
  # real jls does for an unknown JID).
  mock_jls() {
    jls() {
      # invoked as: jls -j <jid> name
      if [ "${2}" = "42" ]; then
        echo "myjail"
      fi
    }
  }
  BeforeEach 'mock_jls'

  It 'prints the jail name for a known JID'
    When call get_jail_name 42
    The status should be success
    The output should equal "myjail"
  End

  It 'returns failure for an unknown JID'
    When call get_jail_name 999
    The status should be failure
    The output should equal ""
  End
End
