# shellcheck shell=sh
#
# Unit spec for the target-state predicates in lib/checks.sh:
#   check_target_exists     - is NAME a known jail? (via `bastille list jails`)
#   check_target_is_running - is NAME in the running set? (via `jls name`)
#   check_target_is_stopped - inverse of the above
#
# All three match with an anchored regex (^NAME$). These specs stub the two
# host commands and, in particular, guard against the classic substring bug
# where "web" would spuriously match a jail named "webserver".

Describe 'target-state predicates'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/checks.sh"

  # `bastille list jails` -> the configured jails.
  # `jls name`            -> the currently running jails.
  mock_host_commands() {
    bastille() { printf '%s\n' web1 webserver database; }
    jls() { printf '%s\n' web1 database; }
  }
  BeforeEach 'mock_host_commands'

  Describe 'check_target_exists()'
    It 'returns success for a known jail'
      When call check_target_exists web1
      The status should be success
    End

    It 'returns failure for an unknown jail'
      When call check_target_exists nope
      The status should be failure
    End

    It 'does not match a jail name as a substring of another'
      # "web" is not itself a jail even though "web1"/"webserver" exist.
      When call check_target_exists web
      The status should be failure
    End
  End

  Describe 'check_target_is_running()'
    It 'returns success when the jail is running'
      When call check_target_is_running web1
      The status should be success
    End

    It 'returns failure when the jail is not running'
      When call check_target_is_running webserver
      The status should be failure
    End
  End

  Describe 'check_target_is_stopped()'
    It 'returns success when the jail is not running'
      When call check_target_is_stopped webserver
      The status should be success
    End

    It 'returns failure when the jail is running'
      When call check_target_is_stopped web1
      The status should be failure
    End
  End
End
