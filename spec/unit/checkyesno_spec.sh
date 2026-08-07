# shellcheck shell=sh
#
# Unit spec for checkyesno() in lib/checks.sh.
#
# checkyesno mirrors rc.subr: it reads the *named* variable and returns 0 for
# an enabled value (YES/TRUE/ON/1, any case), 1 otherwise. Bastille gates ZFS
# and other behavior on it, so a regression here silently flips features.

Describe 'lib/checks.sh checkyesno()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/checks.sh"

  Describe 'enabled values return success (0)'
    Parameters:value YES yes Yes TRUE true On on 1

    It "treats '$1' as enabled"
      flag="$1"
      When call checkyesno flag
      The status should be success
    End
  End

  Describe 'disabled values return failure (1)'
    Parameters:value NO no False FALSE Off off 0

    It "treats '$1' as disabled"
      flag="$1"
      When call checkyesno flag
      The status should be failure
    End
  End

  # warn() writes to stdout (only error_notify/error_exit go to stderr), so the
  # "not set properly" notice is asserted against stdout.
  It 'warns and fails on an unrecognized value'
    flag="garbage"
    When call checkyesno flag
    The status should be failure
    The stdout should include "not set properly"
  End

  It 'fails when the variable is unset/empty'
    unset flag 2>/dev/null || true
    When call checkyesno flag
    The status should be failure
    The stdout should include "not set properly"
  End
End
