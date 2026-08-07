# Bastille test suite

Bastille has two tiers of tests. Run the fast one constantly; run the slow one
before releases or when touching jail/network/ZFS behavior.

## Tier 1 — Unit tests (fast, runs anywhere)

Pure-logic tests written with [shellspec](https://shellspec.info), a POSIX
`/bin/sh` test framework. They source Bastille's shell modules directly and
call individual functions, stubbing out host commands (`ifconfig`, `zfs`,
`jls`, ...) so **no root, no jails, and no FreeBSD host are required**. They
run in under a second on macOS, Linux, or FreeBSD, and gate every pull request
via `.github/workflows/unit-tests.yml`.

These catch the class of regression that "many contributors" tends to
introduce: argument parsing, IP/subnet validation, MAC generation, the
`jail.conf` VNET stanza generator, config get/set string handling, and so on.

### Running

```sh
# Install shellspec once:
curl -fsSL https://raw.githubusercontent.com/shellspec/shellspec/master/install.sh | sh
#   (or) brew install shellspec

make test          # or: make test-unit
#   (or) shellspec
```

### Layout

The function libraries under `usr/local/share/bastille/lib/` (`log.sh`,
`checks.sh`, `config.sh`, `target.sh`, `network.sh`, `storage.sh`,
`migrate.sh`) are pure definitions, so a spec sources just the lib it needs
rather than the whole of `common.sh`.

```
.shellspec               # shellspec options (forces --shell sh)
spec/
  spec_helper.sh         # sources the fixture config; sets NO_COLOR etc.
  fixtures/bastille.conf # inert config consumed by `. ${BASTILLE_CONFIG}`
  unit/
    checkyesno_spec.sh            # rc.subr-style boolean parsing
    validate_ip_spec.sh           # IPv4/IPv6/subnet/special-value validation
    vnet_netblock_spec.sh         # jail.conf VNET stanza + static MAC (mocked host)
    config_spec.sh                # config get/set helpers (split/get/set/validate)
    generate_static_mac_spec.sh   # deterministic FreeBSD-prefixed MAC (mocked host)
    validate_netconf_spec.sh      # loopback/shared + vnet_type invariants
    check_target_spec.sh          # exists/running/stopped predicates (anchored match)
    get_jail_name_spec.sh         # JID -> name lookup (mocked jls)
    check_rdr_ip_validity_spec.sh # rdr IPv4/IPv6/SLAAC validation
    validate_release_name_spec.sh # convert release-name rules
    validate_cpus_spec.sh         # limits CPU-list validation (mocked cpuset)
```

### Adding a unit test

1. Create `spec/unit/<name>_spec.sh`.
2. `Include "${BASTILLE_SHARE}/lib/<lib>.sh"` for each lib that defines the
   functions under test (e.g. `lib/log.sh` for `error_exit`/`warn`/`info`,
   plus `lib/network.sh`, `lib/checks.sh`, `lib/config.sh`, ...).
3. Use `When call <fn> ...` to inspect exported variables, or `When run <fn>
   ...` for functions that call `exit`.
4. Shadow any host command the function shells out to by defining a shell
   function of the same name in a `BeforeEach` — see `vnet_netblock_spec.sh`
   for the pattern (`ifconfig`/`sha256` mocks).

## Tier 2 — End-to-end / integration (FreeBSD only)

The `Bastillefile` suites (`tests/core`, `tests/unit-tests`, `tests/zfs-tests`,
`tests/ufs-tests`) deploy real jails and exercise full command flows against a
live FreeBSD kernel, ZFS/UFS, and networking. They require root and a FreeBSD
host, so they run on a schedule / on demand via
`.github/workflows/freebsd-e2e.yml` rather than gating PRs.

For local runs, use the `Vagrantfile` to bring up a FreeBSD VM
(`vagrant up && vagrant ssh`), then `make install` and drive the suite there.

> Note: `tests/unit-tests/` is a historical name — those are integration
> scenarios (create → start → stop → destroy), not unit tests. Tier 1 above is
> the unit layer.
