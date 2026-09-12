# SPDX-License-Identifier: MIT
# harness.sh - the test harness for the Johnny.Decimal command line
#
# Every file in test/cases sources this first. It gives a case file:
#   - counters, and one result line per test, in a TAP-like format
#   - assertions: _jd_t_eq, _jd_t_contains, _jd_t_lacks, _jd_t_status,
#     _jd_t_at
#   - _jd_t_run, which runs a jd command in this shell, records where it
#     left us, then puts us back
#   - _jd_t_load, which points $JD_CONFIG at a fixture config and sources
#     jd.sh again
#   - _jd_t_bin, the path of the program, and _jd_t_libs, which sources
#     lib into this shell for the few tests that drive a lib function
#     directly
#
# Why a harness of our own: the tools must work in bash 3.2 and zsh with
# jq as the only dependency, so the tests must too. Nothing here needs a
# language runtime, a package manager, or a test framework. Everything is
# plain shell that both shells parse the same way. There are no arrays,
# because bash 3.2 has no associative arrays and array syntax differs.
#
# The runner (test/run.sh) sets $JD_T_REPO, $JD_T_TMP, $JD_T_SHELL,
# $JD_T_FILE and $JD_T_COUNTS before it starts a case file. Do not run a
# case file by hand; run test/run.sh.
#
# jd cd's. So does every per-system function. _jd_t_run therefore records
# $PWD after the command as $JD_T_PWD, then returns to where it started.
# A case file never has to think about it.
#
# The program, bin/jd, does not cd: it prints the folder and stops. A
# case that runs $JD_T_BIN reads $JD_T_OUT, not $JD_T_PWD.

if [ -z "${JD_T_TMP-}" ] || [ -z "${JD_T_REPO-}" ]; then
  printf 'test: no $JD_T_TMP or $JD_T_REPO - run the suite with test/run.sh\n' >&2
  exit 2
fi

_jd_t_n=0
_jd_t_pass=0
_jd_t_fail=0
_jd_t_skip=0

# ---------------------------------------------------------------- output

# Print a labelled value, one '#' line per line of the value.
# $1 label, $2 value
_jd_t_show() {
  printf '%s\n' "$2" | awk -v l="$1" '
    NR == 1 { printf "#   %-10s%s\n", l, $0; next }
    { printf "#             %s\n", $0 }
  '
}

_jd_t_ok() {
  _jd_t_n=$((_jd_t_n + 1))
  _jd_t_pass=$((_jd_t_pass + 1))
  printf 'ok %s - %s\n' "$_jd_t_n" "$1"
}

# $1 name, $2 expected, $3 got
_jd_t_bad() {
  _jd_t_n=$((_jd_t_n + 1))
  _jd_t_fail=$((_jd_t_fail + 1))
  printf 'not ok %s - %s\n' "$_jd_t_n" "$1"
  printf '#   %-10s%s [%s]\n' 'in' "$JD_T_FILE" "$JD_T_SHELL"
  _jd_t_show 'expected:' "$2"
  _jd_t_show 'got:' "$3"
}

# $1 name, $2 reason
_jd_t_skipped() {
  _jd_t_n=$((_jd_t_n + 1))
  _jd_t_skip=$((_jd_t_skip + 1))
  printf 'ok %s - %s # SKIP %s\n' "$_jd_t_n" "$1" "$2"
}

# A test for a bug that is known and not yet fixed. It says what the
# right answer is, and it does not turn the suite red, because the suite
# is red only for work that has gone backwards.
#
# When the bug is fixed the line changes to say so. Move the test into
# the case file it belongs in and use _jd_t_eq.
#
# $1 name, $2 expected, $3 actual, $4 note
_jd_t_eq_known() {
  _jd_t_n=$((_jd_t_n + 1))
  _jd_t_skip=$((_jd_t_skip + 1))
  if [ "$2" = "$3" ]; then
    printf 'ok %s - %s # TODO this now passes, so promote it: %s\n' \
      "$_jd_t_n" "$1" "$4"
    return 0
  fi
  printf 'ok %s - %s # TODO known bug: %s\n' "$_jd_t_n" "$1" "$4"
  _jd_t_show 'expected:' "$2"
  _jd_t_show 'got:' "$3"
}

# Write the counts where the runner can find them, then exit.
_jd_t_summary() {
  printf '# %s [%s]: %s passed, %s failed, %s skipped\n' \
    "$JD_T_FILE" "$JD_T_SHELL" "$_jd_t_pass" "$_jd_t_fail" "$_jd_t_skip"
  printf '%s %s %s\n' "$_jd_t_pass" "$_jd_t_fail" "$_jd_t_skip" >"$JD_T_COUNTS"
  [ "$_jd_t_fail" -eq 0 ] || exit 1
  exit 0
}

# ------------------------------------------------------------ assertions

# $1 name, $2 expected, $3 actual
_jd_t_eq() {
  if [ "$2" = "$3" ]; then
    _jd_t_ok "$1"
  else
    _jd_t_bad "$1" "$2" "$3"
  fi
}

# $1 name, $2 needle, $3 haystack
_jd_t_contains() {
  case $3 in
    *"$2"*) _jd_t_ok "$1" ;;
    *) _jd_t_bad "$1" "text containing: $2" "$3" ;;
  esac
}

# $1 name, $2 needle, $3 haystack
_jd_t_lacks() {
  case $3 in
    *"$2"*) _jd_t_bad "$1" "text without: $2" "$3" ;;
    *) _jd_t_ok "$1" ;;
  esac
}

# The exit status of the last _jd_t_run. $1 name, $2 expected status.
_jd_t_status() {
  _jd_t_eq "$1" "status $2" "status $JD_T_STATUS"
}

# Where the last _jd_t_run left us. $1 name, $2 expected directory.
_jd_t_at() {
  _jd_t_eq "$1" "$2" "$JD_T_PWD"
}

# ------------------------------------------------------------ running jd

# Run a command from a directory and record everything about it.
# $1 directory to start in, $2+ the command and its words.
# Sets $JD_T_STATUS, $JD_T_OUT, $JD_T_ERR, $JD_T_PWD, then goes back.
_jd_t_run_from() {
  local _jd_t_dir=$1 _jd_t_back=$PWD
  shift
  cd -- "$_jd_t_dir" || return 1
  "$@" >"$JD_T_TMP/.out" 2>"$JD_T_TMP/.err"
  JD_T_STATUS=$?
  JD_T_PWD=$PWD
  cd -- "$_jd_t_back" || return 1
  JD_T_OUT=$(cat "$JD_T_TMP/.out")
  JD_T_ERR=$(cat "$JD_T_TMP/.err")
}

# The same, starting from the temp directory, which is outside every
# fixture system. $1+ the command and its words.
_jd_t_run() {
  _jd_t_run_from "$JD_T_TMP" "$@"
}

# ------------------------------------------------------- loading the CLI

# The program. A case runs it with _jd_t_run to see the contract an
# agent, a script or cron gets: no cd, the folder on stdout.
JD_T_BIN=$JD_T_REPO/bin/jd

# The version, which lives in bin/jd and nowhere else.
_jd_t_version() {
  sed -n 's/^_JD_CLI_VERSION="\([^"]*\)".*/\1/p' "$JD_T_BIN"
}

# Source lib into this shell, for the few tests that drive a lib
# function directly rather than through a command. bin/jd sets the same
# three variables before it sources the same three files.
#
# It defines no command: jd and the rest still come from _jd_t_load, and
# still run the program.
_jd_t_libs() {
  _JD_CLI_DIR=$JD_T_REPO
  _JD_CLI_VERSION=$(_jd_t_version)
  _JD_CLI_HELP_URL=$(sed -n 's/^_JD_CLI_HELP_URL="\([^"]*\)".*/\1/p' "$JD_T_BIN")
  . "$JD_T_REPO/lib/nav.sh"
  . "$JD_T_REPO/lib/setup.sh"
  . "$JD_T_REPO/lib/beta.sh"
  . "$JD_T_REPO/lib/new.sh"
}

# Forget the commands a previous _jd_t_load defined. jd.sh redefines jd
# every time, but a per-system function from an old config would survive
# into a config that no longer has that system.
_jd_t_unload() {
  local _jd_t_f
  for _jd_t_f in jd d25 p76 x99; do
    unset -f "$_jd_t_f" 2>/dev/null || true
  done
}

# Point $JD_CONFIG at a fixture config, and load nothing. This is what a
# case that only runs the program needs. $1 path to the config. It need
# not exist; that is a test too.
_jd_t_config() {
  JD_CONFIG=$1
  export JD_CONFIG
  # Never let a test read the real config, or the real system.
  case $JD_CONFIG in
    "$JD_T_TMP"/*) ;;
    *)
      printf 'test: refusing to run - $JD_CONFIG is outside $JD_T_TMP\n' >&2
      exit 2
      ;;
  esac
}

# The same, and source jd.sh again, so this shell has jd and the rest.
# Sets $JD_T_LOADERR, the stderr jd.sh wrote while it loaded.
_jd_t_load() {
  _jd_t_config "$1"
  _jd_t_unload
  . "$JD_T_REPO/jd.sh" 2>"$JD_T_TMP/.loaderr"
  JD_T_LOADERR=$(cat "$JD_T_TMP/.loaderr")
}
