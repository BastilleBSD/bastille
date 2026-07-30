# shellcheck shell=sh
#
# Unit spec for validate_cpus() in lib/checks.sh (used by 'limits'). Splits a
# comma-separated CPU list and checks each entry with `cpuset -l`. Unlike the
# other validators it returns non-zero (rather than exiting) so the caller can
# 'continue', so these cases use `When call`. cpuset(8) is stubbed: CPUs 0-3
# are "available", everything else is not.

Describe 'validate_cpus()'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/checks.sh"

  mock_cpuset() {
    # invoked as: cpuset -l <cpu>
    cpuset() {
      case "${2}" in
        0|1|2|3) return 0 ;;
        *) return 1 ;;
      esac
    }
  }
  BeforeEach 'mock_cpuset'

  It 'accepts a single available CPU'
    When call validate_cpus "2"
    The status should be success
    The output should equal ""
  End

  It 'accepts a comma-separated list of available CPUs'
    When call validate_cpus "0,1,3"
    The status should be success
    The output should equal ""
  End

  It 'rejects a list containing an unavailable CPU'
    When call validate_cpus "1,9"
    The status should be failure
    The stderr should include "CPU is not available: 9"
  End
End
