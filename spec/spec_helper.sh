# shellcheck shell=sh
#
# shellspec support file. Loaded once before any spec runs (see .shellspec
# "--require spec_helper"). Its job is to make Bastille's shell sources
# *sourceable in isolation* on any host -- macOS, Linux, or FreeBSD -- with
# no root and no running jails.
#
# The function libraries live in usr/local/share/bastille/lib/*.sh and are
# pure definitions -- each spec Includes the specific lib(s) it exercises
# (e.g. lib/log.sh + lib/network.sh) rather than common.sh, which sources the
# libs by absolute install path. Some functions read bastille.conf settings
# (e.g. validate_netconf), so we source the fixture config here -- the job
# common.sh's top-level `. ${BASTILLE_CONFIG}` does at runtime.

# Never emit color codes into captured output.
export NO_COLOR=1

# common.sh's error_notify/info/warn do `[ "${BASTILLE_QUIET}" -ne 1 ]`, which
# errors if the variable is empty. Give it a numeric default. Set
# BASTILLE_QUIET=1 in the environment to silence messages while debugging.
export BASTILLE_QUIET="${BASTILLE_QUIET:-0}"

# Fixture config consumed by the top-level `. ${BASTILLE_CONFIG}` in every source.
export BASTILLE_CONFIG="${SHELLSPEC_PROJECT_ROOT}/spec/fixtures/bastille.conf"

# Absolute path to the shipped shell sources, for convenience in specs.
export BASTILLE_SHARE="${SHELLSPEC_PROJECT_ROOT}/usr/local/share/bastille"

# Load the fixture settings so functions that read bastille.conf globals see
# sane defaults. Individual examples override specific values as needed.
# shellcheck disable=SC1090
. "${BASTILLE_CONFIG}"
