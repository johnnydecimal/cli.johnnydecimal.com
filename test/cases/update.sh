# SPDX-License-Identifier: MIT
# update.sh - the update check, and 'jd update'
#
# Nothing here uses the network. The check's one request is
# 'git ls-remote', and the test of _jd_update_fetch replaces git with a
# function. 'jd update' pulls from a git repo under $JD_T_TMP.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_new "$JD_T_TMP/update.json"
_jd_t_config "$JD_T_TMP/update.json"
_jd_t_libs

_jd_t_cache="$HOME/.cache/johnnydecimal/update-check"

# ------------------------------------------------------------- versions

_jd_t_newer() { if _jd_update_newer "$1" "$2"; then echo yes; else echo no; fi; }
_jd_t_eq 'newer: a greater patch' yes "$(_jd_t_newer 4.4.1 4.4.0)"
_jd_t_eq 'newer: the same version is not newer' no "$(_jd_t_newer 4.4.0 4.4.0)"
_jd_t_eq 'newer: a smaller version is not newer' no "$(_jd_t_newer 4.4.0 4.4.1)"
_jd_t_eq 'newer: each part is a number, not text' yes "$(_jd_t_newer 4.10.0 4.9.9)"
_jd_t_eq 'newer: a greater major' yes "$(_jd_t_newer 5.0.0 4.99.99)"
_jd_t_eq 'newer: empty is not a version' no "$(_jd_t_newer '' 4.4.0)"
_jd_t_eq 'newer: two parts is not a version' no "$(_jd_t_newer 4.5 4.4.0)"
_jd_t_eq 'newer: a pre-release is not a version' no "$(_jd_t_newer 5.0.0-beta 4.4.0)"

_jd_t_tags=$(printf '%s\n' \
  "aaa1	refs/tags/v4.4.0" \
  "bbb2	refs/tags/v4.10.0" \
  "ccc3	refs/tags/v4.9.1" \
  "ddd4	refs/tags/v5.0.0-beta" \
  "eee5	refs/tags/release-9" \
  "fff6	refs/tags/4.2.0")
_jd_t_eq 'tags: the greatest version, compared as numbers' 4.10.0 \
  "$(printf '%s\n' "$_jd_t_tags" | _jd_update_latest_tag)"
_jd_t_eq 'tags: no version tag prints nothing' '' \
  "$(printf 'aaa1\trefs/tags/release-9\n' | _jd_update_latest_tag)"

_jd_t_eq 'version_in: reads the version from bin/jd' "$(_jd_t_version)" \
  "$(_jd_update_version_in "$JD_T_BIN")"

# ---------------------------------------------------------------- cache

_jd_t_eq 'cache: the default path' "$_jd_t_cache" "$(_jd_paths_cache)"
XDG_CACHE_HOME="$JD_T_TMP/xdg-cache"
_jd_t_eq 'cache: XDG_CACHE_HOME' "$JD_T_TMP/xdg-cache/johnnydecimal/update-check" "$(_jd_paths_cache)"
XDG_CACHE_HOME=relative/path
_jd_t_eq 'cache: a relative XDG_CACHE_HOME is ignored' "$_jd_t_cache" "$(_jd_paths_cache)"
unset XDG_CACHE_HOME

_jd_update_cache_read
_jd_t_eq 'cache: no file reads as no check' '0|' "$_JD_UPDATE_CHECKED|$_JD_UPDATE_LATEST"

_JD_UPDATE_CHECKED=100 _JD_UPDATE_LATEST=''
_jd_update_cache_write
_jd_t_eq 'cache: no latest version is written as -' "$(printf '100\t-')" "$(cat "$_jd_t_cache")"
_jd_update_cache_read
_jd_t_eq 'cache: - reads as no latest version' '100|' "$_JD_UPDATE_CHECKED|$_JD_UPDATE_LATEST"

_JD_UPDATE_CHECKED=300 _JD_UPDATE_LATEST=4.5.0
_jd_update_cache_write
_jd_update_cache_read
_jd_t_eq 'cache: round trip' '300|4.5.0' "$_JD_UPDATE_CHECKED|$_JD_UPDATE_LATEST"

printf 'garbage\n' >"$_jd_t_cache"
_jd_update_cache_read
_jd_t_eq 'cache: a damaged file reads as no check' '0|' "$_JD_UPDATE_CHECKED|$_JD_UPDATE_LATEST"
rm -f "$_jd_t_cache"

# ---------------------------------------------------------------- fetch

git() { printf '%s\n' "$_jd_t_tags"; }
_JD_UPDATE_CHECKED=500 _JD_UPDATE_LATEST=''
_jd_update_cache_write
_jd_update_fetch
_jd_update_cache_read
_jd_t_eq 'fetch: writes the latest version, and keeps the time' '500|4.10.0' \
  "$_JD_UPDATE_CHECKED|$_JD_UPDATE_LATEST"
git() { return 128; }
_jd_update_fetch
_jd_update_cache_read
_jd_t_eq 'fetch: a failed request changes nothing' '500|4.10.0' \
  "$_JD_UPDATE_CHECKED|$_JD_UPDATE_LATEST"
unset -f git
rm -f "$_jd_t_cache"

# ---------------------------------------------------------------- after

# A terminal, a fixed clock, and a check that records that it started.
_JD_CLI_VERSION=4.4.0
_jd_t_now=1000000
_jd_update_now() { printf '%s' "$_jd_t_now"; }
_jd_update_tty() { return 0; }
_jd_t_started="$JD_T_TMP/started"
_jd_update_check_start() { printf 'x' >>"$_jd_t_started"; }
_jd_t_starts() { if [ -f "$_jd_t_started" ]; then wc -c <"$_jd_t_started" | tr -d ' '; else echo 0; fi; }

_jd_t_run _jd_update_after 11.11
_jd_t_eq 'after: no cache prints nothing' '' "$JD_T_ERR"
_jd_t_eq 'after: no cache starts a check' 1 "$(_jd_t_starts)"
_jd_update_cache_read
_jd_t_eq 'after: the time of the check is written first' 1000000 "$_JD_UPDATE_CHECKED"

_jd_t_now=1000100
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'after: no second check within 24 hours' 1 "$(_jd_t_starts)"

_jd_t_now=1086400
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'after: a check 24 hours later' 2 "$(_jd_t_starts)"

_jd_t_now=900000
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'after: a check when the clock moved back' 3 "$(_jd_t_starts)"

# The cache names a newer version, and the last check was just now.
_jd_t_now=2000000
_JD_UPDATE_CHECKED=2000000 _JD_UPDATE_LATEST=4.5.0
_jd_update_cache_write
_jd_t_notice="jd: version 4.5.0 is available, this is 4.4.0 - run 'jd update'"
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'notice: one line on stderr' "$_jd_t_notice" "$JD_T_ERR"
_jd_t_eq 'notice: nothing on stdout' '' "$JD_T_OUT"
_jd_t_status 'notice: exit status' 0

_jd_t_now=2000100
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'notice: again after the next command' "$_jd_t_notice" "$JD_T_ERR"
_jd_t_run _jd_update_after version
_jd_t_eq 'notice: jd version prints it' "$_jd_t_notice" "$JD_T_ERR"
_jd_t_run _jd_update_after --version
_jd_t_eq 'notice: jd --version prints it' "$_jd_t_notice" "$JD_T_ERR"

_jd_t_now=3000000
_jd_t_run _jd_update_after paths
_jd_t_eq 'notice: jd paths prints nothing' '' "$JD_T_ERR"
_jd_t_run _jd_update_after jdex paths config
_jd_t_eq 'notice: jdex paths prints nothing' '' "$JD_T_ERR"
_jd_t_run _jd_update_after update
_jd_t_eq 'notice: jd update prints nothing' '' "$JD_T_ERR"

_JD_UPDATE_LATEST=4.4.0
_jd_update_cache_write
_jd_t_run _jd_update_after version
_jd_t_eq 'notice: the same version prints nothing' '' "$JD_T_ERR"

# Turned off. The cache names a newer version, the check is due, and
# none of these prints or checks.
_jd_t_off() {
  _JD_UPDATE_CHECKED=0 _JD_UPDATE_LATEST=4.5.0
  _jd_update_cache_write
  rm -f "$_jd_t_started"
  _jd_t_run _jd_update_after version
  _jd_t_eq "off: $1 prints nothing" '' "$JD_T_ERR"
  _jd_t_eq "off: $1 starts no check" 0 "$(_jd_t_starts)"
}
JD_NO_UPDATE_CHECK=1
_jd_t_off 'JD_NO_UPDATE_CHECK=1'
unset JD_NO_UPDATE_CHECK
DO_NOT_TRACK=1
_jd_t_off 'DO_NOT_TRACK=1'
unset DO_NOT_TRACK
jq '. + {updateCheck: false}' "$JD_T_TMP/update.json" >"$JD_T_TMP/update-off.json"
_jd_t_config "$JD_T_TMP/update-off.json"
_jd_t_off '"updateCheck": false'
_jd_t_config "$JD_T_TMP/update.json"

JD_NO_UPDATE_CHECK=0
_JD_UPDATE_CHECKED=0 _JD_UPDATE_LATEST=4.5.0
_jd_update_cache_write
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'off: JD_NO_UPDATE_CHECK=0 leaves the check on' "$_jd_t_notice" "$JD_T_ERR"
unset JD_NO_UPDATE_CHECK

# Not a terminal: the real _jd_update_tty, and _jd_t_run sends stderr to
# a file.
. "$JD_T_REPO/lib/update.sh"
_jd_update_now() { printf '%s' "$_jd_t_now"; }
_jd_update_check_start() { printf 'x' >>"$_jd_t_started"; }
_JD_CLI_VERSION=4.4.0
_JD_UPDATE_CHECKED=0 _JD_UPDATE_LATEST=4.5.0
_jd_update_cache_write
rm -f "$_jd_t_started"
_jd_t_run _jd_update_after 11.11
_jd_t_eq 'no terminal: prints nothing' '' "$JD_T_ERR"
_jd_t_eq 'no terminal: starts no check' 0 "$(_jd_t_starts)"
_jd_t_run _jd_update_after version
_jd_t_eq 'no terminal: jd version still prints it' "$_jd_t_notice" "$JD_T_ERR"
_jd_t_eq 'no terminal: jd version starts no check' 0 "$(_jd_t_starts)"

# ------------------------------------------------------------ the program

_JD_UPDATE_CHECKED=$(date +%s) _JD_UPDATE_LATEST=999.0.0
_jd_update_cache_write
_jd_t_run "$JD_T_BIN" version
_jd_t_eq 'bin: version prints the version on stdout' "jd $(_jd_t_version)" "$JD_T_OUT"
_jd_t_contains 'bin: version prints the notice on stderr' \
  "jd: version 999.0.0 is available, this is $(_jd_t_version) - run 'jd update'" "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" paths config
_jd_t_eq 'bin: paths prints no notice' '' "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'bin: a move from a script prints no notice' '' "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" update --help
_jd_t_status 'bin: update --help exit status' 0
_jd_t_contains 'bin: update --help says no telemetry is sent' 'No telemetry is sent.' "$JD_T_OUT"
_jd_t_run "$JD_T_BIN" update now
_jd_t_status 'bin: update with a word after it exit status' 1
_jd_t_eq 'bin: update with a word after it' "jd: 'jd update' takes nothing after it" "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" --help
_jd_t_contains 'bin: help lists update' '<system> update' "$JD_T_OUT"
rm -f "$_jd_t_cache"

# ------------------------------------------------------------ jd update

# An upstream repo and a clone of it, each with a fake bin/jd that
# defines a version. git reads no config of the user's: $HOME is under
# $JD_T_TMP.
GIT_CONFIG_NOSYSTEM=1
GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

_jd_t_up="$JD_T_TMP/up stream"
_jd_t_inst="$JD_T_TMP/the install"

# Write a release into the upstream repo. $1 the version, $2 the
# changelog entry to add at the top.
_jd_t_release() {
  printf '#!/usr/bin/env bash\n_JD_CLI_VERSION="%s"\n' "$1" >"$_jd_t_up/bin/jd"
  {
    printf '# Changelog\n\n## %s – 2026-01-01\n\n%s\n\n' "$1" "$2"
    sed '1,2d' "$_jd_t_up/CHANGELOG.md" 2>/dev/null
  } >"$_jd_t_up/CHANGELOG.new"
  mv "$_jd_t_up/CHANGELOG.new" "$_jd_t_up/CHANGELOG.md"
  git -C "$_jd_t_up" add -A >/dev/null 2>&1
  git -C "$_jd_t_up" -c commit.gpgsign=false commit -q -m "$1" >/dev/null 2>&1
}

mkdir -p "$_jd_t_up/bin"
git init -q -b main "$_jd_t_up" >/dev/null 2>&1
printf '# hook\n' >"$_jd_t_up/jd.sh"
printf '# Changelog\n\n' >"$_jd_t_up/CHANGELOG.md"
_jd_t_release 1.0.0 'The first release.'
git clone -q "$_jd_t_up" "$_jd_t_inst" >/dev/null 2>&1
_jd_t_release 1.1.0 'The second release.'
_jd_t_release 1.2.0 'The third release.'

_jd_t_run _jd_update_run "$_jd_t_inst"
_jd_t_status 'update: exit status' 0
_jd_t_contains 'update: names both versions' 'jd updated from 1.0.0 to 1.2.0' "$JD_T_OUT"
_jd_t_contains 'update: prints the newest entry' 'The third release.' "$JD_T_OUT"
_jd_t_contains 'update: prints every entry since the old version' 'The second release.' "$JD_T_OUT"
_jd_t_lacks 'update: does not print the old version' 'The first release.' "$JD_T_OUT"
_jd_t_lacks 'update: no new shell when the hook did not change' 'new shell' "$JD_T_OUT"
_jd_t_eq 'update: the clone is at the new version' 1.2.0 "$(_jd_update_version_in "$_jd_t_inst/bin/jd")"
_jd_update_cache_read
_jd_t_eq 'update: writes the new version to the cache' 1.2.0 "$_JD_UPDATE_LATEST"

_jd_t_run _jd_update_run "$_jd_t_inst"
_jd_t_status 'update: up to date exit status' 0
_jd_t_eq 'update: up to date' 'jd 1.2.0 is the latest version' "$JD_T_OUT"

printf '# hook, changed\n' >"$_jd_t_up/jd.sh"
_jd_t_release 1.2.1 'The hook changed.'
printf 'scratch\n' >"$_jd_t_inst/untracked.txt"
_jd_t_run _jd_update_run "$_jd_t_inst"
_jd_t_status 'update: an untracked file does not stop it' 0
_jd_t_contains 'update: a changed hook needs a new shell' \
  'Start a new shell to load the new shell hook.' "$JD_T_OUT"
rm -f "$_jd_t_inst/untracked.txt"

printf '# local\n' >>"$_jd_t_inst/jd.sh"
_jd_t_run _jd_update_run "$_jd_t_inst"
_jd_t_status 'update: uncommitted changes exit status' 1
_jd_t_eq 'update: refuses uncommitted changes' \
  "jd: $_jd_t_inst contains uncommitted changes - commit or discard them, then run 'jd update' again" "$JD_T_ERR"
git -C "$_jd_t_inst" checkout -q -- jd.sh

git -C "$_jd_t_inst" switch -q -c other >/dev/null 2>&1
_jd_t_run _jd_update_run "$_jd_t_inst"
_jd_t_status 'update: another branch exit status' 1
_jd_t_eq 'update: refuses another branch' \
  "jd: $_jd_t_inst is on the branch 'other' - 'jd update' updates the branch main" "$JD_T_ERR"
git -C "$_jd_t_inst" switch -q main >/dev/null 2>&1

git -C "$_jd_t_inst" checkout -q --detach >/dev/null 2>&1
_jd_t_run _jd_update_run "$_jd_t_inst"
_jd_t_status 'update: no branch exit status' 1
_jd_t_eq 'update: refuses no branch' \
  "jd: $_jd_t_inst is not on a branch - 'jd update' updates the branch main" "$JD_T_ERR"
git -C "$_jd_t_inst" switch -q main >/dev/null 2>&1

mkdir -p "$JD_T_TMP/not a clone"
_jd_t_run _jd_update_run "$JD_T_TMP/not a clone"
_jd_t_status 'update: not a clone exit status' 1
_jd_t_contains 'update: refuses a folder that is not a clone' 'is not a git clone' "$JD_T_ERR"

_jd_t_summary
