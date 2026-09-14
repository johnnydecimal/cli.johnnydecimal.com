# SPDX-License-Identifier: MIT
# fish.sh - the fish hook, jd.fish
#
# jd.fish is a thin port of jd.sh for fish: it runs the program, cds on
# exit status 3, defines jd, jdex and one command per system, and puts
# bin on $PATH. See jd.fish for the reasoning.
#
# A case file is bash or zsh, and jd.fish is neither, so this file does
# not source it. It runs fish itself, as a subprocess, through
# _jd_t_run - the way cases/bin.sh runs bin/jd as a subprocess. A
# subprocess's cd cannot reach back into this shell either way, so
# every assertion here reads $JD_T_OUT, what jd.fish prints after it
# cds, and never $JD_T_PWD.
#
# fish is a subprocess dependency here, like jq, not one of the shells
# test/run.sh drives this file with. So it runs once, under bash, and
# skips under zsh: the same fish subprocess a second time would not add
# coverage.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

if [ -n "${ZSH_VERSION-}" ]; then
  _jd_t_skipped 'fish hook: jd.fish' 'runs once, under bash'
  _jd_t_summary
fi

if ! command -v fish >/dev/null 2>&1; then
  _jd_t_skipped 'fish hook: jd.fish' 'fish is not installed'
  _jd_t_summary
fi

# Run a fish script with jd.fish already sourced. $1 the script.
_jd_t_fish() {
  _jd_t_run fish -c "source '$JD_T_REPO/jd.fish'; $1"
}

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_config "$JD_T_TMP/two.json"

_jd_t_id="$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"

# ------------------------------------------------------------------ moves

_jd_t_fish 'jd 11.11'
_jd_t_status 'jd: exit status' 0
_jd_t_eq 'jd: cds and prints the new path' "$_jd_t_id" "$JD_T_OUT"

# The printed line is jd's own report. Prove the cd itself reached the
# calling script, not just a function-local scope, with a second, plain
# pwd in the same fish process.
_jd_t_fish 'jd 11.11 >/dev/null; and pwd'
_jd_t_eq 'jd: the cd really happened, not just the printed line' \
  "$_jd_t_id" "$JD_T_OUT"

_jd_t_fish 'jdex 11.11'
_jd_t_status 'jdex: exit status' 0
_jd_t_eq 'jdex: cds into the folder the note is in' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven" "$JD_T_OUT"

_jd_t_fish 'd25 11.11'
_jd_t_status 'd25: exit status' 0
_jd_t_eq 'd25: acts on its own system' "$_jd_t_id" "$JD_T_OUT"

_jd_t_fish 'p76 31.11'
_jd_t_status 'p76: exit status' 0
_jd_t_eq 'p76: acts on the other system' \
  "$JD_FX_ROOT2/30-39 Area three/31 Category thirtyone/31.11 Pear" "$JD_T_OUT"

# ------------------------------------------------------------------ errors

_jd_t_fish 'jd nonexistent-zzz-word'
_jd_t_status 'no match: exit status' 1
_jd_t_eq 'no match: nothing on stdout, so no cd' '' "$JD_T_OUT"
_jd_t_contains 'no match: the error is on stderr' \
  "no match for 'nonexistent-zzz-word'" "$JD_T_ERR"

_jd_t_fish 'jd tripsy'
_jd_t_status 'many matches: exit status' 1
_jd_t_eq 'many matches: nothing on stdout' '' "$JD_T_OUT"
_jd_t_contains 'many matches: the list is on stderr' \
  "jd: 2 matches for 'tripsy':" "$JD_T_ERR"

# -------------------------------------------------------------------- PATH

_jd_t_fish 'echo $PATH'
_jd_t_contains 'jd.fish puts bin on $PATH' "$JD_T_REPO/bin" "$JD_T_OUT"

# ----------------------------------------------------- what jd.fish makes
#
# The same shape cases/bin.sh checks for jd.sh: each function must name
# the program and hold no helper, because an agent's shell keeps jd and
# drops every _jd_ name around it. fish is no different: 'functions'
# prints a function's source the way 'declare -f'/'typeset -f' does.

for _jd_t_fn in jd jdex d25 p76; do
  _jd_t_fish "functions $_jd_t_fn"
  _jd_t_contains "$_jd_t_fn: names the program" 'bin/jd' "$JD_T_OUT"
  _jd_t_lacks "$_jd_t_fn: calls no helper" '_jd_' "$JD_T_OUT"
done

_jd_t_fish 'functions jdex'
_jd_t_contains 'jdex: passes the word jdex' "jdex \$argv" "$JD_T_OUT"

_jd_t_fish 'functions d25'
_jd_t_contains 'd25: passes its own system' '--system D25' "$JD_T_OUT"

_jd_t_fish 'functions jd'
_jd_t_lacks 'jd: names no system, so the program picks the default' \
  '--system' "$JD_T_OUT"

# No _jd_hook_def or other setup helper survives sourcing: it is a
# fixed, small set of names, the same as jd.sh leaves behind.
_jd_t_fish 'functions -a'
_jd_t_lacks 'sourcing cleans up its own helpers' '_jd_hook' "$JD_T_OUT"

_jd_t_summary
