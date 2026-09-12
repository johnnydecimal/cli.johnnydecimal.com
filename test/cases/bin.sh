# SPDX-License-Identifier: MIT
# bin.sh - bin/jd, the program, and the shape of the functions jd.sh makes
#
# Every other case file drives jd through the shell hook. This one is
# the other half: the contract a script, cron or an agent gets when it
# runs the program and has sourced nothing at all.
#
# The contract is:
#   - a move prints one absolute path on stdout, and nothing else
#   - a move does not change the caller's directory. It cannot
#   - lists, reports and errors go to stderr
#   - the exit status is 0 for a move, 1 for an error, and 3 for a move
#     when JD_HOOK is set, which is how the hook knows to cd
#
# So the program half reads $JD_T_OUT, never $JD_T_PWD.
#
# The last section sources jd.sh and looks at the functions it made,
# because their shape is what started all this: Claude Code copies the
# user's shell functions, keeps jd, and drops every name that starts
# with an underscore. A jd that called a helper arrived broken.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# Both would reach the program through the environment and change what
# it does, so neither is left to the shell that started the suite.
unset JD_HOOK
unset JD_BETA

_jd_t_version=$(_jd_t_version)

# ---------------------------------------------------------- executable

if [ -x "$JD_T_BIN" ]; then
  _jd_t_ok 'the program is executable'
else
  _jd_t_bad 'the program is executable' 'bin/jd is +x' 'it is not'
fi

# ----------------------------------------------------------- no config
#
# Before a fixture config exists, so 'no config' is the truth.

_jd_t_config "$JD_T_TMP/nothing-here.json"

_jd_t_run "$JD_T_BIN" version
_jd_t_status 'no config: version exit status' 0
_jd_t_eq 'no config: version prints it' "jd $_jd_t_version" "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" --help
_jd_t_status 'no config: help exit status' 0
_jd_t_contains 'no config: help names --system' '--system' "$JD_T_OUT"
_jd_t_contains 'no config: help names the program' 'bin/jd' "$JD_T_OUT"

_jd_t_run "$JD_T_BIN"
_jd_t_status 'no config: a move is an error' 1
_jd_t_contains 'no config: says which file it looked for' \
  "no config at $JD_T_TMP/nothing-here.json" "$JD_T_ERR"
_jd_t_eq 'no config: nothing on stdout' '' "$JD_T_OUT"

# --------------------------------------------------------------- moves

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_config "$JD_T_TMP/two.json"

_jd_t_id="$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"

_jd_t_run "$JD_T_BIN" 11.11
_jd_t_status 'id: exit status' 0
_jd_t_eq 'id: prints the folder' "$_jd_t_id" "$JD_T_OUT"
_jd_t_at 'id: the program does not move its caller' "$JD_T_TMP"
_jd_t_eq 'id: one line, and nothing else' '1' \
  "$(printf '%s\n' "$JD_T_OUT" | grep -c '^')"
_jd_t_eq 'id: nothing on stderr' '' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN"
_jd_t_status 'root: exit status' 0
_jd_t_eq 'root: prints the system root' "$JD_FX_ROOT" "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" jdex 11.11
_jd_t_status 'jdex: exit status' 0
_jd_t_eq 'jdex: prints the folder the note is in' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven" "$JD_T_OUT"

# ------------------------------------------------------------- JD_HOOK

_jd_t_run env JD_HOOK=1 "$JD_T_BIN" 11.11
_jd_t_status 'hook: a move exits 3' 3
_jd_t_eq 'hook: and prints the same folder' "$_jd_t_id" "$JD_T_OUT"

_jd_t_run env JD_HOOK=1 "$JD_T_BIN" version
_jd_t_status 'hook: what is not a move still exits 0' 0

# ------------------------------------------------------------ --system

_jd_t_run "$JD_T_BIN" --system P76
_jd_t_status 'system: exit status' 0
_jd_t_eq 'system: acts on the system named, not the default' \
  "$JD_FX_ROOT2" "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" --system P76 31.11
_jd_t_eq 'system: and navigates in it' \
  "$JD_FX_ROOT2/30-39 Area three/31 Category thirtyone/31.11 Pear" "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" --system
_jd_t_status 'system: with no id, an error' 1
_jd_t_contains 'system: says it needs one' 'needs a system id' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN" --system X99 11.11
_jd_t_status 'system: one that is not in the config, an error' 1
_jd_t_contains 'system: names it' "system 'X99' is not in" "$JD_T_ERR"

# --system is read as the first word and nowhere else, so a search for
# the word '--system' is a search, not an option.
_jd_t_run "$JD_T_BIN" 11.11 --system
_jd_t_status 'system: not read after the first word' 1
_jd_t_contains 'system: it is just a word there' \
  "unexpected words after '11.11'" "$JD_T_ERR"

# ------------------------------------------------------- many matches

_jd_t_run "$JD_T_BIN" tripsy
_jd_t_status 'many matches: exit status' 1
_jd_t_eq 'many matches: nothing on stdout' '' "$JD_T_OUT"
_jd_t_contains 'many matches: the list is on stderr' \
  "jd: 2 matches for 'tripsy':" "$JD_T_ERR"
_jd_t_contains 'many matches: lists the first' '11.13 Tripsy travel' "$JD_T_ERR"
_jd_t_contains 'many matches: lists the second' '21.11 Tripsy notes' "$JD_T_ERR"

# ---------------------------------------------------------- jd new id
#
# The machine interface, which is the whole reason an agent runs the
# program: one JSON object on stdout, and it does not move.

_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_config "$JD_T_TMP/new.json"

_jd_t_f21="$JD_FX_ROOT/20-29 Area two/21 Category twentyone"
_jd_t_j21="$JD_FX_JDEX/20-29 Area two/21 Category twentyone"

_jd_t_run env JD_BETA=1 "$JD_T_BIN" new id 21 A title --dry-run --json
_jd_t_status 'new --json: exit status' 0
_jd_t_eq 'new --json: one object' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
_jd_t_eq 'new --json: stdout is that one object and nothing else' '1' \
  "$(printf '%s' "$JD_T_OUT" | jq -s 'length')"

_jd_t_run env JD_BETA=1 "$JD_T_BIN" new id 21 A title
_jd_t_status 'new: exit status' 0
_jd_t_eq 'new: prints the folder it made' "$_jd_t_f21/21.36 A title" "$JD_T_OUT"
_jd_t_at 'new: and does not move its caller' "$JD_T_TMP"
if [ -d "$_jd_t_f21/21.36 A title" ] && [ -f "$_jd_t_j21/21.36 A title.md" ]; then
  _jd_t_ok 'new: the folder and the note are both there'
else
  _jd_t_bad 'new: the folder and the note are both there' \
    'a folder and a note' 'at least one is missing'
fi

_jd_t_run env JD_BETA=1 JD_HOOK=1 "$JD_T_BIN" new id 21 Another title
_jd_t_status 'new: under the hook it exits 3' 3
_jd_t_eq 'new: and prints the folder to go to' \
  "$_jd_t_f21/21.37 Another title" "$JD_T_OUT"

# --json is the answer, so it never moves, hook or no hook.
_jd_t_run env JD_BETA=1 JD_HOOK=1 "$JD_T_BIN" new id 21 A third title --json
_jd_t_status 'new --json: under the hook it still exits 0' 0
_jd_t_eq 'new --json: and the object is the only thing on stdout' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"

# ----------------------------------------------------- what jd.sh makes
#
# From here the shell has the functions. Each one must name the program
# and hold no helper, because an agent's shell keeps jd and drops every
# _jd_ name around it.

_jd_fx_reset
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

if [ -n "${ZSH_VERSION-}" ]; then
  _jd_t_body() { typeset -f "$1"; }
else
  _jd_t_body() { declare -f "$1"; }
fi

for _jd_t_fn in jd jdex d25 p76; do
  _jd_t_out=$(_jd_t_body "$_jd_t_fn")
  _jd_t_contains "$_jd_t_fn: names the program" 'bin/jd' "$_jd_t_out"
  _jd_t_lacks "$_jd_t_fn: calls no helper" '_jd_' "$_jd_t_out"
done

_jd_t_eq 'jdex: passes the word jdex' 'jdex' \
  "$(_jd_t_body jdex | sed -n 's/.*bin\/jd. \([a-z]*\) .*/\1/p' | head -1)"
_jd_t_contains 'd25: passes its own system' '--system' "$(_jd_t_body d25)"
_jd_t_lacks 'jd: names no system, so the program picks the default' \
  '--system' "$(_jd_t_body jd)"

# bin is on $PATH, so a program started from this shell finds jd too.
_jd_t_contains 'jd.sh puts bin on $PATH' "$JD_T_REPO/bin" "$PATH"

_jd_t_summary
