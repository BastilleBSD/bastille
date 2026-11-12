#!/bin/sh
# Run as an ordinary user on FreeBSD; no Bastille installation or real jails needed.
# Usage: sh tests/regress/list-tempfiles.sh [path/to/list.sh]
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
source=${1:-${repo}/usr/local/share/bastille/list.sh}
work=$(mktemp -d /tmp/bastille-regression.XXXXXXXXXX)
trap 'rm -rf -- "${work}"' 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15
mkdir "${work}/sandbox" "${work}/jails"
for jail in Alpha Bravo Charlie Delta Echo Foxtrot; do
    mkdir "${work}/jails/${jail}"
    : > "${work}/jails/${jail}/jail.conf"
done

cat > "${work}/common.sh" <<'EOF'
error_exit() { echo "$*" >&2; exit 1; }
error_notify() { echo "$*" >&2; }
bastille_root_check() { :; }
set_target() { TARGET="$1"; }
enable_debug() { :; }
EOF

cat > "${work}/mock.sh" <<'EOF'
get_max_lengths() {
    for field in JID JAIL_NAME JAIL_BOOT JAIL_PRIO JAIL_STATE JAIL_TYPE JAIL_IP JAIL_PORTS JAIL_RELEASE JAIL_TAGS JAIL_HOSTNAME; do
        eval "MAX_LENGTH_${field}=24"
    done
    SPACER=2
}
get_jail_list() {
    JAIL_LIST="${TARGET:-Alpha Bravo Charlie Delta Echo Foxtrot}"
}
get_jail_info() {
    : > "${TEST_ROOT}/ready-${TEST_TOKEN}"
    sleep "${TEST_DELAY}"
    JID="${TEST_TOKEN}"
    JAIL_NAME="$1"
    BOOT=on
    JAIL_BOOT=on
    PRIORITY=99
    JAIL_PRIO=99
    JAIL_STATE=Up
    JAIL_TYPE=thin
    JAIL_IP="192.0.2.${TEST_TOKEN}"
    JAIL_IP_FULL="${JAIL_IP}"
    JAIL_PORTS="${TEST_TOKEN}"
    JAIL_PORTS_FULL="${TEST_TOKEN}"
    JAIL_HOSTNAME="run${TEST_TOKEN}-$1"
    JAIL_RELEASE=14.4-RELEASE
    JAIL_PATH="/mock/${TEST_TOKEN}/$1"
    JAIL_TAGS="run${TEST_TOKEN}"
}
EOF

# Rewrite every temporary path into the private sandbox and replace metadata
# helpers before argument dispatch. Never source the installed common.sh.
awk -v sandbox="${work}/sandbox" -v mocks="${work}/mock.sh" '
    $0 == ". /usr/local/share/bastille/common.sh" {
        print ". \"${TEST_COMMON}\""; next
    }
    $0 == "TARGET=\"\"" {
        while ((getline line < mocks) > 0) print line
        close(mocks)
    }
    { gsub(/\/tmp\/bastille-list/, sandbox "/bastille-list"); print }
' "${source}" > "${work}/list.sh"
TEST_ROOT=${work}
TEST_COMMON=${work}/common.sh
bastille_jailsdir=${work}/jails
export TEST_ROOT TEST_COMMON bastille_jailsdir

run_list() {
    token=$1
    delay=$2
    shift 2
    TEST_TOKEN=${token} TEST_DELAY=${delay} /bin/sh "${work}/list.sh" "$@"
}
fail() { echo "FAIL: $*" >&2; exit 1; }
empty_stderr() { [ ! -s "$1" ] || { cat "$1" >&2; fail "list emitted diagnostics"; }; }
no_private_dirs() {
    for entry in "${work}/sandbox"/bastille-list.*; do
        [ ! -e "${entry}" ] || fail "temporary directory leaked: ${entry}"
    done
}

# Simulate cleanup by an older invocation after the slow run has opened a row.
run_list 80 0 > "${work}/expected80" 2> "${work}/expected80.err"
empty_stderr "${work}/expected80.err"
rm -f "${work}/ready-80"
run_list 80 .4 > "${work}/out80" 2> "${work}/err80" &
pid=$!
tries=0
while [ ! -e "${work}/ready-80" ]; do
    tries=$((tries + 1))
    [ "${tries}" -le 500 ] || fail "slow invocation never created a row"
    sleep .01
done
# This intentionally models the old cleanup, inside the test sandbox only.
rm -rf "${work}/sandbox"/bastille-list-*
wait "${pid}" || fail "slow invocation failed"
empty_stderr "${work}/err80"
cmp -s "${work}/expected80" "${work}/out80" || fail "legacy cleanup corrupted output"
no_private_dirs

# Check all temporary-file list implementations and representative JSON paths.
for kind in table all ip path port state type; do
    if [ "${kind}" = table ]; then
        run_list 81 0 > "${work}/out" 2> "${work}/err"
    else
        run_list 81 0 "${kind}" > "${work}/out" 2> "${work}/err"
    fi
    empty_stderr "${work}/err"
    [ "$(wc -l < "${work}/out" | tr -d ' ')" -eq 7 ] || fail "incomplete ${kind} listing"
done
run_list 82 0 -j > "${work}/json" 2> "${work}/err"
empty_stderr "${work}/err"
run_list 82 0 -p > "${work}/pretty" 2> "${work}/err"
empty_stderr "${work}/err"

# Distinct metadata per process catches both missing rows and cross-run data.
pids=""
for token in 11 12 13 14 15 16 17 18; do
    run_list "${token}" 0 > "${work}/expected${token}" 2> "${work}/expected${token}.err"
    empty_stderr "${work}/expected${token}.err"
done
for token in 11 12 13 14 15 16 17 18; do
    run_list "${token}" .15 > "${work}/out${token}" 2> "${work}/err${token}" &
    pids="${pids} $!"
done
for pid in ${pids}; do wait "${pid}" || fail "concurrent invocation failed"; done
for token in 11 12 13 14 15 16 17 18; do
    empty_stderr "${work}/err${token}"
    cmp -s "${work}/expected${token}" "${work}/out${token}" || fail "concurrent output changed"
done

# Unrelated legacy files must not be removed by new invocations.
echo foreign > "${work}/sandbox/bastille-list-foreign"
run_list 83 0 > "${work}/out" 2> "${work}/err"
empty_stderr "${work}/err"
[ -f "${work}/sandbox/bastille-list-foreign" ] || fail "deleted an unrelated invocation file"
no_private_dirs
echo 'PASS: isolated list tempfiles, legacy overlap, formats, concurrent output and cleanup'
