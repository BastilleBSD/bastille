# shellcheck shell=sh
#
# Unit spec for validate_release_name() in lib/checks.sh (used by 'convert').
# A valid name contains only [a-zA-Z0-9-_] and does not begin with '-' or '_'.
# Invalid names call error_exit, so those cases use `When run`.

Describe 'validate_release_name()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/checks.sh"

  It 'accepts a plain alphanumeric name'
    # Note: the validator strips dots, so a value like "13.2-RELEASE" is
    # rejected as a "special character" name -- keep names dot-free.
    When call validate_release_name "132RELEASE"
    The status should be success
  End

  It 'accepts names with hyphens and underscores'
    When call validate_release_name "my-release_1"
    The status should be success
  End

  It 'rejects a name beginning with a hyphen'
    When run validate_release_name "-bad"
    The status should be failure
    The stderr should include "may not begin with"
  End

  It 'rejects a name beginning with an underscore'
    When run validate_release_name "_bad"
    The status should be failure
    The stderr should include "may not begin with"
  End

  It 'rejects a name containing special characters'
    When run validate_release_name "bad/name"
    The status should be failure
    The stderr should include "special characters"
  End
End
