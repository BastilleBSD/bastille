# shellcheck shell=sh
#
# Unit spec for the 'config' subcommand helpers in lib/config.sh.
#
# The config get/set logic has been a repeated source of regressions, so these
# functions were factored out of config.sh so they can be exercised directly:
#
#   config_split_property  - "name=value" shorthand splitter
#   config_get_value       - parse a value out of jail(8) -e output (stdin)
#   config_set_line        - substitute/append a property line in a jail.conf
#   validate_property      - jail.conf property-name allowlist

Describe 'lib/config.sh config helpers'
  Include "${BASTILLE_SHARE}/lib/log.sh"
  Include "${BASTILLE_SHARE}/lib/config.sh"

  Describe 'config_split_property()'
    # config_split_property mutates the PROPERTY/VALUE globals in place.
    reset() { PROPERTY=""; VALUE=""; }
    BeforeEach 'reset'

    It 'splits a name=value argument into PROPERTY and VALUE'
      PROPERTY="ip4.addr=192.168.1.10"
      When call config_split_property "${PROPERTY}"
      The variable PROPERTY should equal "ip4.addr"
      The variable VALUE should equal "192.168.1.10"
    End

    It 'derives VALUE from the original argument, not the reassigned PROPERTY'
      # Regression guard: an earlier version re-read PROPERTY after overwriting
      # it, so VALUE came out wrong. VALUE must reflect the right-hand side.
      PROPERTY="host.hostname=myjail"
      When call config_split_property "${PROPERTY}"
      The variable PROPERTY should equal "host.hostname"
      The variable VALUE should equal "myjail"
    End

    It 'leaves PROPERTY/VALUE untouched when there is no = sign'
      PROPERTY="ip4.addr"
      VALUE="192.168.1.10"
      When call config_split_property "${PROPERTY}"
      The variable PROPERTY should equal "ip4.addr"
      The variable VALUE should equal "192.168.1.10"
    End
  End

  Describe 'config_get_value()'
    # Feeds representative `jail -f ... -e` output on stdin. Each parameter is
    # printed as name=value (values may be quoted) or a bare name for booleans.
    conf() {
      %text
      #|name=jail1
      #|host.hostname="jail1"
      #|ip4.addr=192.168.1.10
      #|allow.raw_sockets
    }

    It 'returns an unquoted string value'
      Data conf
      When call config_get_value ip4.addr
      The status should be success
      The output should equal "192.168.1.10"
    End

    It 'strips surrounding quotes from a value'
      Data conf
      When call config_get_value host.hostname
      The status should be success
      The output should equal "jail1"
    End

    It 'reports a valueless (boolean) property as enabled'
      Data conf
      When call config_get_value allow.raw_sockets
      The status should be success
      The output should equal "enabled"
    End

    It 'reports an absent property as "not set" with exit 120'
      Data conf
      When call config_get_value ip6.addr
      The status should equal 120
      The output should equal "not set"
    End
  End

  Describe 'config_set_line()'
    # Feeds a jail.conf stanza on stdin; prints the rewritten stanza.
    stanza() {
      %text
      #|jail1 {
      #|  host.hostname = jail1;
      #|  ip4.addr = 192.168.1.10;
      #|  path = /usr/local/bastille/jails/jail1/root;
      #|}
    }

    It 'substitutes an existing property line in place'
      Data stanza
      When call config_set_line "ip4.addr" "  ip4.addr = 10.0.0.5;"
      The status should be success
      The output should include "ip4.addr = 10.0.0.5;"
      The output should not include "192.168.1.10"
    End

    It 'appends a new property before the closing brace'
      Data stanza
      When call config_set_line "vnet" "  vnet;"
      The status should be success
      The output should include "  vnet;"
      # Original properties are preserved.
      The output should include "ip4.addr = 192.168.1.10;"
    End

    It 'replaces a boolean property line'
      Data
        #|jail1 {
        #|  vnet;
        #|}
      End
      When call config_set_line "vnet" "  novnet;"
      The status should be success
      The output should include "novnet;"
      The output should not include "  vnet;"
    End
  End

  Describe 'validate_property()'
    Parameters:value ip4.addr vnet host.hostname exec.start allow.mount.zfs

    It "accepts supported property '$1'"
      When call validate_property "$1"
      The status should be success
    End
  End

  It 'rejects an unsupported property'
    When run validate_property "totally.bogus"
    The status should be failure
    The stderr should include "Unsupported property"
  End
End
