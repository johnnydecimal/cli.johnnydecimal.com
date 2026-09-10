# SPDX-License-Identifier: MIT
# version-usage.sh - jd version, and jd help
#
# The version is not written out here. It is read from jd.sh, so a
# release does not need the tests edited. What is tested is that the
# three spellings agree, that the version reaches the user, and that the
# changelog was updated with it.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_version=$(sed -n 's/^_JD_CLI_VERSION="\([^"]*\)".*/\1/p' "$JD_T_REPO/jd.sh")

if [ -n "$_jd_t_version" ]; then
  _jd_t_ok 'version: jd.sh sets _JD_CLI_VERSION'
else
  _jd_t_bad 'version: jd.sh sets _JD_CLI_VERSION' 'a version' 'nothing'
fi

_jd_t_eq 'version: sourcing jd.sh exports it to the shell' \
  "$_jd_t_version" "$_JD_CLI_VERSION"

_jd_t_run jd version
_jd_t_status 'version: exit status' 0
_jd_t_eq 'version: jd version' "jd $_jd_t_version" "$JD_T_OUT"
_jd_t_at 'version: does not move us' "$JD_T_TMP"

_jd_t_run jd -v
_jd_t_eq 'version: jd -v' "jd $_jd_t_version" "$JD_T_OUT"

_jd_t_run jd --version
_jd_t_eq 'version: jd --version' "jd $_jd_t_version" "$JD_T_OUT"

_jd_t_run d25 version
_jd_t_eq 'version: a per-system command prints it too' \
  "jd $_jd_t_version" "$JD_T_OUT"

# The changelog is the record of releases, so it must know this version.
_jd_t_changelog=$(sed -n 's/^## \([0-9][0-9.]*\).*/\1/p' "$JD_T_REPO/CHANGELOG.md" | head -1)
_jd_t_eq 'version: the changelog names the current version first' \
  "$_jd_t_version" "$_jd_t_changelog"

# ------------------------------------------------------------------ help

_jd_t_run jd help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' \
  'usage: <system> [jdex] [target]' "$JD_T_OUT"
_jd_t_contains 'help: lists the jdex target' \
  '<system> jdex ...' "$JD_T_OUT"
_jd_t_contains 'help: explains what many matches do' \
  'Two or more matches are listed, not entered.' "$JD_T_OUT"
_jd_t_at 'help: does not move us' "$JD_T_TMP"

_jd_t_run jd -h
_jd_t_contains 'help: jd -h' 'usage: <system> [jdex] [target]' "$JD_T_OUT"

_jd_t_run jd --help
_jd_t_contains 'help: jd --help' 'usage: <system> [jdex] [target]' "$JD_T_OUT"

_jd_t_run jd jdex help
_jd_t_contains 'help: works in jdex mode too' \
  'usage: <system> [jdex] [target]' "$JD_T_OUT"

_jd_t_contains 'help: lists the jdex command' 'jdex [target]' "$JD_T_OUT"

# ----------------------------------------------- the jdex command

_jd_t_run jdex version
_jd_t_status 'jdex command: version exit status' 0
_jd_t_eq 'jdex command: jdex version' "jd $_jd_t_version" "$JD_T_OUT"
_jd_t_at 'jdex command: version does not move us' "$JD_T_TMP"

_jd_t_run jdex -v
_jd_t_eq 'jdex command: jdex -v' "jd $_jd_t_version" "$JD_T_OUT"

_jd_t_run jd jdex version
_jd_t_eq 'jdex command: jd jdex version' "jd $_jd_t_version" "$JD_T_OUT"

_jd_t_run jdex help
_jd_t_contains 'jdex command: jdex help' \
  'usage: <system> [jdex] [target]' "$JD_T_OUT"

_jd_t_run jdex --help
_jd_t_contains 'jdex command: jdex --help' \
  'usage: <system> [jdex] [target]' "$JD_T_OUT"

_jd_t_summary
