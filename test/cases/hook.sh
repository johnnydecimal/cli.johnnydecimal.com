# SPDX-License-Identifier: MIT
# hook.sh - what jd.sh defines, in cases the other files do not cover
#
# A sys id that is already a command, a second source of jd.sh in the
# same shell, and a copy of jd in a folder whose path contains a quote.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"

_jd_t_id="$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"

# ------------------------------------------ a sys id that is a command
#
# A function named cd would replace cd. jd.sh defines no function for
# that system, and prints why.

jq '.systems[1].sys = "CD"' "$JD_T_TMP/two.json" >"$JD_T_TMP/cd.json"
_jd_t_load "$JD_T_TMP/cd.json"
_jd_t_contains 'sys id cd: prints that it is already a command' \
  "cannot define a function for sys id 'CD': 'cd' is already a command" "$JD_T_LOADERR"
_jd_t_run_from "$JD_T_TMP" cd /
_jd_t_at 'sys id cd: cd still changes directory' /
_jd_t_run d25 11.11
_jd_t_at 'sys id cd: the other systems still work' "$_jd_t_id"

# ------------------------------------------------- source jd.sh twice
#
# A second source in the same shell, as 'source ~/.zshrc' does, finds
# d25 and p76 already defined. They are jd's own, so jd.sh defines them
# again, and prints nothing.

_jd_t_load "$JD_T_TMP/two.json"
. "$JD_T_REPO/jd.sh" 2>"$JD_T_TMP/.loaderr"
_jd_t_eq 'source twice: prints nothing' '' "$(cat "$JD_T_TMP/.loaderr")"
_jd_t_run p76 31.11
_jd_t_at 'source twice: p76 still works' \
  "$JD_FX_ROOT2/30-39 Area three/31 Category thirtyone/31.11 Pear"

# ---------------------------------------- a quote in the install path

_jd_t_q="$JD_T_TMP/it's here"
mkdir -p "$_jd_t_q"
cp -R "$JD_T_REPO/jd.sh" "$JD_T_REPO/bin" "$JD_T_REPO/lib" \
  "$JD_T_REPO/templates" "$_jd_t_q/"
_jd_t_path=$PATH
_jd_t_unload
. "$_jd_t_q/jd.sh" 2>"$JD_T_TMP/.loaderr"
_jd_t_eq 'quote in the path: sourcing prints nothing' '' "$(cat "$JD_T_TMP/.loaderr")"
_jd_t_run jd 11.11
_jd_t_status 'quote in the path: jd exit status' 0
_jd_t_at 'quote in the path: jd changes directory' "$_jd_t_id"
_jd_t_run d25 11.11
_jd_t_at 'quote in the path: d25 changes directory' "$_jd_t_id"
PATH=$_jd_t_path
rm -rf "$_jd_t_q"

_jd_t_summary
