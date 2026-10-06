# SPDX-License-Identifier: MIT
# paths.sh - where jd keeps its files, and 'jd paths', which prints them
#
# jd follows the XDG Base Directory Specification. The config is in
# $XDG_CONFIG_HOME/johnnydecimal, the journal in
# $XDG_STATE_HOME/johnnydecimal, and $JD_CONFIG names the config file
# itself. Up to 3.x all of it was in ~/.jd, the old place, which jd
# still reads for now.
#
# Every other case file names its config with $JD_CONFIG, so none of
# them finds a config the way a person's shell does. This one takes
# $JD_CONFIG away. $HOME is a folder under $JD_T_TMP, and
# _jd_t_no_config_var stops the file if it is not, so ~/.config, ~/.jd
# and ~/.local here are all the test's own.
#
# What is tested:
#   - each step in the order jd looks for the config
#   - an XDG variable that is not an absolute path is ignored
#   - the old place still works, and jd says so, in one line
#   - a config in the old place and the new one gets a warning
#   - the journal, the same way, and the mode of the folder jd makes
#   - 'jd paths', its --json, and the commands it prints, which are run
#   - 'jd agent-setup', which moves an old install with a step 0
#   - the shell hook, which asks the program where the config is

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# All three would reach the program through the environment.
unset JD_HOOK
unset JD_BETA
_jd_t_no_config_var

_jd_fx_build

_jd_t_new="$HOME/.config/johnnydecimal/config.json"
_jd_t_old="$HOME/.jd/config.json"
_jd_t_jnew="$HOME/.local/state/johnnydecimal/journal.jsonl"
_jd_t_jold="$HOME/.jd/journal.jsonl"
_jd_t_xdg="$JD_T_TMP/xdg"
_jd_t_mess="$JD_T_TMP/mess"
_jd_t_f11="$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"

# Take away every file jd keeps, so that a group starts from nothing.
_jd_t_wipe() {
  rm -rf "$HOME/.config" "$HOME/.jd" "$HOME/.local" "$_jd_t_xdg" "$JD_T_TMP/rel"
}

# Write a config. $1 the fixture writer, $2 the path. Its folder is made.
_jd_t_put() {
  mkdir -p "$(dirname -- "$2")"
  "$1" "$2"
}

# JSON field $1 of the last run's stdout.
_jd_t_json() { printf '%s' "$JD_T_OUT" | jq -r "$1"; }

# The number of lines in $1.
_jd_t_count() { printf '%s\n' "$1" | grep -c '^'; }

# The mode of $1, as three octal digits. GNU stat first, as lib/beta.sh
# does, and for the same reason.
_jd_t_mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null; }

# The commands 'jd paths' printed on stderr in the last run: the lines
# that are four spaces, then mkdir or mv.
_jd_t_cmds() {
  printf '%s\n' "$JD_T_ERR" |
    sed -n 's/^    \(mkdir .*\)$/\1/p; s/^    \(mv .*\)$/\1/p'
}

_jd_t_exists() {
  if [ -e "$2" ]; then _jd_t_ok "$1"; else _jd_t_bad "$1" "$2" 'nothing'; fi
}
_jd_t_gone() {
  if [ -e "$2" ] || [ -L "$2" ]; then _jd_t_bad "$1" 'nothing' "$2"; else _jd_t_ok "$1"; fi
}

# ------------------------------------------------- no config anywhere

_jd_t_wipe

_jd_t_run "$JD_T_BIN" paths config
_jd_t_status 'no config: jd paths config exit status' 0
_jd_t_eq 'no config: jd looks in ~/.config/johnnydecimal' "$_jd_t_new" "$JD_T_OUT"
_jd_t_eq 'no config: jd paths config says nothing on stderr' '' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN"
_jd_t_status 'no config: a move is an error' 1
_jd_t_contains 'no config: the error names the new place, not ~/.jd' \
  "no config at $_jd_t_new" "$JD_T_ERR"

# --------------------------------------- the order: 3, the default place

_jd_t_put _jd_fx_config_single "$_jd_t_new"

_jd_t_run "$JD_T_BIN"
_jd_t_status 'default: exit status' 0
_jd_t_eq 'default: jd reads ~/.config/johnnydecimal/config.json' "$JD_FX_ROOT" "$JD_T_OUT"
_jd_t_eq 'default: nothing on stderr' '' "$JD_T_ERR"

_jd_t_run env XDG_CONFIG_HOME= "$JD_T_BIN" paths config
_jd_t_eq 'default: an empty $XDG_CONFIG_HOME is the default too' "$_jd_t_new" "$JD_T_OUT"

# ------------------------------------- the order: 2, $XDG_CONFIG_HOME

# The second system only, so that which config answered can be told
# from where jd goes.
_jd_t_put _jd_fx_config_second_only "$_jd_t_xdg/config/johnnydecimal/config.json"

_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/config" "$JD_T_BIN"
_jd_t_status '$XDG_CONFIG_HOME: exit status' 0
_jd_t_eq '$XDG_CONFIG_HOME: wins over ~/.config' "$JD_FX_ROOT2" "$JD_T_OUT"

_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/config" "$JD_T_BIN" paths config
_jd_t_eq '$XDG_CONFIG_HOME: the config is in its johnnydecimal folder' \
  "$_jd_t_xdg/config/johnnydecimal/config.json" "$JD_T_OUT"

_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/config/" "$JD_T_BIN" paths config
_jd_t_eq '$XDG_CONFIG_HOME: a slash on the end makes no double slash' \
  "$_jd_t_xdg/config/johnnydecimal/config.json" "$JD_T_OUT"

# The variable names the base directory. It is not one more place to
# look: with it set, a config in ~/.config is not read, as git and gh
# do not read theirs.
_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/nothing" "$JD_T_BIN"
_jd_t_status '$XDG_CONFIG_HOME with no config in it: an error' 1
_jd_t_contains '$XDG_CONFIG_HOME with no config in it: ~/.config is not read' \
  "no config at $_jd_t_xdg/nothing/johnnydecimal/config.json" "$JD_T_ERR"

# ------------------------------------------- the order: 1, $JD_CONFIG

_jd_t_put _jd_fx_config_second_only "$JD_T_TMP/named-second.json"
_jd_t_put _jd_fx_config_single "$JD_T_TMP/named-first.json"

_jd_t_run env JD_CONFIG="$JD_T_TMP/named-second.json" "$JD_T_BIN"
_jd_t_eq '$JD_CONFIG: wins over ~/.config' "$JD_FX_ROOT2" "$JD_T_OUT"

_jd_t_run env JD_CONFIG="$JD_T_TMP/named-first.json" \
  XDG_CONFIG_HOME="$_jd_t_xdg/config" "$JD_T_BIN"
_jd_t_eq '$JD_CONFIG: wins over $XDG_CONFIG_HOME' "$JD_FX_ROOT" "$JD_T_OUT"

_jd_t_run env JD_CONFIG="$JD_T_TMP/named-first.json" \
  XDG_CONFIG_HOME="$_jd_t_xdg/config" "$JD_T_BIN" paths config
_jd_t_eq '$JD_CONFIG: jd paths config prints it' "$JD_T_TMP/named-first.json" "$JD_T_OUT"

# ------------------------------------------- a path that is not absolute

# The spec: a path in an XDG variable must be absolute, and one that is
# not is ignored. _jd_t_run starts in $JD_T_TMP, so 'rel' would be this
# folder, and there is a config in it to find.
_jd_t_put _jd_fx_config_second_only "$JD_T_TMP/rel/johnnydecimal/config.json"

_jd_t_run env XDG_CONFIG_HOME=rel "$JD_T_BIN"
_jd_t_eq 'relative $XDG_CONFIG_HOME: ignored, and jd reads ~/.config' \
  "$JD_FX_ROOT" "$JD_T_OUT"

_jd_t_run env XDG_CONFIG_HOME=./rel "$JD_T_BIN" paths config
_jd_t_eq 'relative $XDG_CONFIG_HOME: ./rel is ignored too' "$_jd_t_new" "$JD_T_OUT"

_jd_t_run env XDG_STATE_HOME=rel "$JD_T_BIN" paths journal
_jd_t_eq 'relative $XDG_STATE_HOME: ignored' "$_jd_t_jnew" "$JD_T_OUT"

# ------------------------------------------------ the old place: config

_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_old"

_jd_t_run "$JD_T_BIN"
_jd_t_status 'old place: exit status' 0
_jd_t_eq 'old place: jd still reads ~/.jd/config.json' "$JD_FX_ROOT" "$JD_T_OUT"
_jd_t_contains 'old place: jd says the config is there' \
  'the config is in ~/.jd, the old place' "$JD_T_ERR"
_jd_t_contains "old place: the line names 'jd paths'" \
  "'jd paths' says how to move it" "$JD_T_ERR"
_jd_t_eq 'old place: it is one line' 1 "$(_jd_t_count "$JD_T_ERR")"

_jd_t_run env JD_HOOK=1 "$JD_T_BIN" 11.11
_jd_t_status 'old place: under the hook a move still exits 3' 3
_jd_t_eq 'old place: and stdout is still the one folder' "$_jd_t_f11" "$JD_T_OUT"

# What reads no config says nothing about it.
_jd_t_run "$JD_T_BIN" version
_jd_t_eq 'old place: jd version says nothing' '' "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" help
_jd_t_eq 'old place: jd help says nothing' '' "$JD_T_ERR"

# The hooks run this at every shell start, so it must stay quiet.
_jd_t_run "$JD_T_BIN" paths config
_jd_t_eq 'old place: jd paths config prints the config jd reads' "$_jd_t_old" "$JD_T_OUT"
_jd_t_eq 'old place: jd paths config says nothing on stderr' '' "$JD_T_ERR"

# $JD_CONFIG is the user's own word, so the old place is not looked at.
_jd_t_put _jd_fx_config_second_only "$JD_T_TMP/named-second.json"
_jd_t_run env JD_CONFIG="$JD_T_TMP/named-second.json" "$JD_T_BIN"
_jd_t_eq 'old place: $JD_CONFIG wins over it' "$JD_FX_ROOT2" "$JD_T_OUT"
_jd_t_eq 'old place: with $JD_CONFIG set, nothing is said' '' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN" paths
_jd_t_status 'old place: jd paths exit status' 0
_jd_t_contains 'old place: jd paths prints the config jd reads' \
  "config   $_jd_t_old" "$JD_T_OUT"
_jd_t_contains 'old place: jd paths prints the command that makes the folder' \
  'mkdir -p -m 700 ~/.config/johnnydecimal' "$JD_T_ERR"
_jd_t_contains 'old place: jd paths prints the command that moves the config' \
  'mv ~/.jd/config.json ~/.config/johnnydecimal/' "$JD_T_ERR"
_jd_t_contains 'old place: jd paths names agent-setup for an agent' \
  "'jd agent-setup'" "$JD_T_ERR"
_jd_t_eq 'old place: stdout is the three paths and nothing else' 3 "$(_jd_t_count "$JD_T_OUT")"

# The commands are the upgrade path, so run them as printed.
eval "$(_jd_t_cmds)"
_jd_t_exists 'the printed commands: the config is in the new place' "$_jd_t_new"
_jd_t_gone 'the printed commands: it has left the old place' "$_jd_t_old"
_jd_t_eq 'the printed commands: the new folder is mode 700' 700 \
  "$(_jd_t_mode "$HOME/.config/johnnydecimal")"
_jd_t_run "$JD_T_BIN"
_jd_t_eq 'after the move: jd reads the new place' "$JD_FX_ROOT" "$JD_T_OUT"
_jd_t_eq 'after the move: and says nothing' '' "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" paths
_jd_t_eq 'after the move: jd paths says nothing on stderr' '' "$JD_T_ERR"

# A path that a shell minds is printed in quotes, and still works.
_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_old"
_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/my config" "$JD_T_BIN" paths
_jd_t_contains 'a path with a space: the command quotes it' \
  "mkdir -p -m 700 '$_jd_t_xdg/my config/johnnydecimal'" "$JD_T_ERR"
eval "$(_jd_t_cmds)"
_jd_t_exists 'a path with a space: the printed commands still move the config' \
  "$_jd_t_xdg/my config/johnnydecimal/config.json"

# ------------------------------------------- the old place and the new

_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_old"
_jd_t_put _jd_fx_config_second_only "$_jd_t_new"

_jd_t_run "$JD_T_BIN"
_jd_t_status 'both places: exit status' 0
_jd_t_eq 'both places: jd reads the new one' "$JD_FX_ROOT2" "$JD_T_OUT"
_jd_t_contains 'both places: jd warns that the old one is not read' \
  'there is a config in ~/.jd, the old place, that jd does not read' "$JD_T_ERR"
_jd_t_eq 'both places: the warning is one line' 1 "$(_jd_t_count "$JD_T_ERR")"

_jd_t_run "$JD_T_BIN" paths
_jd_t_contains 'both places: jd paths prints the new one' "config   $_jd_t_new" "$JD_T_OUT"
_jd_t_contains 'both places: jd paths says which one jd reads' \
  "jd reads $_jd_t_new" "$JD_T_ERR"
_jd_t_contains 'both places: jd paths says how to delete the old one' \
  'rm ~/.jd/config.json' "$JD_T_ERR"
_jd_t_eq 'both places: jd paths prints no command that moves one over the other' \
  '' "$(_jd_t_cmds)"

_jd_t_run "$JD_T_BIN" paths --json
_jd_t_eq 'both places: the --json warning' 'old_config_ignored' "$(_jd_t_json '.warnings[0]')"

# A ~/.jd that is a link to the new folder is one config with two
# names. That is not two configs.
rm -rf "$HOME/.jd"
ln -s "$HOME/.config/johnnydecimal" "$HOME/.jd"
_jd_t_run "$JD_T_BIN"
_jd_t_eq 'a ~/.jd that links to the new folder: no warning' '' "$JD_T_ERR"
rm "$HOME/.jd"

# ------------------------------------------------------- the journal

_jd_t_wipe
_jd_t_put _jd_fx_config_two "$_jd_t_new"
JD_BETA=1
export JD_BETA

# A fresh file in the mess, and its path on stdout.
_jd_t_file() {
  mkdir -p "$_jd_t_mess"
  printf 'x\n' >"$_jd_t_mess/$1"
  printf '%s' "$_jd_t_mess/$1"
}

_jd_t_run "$JD_T_BIN" paths journal
_jd_t_eq 'journal: jd paths journal prints the default place' "$_jd_t_jnew" "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" move "$(_jd_t_file a.txt)" 11.11 --json
_jd_t_status 'journal: a move exit status' 0
_jd_t_eq 'journal: the move names the journal in ~/.local/state' \
  "$_jd_t_jnew" "$(_jd_t_json .journal)"
_jd_t_exists 'journal: it is written there' "$_jd_t_jnew"
_jd_t_gone 'journal: nothing is written to ~/.jd' "$HOME/.jd"
_jd_t_eq 'journal: nothing is said about the old place' '' \
  "$(printf '%s\n' "$JD_T_ERR" | grep 'old place')"

# The spec asks for mode 700 on a folder a program makes. jd made all
# three of these.
_jd_t_eq 'journal: its folder is made with mode 700' 700 \
  "$(_jd_t_mode "$HOME/.local/state/johnnydecimal")"
_jd_t_eq 'journal: and so is the missing folder above it' 700 \
  "$(_jd_t_mode "$HOME/.local/state")"
_jd_t_eq 'journal: and the one above that' 700 "$(_jd_t_mode "$HOME/.local")"

_jd_t_run env XDG_STATE_HOME="$_jd_t_xdg/state" "$JD_T_BIN" \
  move "$(_jd_t_file b.txt)" 11.11 --json
_jd_t_eq '$XDG_STATE_HOME: the journal is in its johnnydecimal folder' \
  "$_jd_t_xdg/state/johnnydecimal/journal.jsonl" "$(_jd_t_json .journal)"
_jd_t_exists '$XDG_STATE_HOME: it is written there' \
  "$_jd_t_xdg/state/johnnydecimal/journal.jsonl"
_jd_t_eq '$XDG_STATE_HOME: the default journal gets no line' 1 \
  "$(grep -c '^' "$_jd_t_jnew")"

_jd_t_run env XDG_STATE_HOME=rel "$JD_T_BIN" move "$(_jd_t_file c.txt)" 11.11 --json
_jd_t_eq 'relative $XDG_STATE_HOME: the move uses the default journal' \
  "$_jd_t_jnew" "$(_jd_t_json .journal)"
_jd_t_gone 'relative $XDG_STATE_HOME: no folder is made from it' "$JD_T_TMP/rel"

# -------------------------------------------- the old place: journal

# The journal so far, put where 3.x kept it.
mkdir -p "$HOME/.jd"
mv "$_jd_t_jnew" "$_jd_t_jold"
rm -rf "$HOME/.local"

_jd_t_run "$JD_T_BIN" move "$(_jd_t_file d.txt)" 11.11 --json
_jd_t_status 'old journal: a move exit status' 0
_jd_t_eq 'old journal: jd still writes ~/.jd/journal.jsonl' \
  "$_jd_t_jold" "$(_jd_t_json .journal)"
_jd_t_eq 'old journal: the move is one more line in it' 3 "$(grep -c '^' "$_jd_t_jold")"
_jd_t_gone 'old journal: no second journal is started in the new place' "$HOME/.local"
_jd_t_contains 'old journal: jd says the journal is there' \
  'the journal is in ~/.jd, the old place' "$JD_T_ERR"
_jd_t_eq 'old journal: in one line' 1 \
  "$(printf '%s\n' "$JD_T_ERR" | grep -c 'old place')"

_jd_t_run "$JD_T_BIN" move --help
_jd_t_lacks 'old journal: the help says nothing about it' 'old place' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'old journal: a command that uses no journal says nothing' '' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN" paths
_jd_t_contains 'old journal: jd paths prints the journal jd uses' \
  "journal  $_jd_t_jold" "$JD_T_OUT"
_jd_t_contains 'old journal: jd paths prints the command that moves it' \
  'mv ~/.jd/journal.jsonl ~/.local/state/johnnydecimal/' "$JD_T_ERR"
_jd_t_run "$JD_T_BIN" paths --json
_jd_t_eq 'old journal: the --json warning' 'old_journal' "$(_jd_t_json '.warnings[0]')"

# Run the commands, then undo a move that was made before them. The
# journal is the same file in a new place, so the undo still finds it.
_jd_t_run "$JD_T_BIN" paths
eval "$(_jd_t_cmds)"
_jd_t_exists 'the printed commands: the journal is in the new place' "$_jd_t_jnew"
_jd_t_gone 'the printed commands: it has left the old place' "$_jd_t_jold"
_jd_t_run "$JD_T_BIN" undo move --json
_jd_t_status 'after the move: undo exit status' 0
_jd_t_eq 'after the move: undo reads the journal in the new place' \
  "$_jd_t_jnew" "$(_jd_t_json .journal)"
_jd_t_eq 'after the move: it undoes the move made in the old place' \
  "$_jd_t_f11/d.txt" "$(_jd_t_json .from)"
_jd_t_lacks 'after the move: nothing is said about the old place' 'old place' "$JD_T_ERR"

# A journal in each place: jd uses the new one, and says the old one is
# not read.
mkdir -p "$HOME/.jd"
printf '{"at":"2026-01-01T00:00:00Z"}\n' >"$_jd_t_jold"
_jd_t_run "$JD_T_BIN" move "$(_jd_t_file e.txt)" 11.11 --json
_jd_t_eq 'both journals: jd uses the new one' "$_jd_t_jnew" "$(_jd_t_json .journal)"
_jd_t_contains 'both journals: jd warns that the old one is not read' \
  'there is a journal in ~/.jd, the old place, that jd does not read' "$JD_T_ERR"
_jd_t_eq 'both journals: the old one gets no line' 1 "$(grep -c '^' "$_jd_t_jold")"

unset JD_BETA
_jd_fx_reset
rm -rf "$_jd_t_mess"

# ------------------------------------------------------------ jd paths

_jd_t_wipe

_jd_t_run "$JD_T_BIN" paths
_jd_t_status 'jd paths: works with no config' 0
_jd_t_eq 'jd paths: three lines' 3 "$(_jd_t_count "$JD_T_OUT")"
_jd_t_eq 'jd paths: the config' "config   $_jd_t_new" \
  "$(printf '%s\n' "$JD_T_OUT" | sed -n 1p)"
_jd_t_eq 'jd paths: the journal' "journal  $_jd_t_jnew" \
  "$(printf '%s\n' "$JD_T_OUT" | sed -n 2p)"
_jd_t_eq 'jd paths: the install is the folder this copy of jd is in' \
  "install  $JD_T_REPO" "$(printf '%s\n' "$JD_T_OUT" | sed -n 3p)"
_jd_t_eq 'jd paths: nothing on stderr when nothing is in the old place' '' "$JD_T_ERR"
_jd_t_gone 'jd paths: it makes no folder' "$HOME/.config"

_jd_t_run "$JD_T_BIN" paths install
_jd_t_eq 'jd paths install: one path' "$JD_T_REPO" "$JD_T_OUT"

# The install is where jd is. $XDG_DATA_HOME is where the README says to
# clone it, and jd does not pretend to be there.
_jd_t_run env XDG_DATA_HOME="$_jd_t_xdg/data" "$JD_T_BIN" paths install
_jd_t_eq 'jd paths install: $XDG_DATA_HOME does not change where jd is' \
  "$JD_T_REPO" "$JD_T_OUT"

_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/config" XDG_STATE_HOME="$_jd_t_xdg/state" \
  "$JD_T_BIN" paths --json
_jd_t_status 'jd paths --json: exit status' 0
_jd_t_eq 'jd paths --json: one object' 1 "$(printf '%s' "$JD_T_OUT" | jq -s 'length')"
_jd_t_eq 'jd paths --json: ok' true "$(_jd_t_json .ok)"
_jd_t_eq 'jd paths --json: config' "$_jd_t_xdg/config/johnnydecimal/config.json" \
  "$(_jd_t_json .config)"
_jd_t_eq 'jd paths --json: journal' "$_jd_t_xdg/state/johnnydecimal/journal.jsonl" \
  "$(_jd_t_json .journal)"
_jd_t_eq 'jd paths --json: install' "$JD_T_REPO" "$(_jd_t_json .install)"
_jd_t_eq 'jd paths --json: no warnings when nothing is in the old place' 0 \
  "$(_jd_t_json '.warnings | length')"

_jd_t_run "$JD_T_BIN" paths --help
_jd_t_status 'jd paths --help: exit status' 0
_jd_t_contains 'jd paths --help: prints the usage line' 'usage: <system> paths' "$JD_T_OUT"
_jd_t_contains 'jd paths --help: names the spec' 'XDG Base Directory Specification' "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" help
_jd_t_contains 'jd help: names paths' '<system> paths' "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" paths cache
_jd_t_status 'jd paths with a word it does not know: an error' 1
_jd_t_contains 'jd paths with a word it does not know: says so' \
  "'cache' is not a path jd has" "$JD_T_ERR"
_jd_t_eq 'jd paths with a word it does not know: nothing on stdout' '' "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" paths cache --json
_jd_t_eq 'jd paths --json: an unknown word has a code' unknown_path "$(_jd_t_json .code)"
_jd_t_eq 'jd paths --json: and ok is false' false "$(_jd_t_json .ok)"

_jd_t_run "$JD_T_BIN" paths --bogus --json
_jd_t_eq 'jd paths --json: an unknown option has a code' unknown_option "$(_jd_t_json .code)"

_jd_t_run "$JD_T_BIN" paths config journal
_jd_t_status 'jd paths with two names: an error' 1
_jd_t_contains 'jd paths with two names: says so' "unexpected word 'journal'" "$JD_T_ERR"

_jd_t_run "$JD_T_BIN" paths config --json
_jd_t_status 'jd paths config --json: an error' 1
_jd_t_contains 'jd paths config --json: says it prints one path' \
  'prints one path' "$JD_T_ERR"

# No system is needed, and one that is named makes no difference.
_jd_t_run "$JD_T_BIN" --system P76 paths config
_jd_t_eq 'jd paths: --system does not change it' "$_jd_t_new" "$JD_T_OUT"

# jd paths is for the person with nothing set up, so it needs no jq.
_jd_t_path=$PATH
PATH=$(_jd_fx_nojq_bin)
if command -v jq >/dev/null 2>&1; then
  PATH=$_jd_t_path
  _jd_t_bad 'no jq: jq can be hidden' 'no jq on $PATH' 'jq is still there'
else
  _jd_t_run "$JD_T_BIN" paths
  _jd_t_status 'no jq: jd paths works' 0
  _jd_t_eq 'no jq: jd paths prints the three paths' 3 "$(_jd_t_count "$JD_T_OUT")"
  _jd_t_run "$JD_T_BIN" paths --json
  _jd_t_status 'no jq: jd paths --json is an error' 1
  _jd_t_contains 'no jq: jd paths --json says so' 'jq is not installed' "$JD_T_ERR"
  PATH=$_jd_t_path
fi

# ------------------------------------------ this copy of jd, in ~/.jd

# A folder link, so that the program runs from ~/.jd/cli, which is where
# the README put it up to 3.x.
_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_new"
mkdir -p "$HOME/.jd"
ln -s "$JD_T_REPO" "$HOME/.jd/cli"
_jd_t_oldbin="$HOME/.jd/cli/bin/jd"

_jd_t_run "$_jd_t_oldbin" paths
_jd_t_status 'old install: jd paths exit status' 0
_jd_t_contains 'old install: jd paths prints where this copy is' \
  "install  $HOME/.jd/cli" "$JD_T_OUT"
_jd_t_contains 'old install: jd paths says it is in the old place' \
  'this copy of jd is in ~/.jd, the old place' "$JD_T_ERR"
_jd_t_contains 'old install: jd paths prints the command that moves it' \
  'mv ~/.jd/cli ~/.local/share/johnnydecimal/' "$JD_T_ERR"
_jd_t_contains 'old install: jd paths says to change the shell config' \
  'Then change ~/.jd/cli to ~/.local/share/johnnydecimal/cli' "$JD_T_ERR"

_jd_t_run env XDG_DATA_HOME="$_jd_t_xdg/data" "$_jd_t_oldbin" paths
_jd_t_contains 'old install: $XDG_DATA_HOME is where it moves to' \
  "mv ~/.jd/cli $_jd_t_xdg/data/johnnydecimal/" "$JD_T_ERR"

_jd_t_run "$_jd_t_oldbin" paths --json
_jd_t_eq 'old install: the --json warning' 'old_install' "$(_jd_t_json '.warnings[0]')"

# It works where it is, for as long as the user leaves it there. So an
# ordinary command does not mention it.
_jd_t_run "$_jd_t_oldbin" 11.11
_jd_t_eq 'old install: an ordinary command says nothing' '' "$JD_T_ERR"

_jd_t_run "$_jd_t_oldbin" help
_jd_t_contains 'old install: jd help names this copy, where it is' \
  "$HOME/.jd/cli/bin/jd" "$JD_T_OUT"

# ------------------------------------------- a link in ~/.local/bin

# The README says a link to the program from ~/.local/bin works. The
# program follows the link, so it still finds lib, and it still says
# where it really is.
_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_new"
mkdir -p "$HOME/.local/bin"
ln -s "$JD_T_BIN" "$HOME/.local/bin/jd"
_jd_t_run "$HOME/.local/bin/jd" 11.11
_jd_t_status 'a link in ~/.local/bin: exit status' 0
_jd_t_eq 'a link in ~/.local/bin: the program runs' "$_jd_t_f11" "$JD_T_OUT"
_jd_t_run "$HOME/.local/bin/jd" paths install
_jd_t_eq 'a link in ~/.local/bin: the install is where the program is' \
  "$JD_T_REPO" "$JD_T_OUT"

# ------------------------------------------------------ jd agent-setup

# The prompt has a blank line before step 1, with a step 0 or without.
_jd_t_nl='
'

_jd_t_wipe
_jd_t_run "$JD_T_BIN" agent-setup
_jd_t_status 'agent-setup, nothing set up: exit status' 0
_jd_t_contains 'agent-setup, nothing set up: the prompt names the new place' \
  "It needs a configuration file at $_jd_t_new. It does not exist yet." "$JD_T_OUT"
_jd_t_lacks 'agent-setup, nothing set up: there is no step 0' '0. First, move' "$JD_T_OUT"
_jd_t_lacks 'agent-setup, nothing set up: the old place is not named' \
  'the old place' "$JD_T_OUT"
_jd_t_contains 'agent-setup, nothing set up: a blank line before step 1' \
  "what each field means.${_jd_t_nl}${_jd_t_nl}1. Check that jq" "$JD_T_OUT"
_jd_t_contains 'agent-setup: the prompt says to make the folder with mode 700' \
  'mode 700' "$JD_T_OUT"

_jd_t_run env XDG_CONFIG_HOME="$_jd_t_xdg/config" "$JD_T_BIN" agent-setup
_jd_t_contains 'agent-setup: the prompt names the config in $XDG_CONFIG_HOME' \
  "It needs a configuration file at $_jd_t_xdg/config/johnnydecimal/config.json." "$JD_T_OUT"

# Everything in the old place: the config, the journal, and this copy.
_jd_t_put _jd_fx_config_single "$_jd_t_old"
printf '{"at":"2026-01-01T00:00:00Z"}\n' >"$_jd_t_jold"
ln -s "$JD_T_REPO" "$HOME/.jd/cli"

_jd_t_run "$_jd_t_oldbin" agent-setup
_jd_t_status 'agent-setup, old install: exit status' 0
_jd_t_contains 'agent-setup, old install: the prompt opens with step 0' \
  '0. First, move my jd files out of ~/.jd.' "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: step 0 moves the config' \
  "The configuration file: move $_jd_t_old to $_jd_t_new" "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: step 0 moves the journal' \
  "move $_jd_t_jold to $_jd_t_jnew" "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: step 0 moves the program' \
  "The program: move the folder $HOME/.jd/cli to $HOME/.local/share/johnnydecimal/cli" \
  "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: then it sends the agent to the new copy' \
  "Run $HOME/.local/share/johnnydecimal/cli/bin/jd agent-setup" "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: the agent waits for a yes' \
  'Wait for my yes to each line before you move anything' "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: the prompt says the config is in the old place' \
  "My configuration file is still at $_jd_t_old, the old place" "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: the config is still to be kept as it is' \
  'change nothing in it without asking me' "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: a blank line before step 1' \
  "${_jd_t_nl}${_jd_t_nl}1. Check that jq" "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: the safety rules allow step 0' \
  'If there is a step 0, you can also move the items that step 0 lists.' "$JD_T_OUT"
_jd_t_contains 'agent-setup, old install: the person is told' \
  'you have a config in ~/.jd, the old place' "$JD_T_ERR"
_jd_t_lacks 'agent-setup, old install: only the prompt is on stdout' 'jd:' "$JD_T_OUT"

# Only the journal is old: step 0 names that, and not the rest.
_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_new"
mkdir -p "$HOME/.jd"
printf '{"at":"2026-01-01T00:00:00Z"}\n' >"$_jd_t_jold"
_jd_t_run "$JD_T_BIN" agent-setup
_jd_t_contains 'agent-setup, old journal only: step 0 moves the journal' \
  "move $_jd_t_jold to $_jd_t_jnew" "$JD_T_OUT"
_jd_t_lacks 'agent-setup, old journal only: it does not move the config' \
  'The configuration file: move' "$JD_T_OUT"
_jd_t_lacks 'agent-setup, old journal only: it does not move the program' \
  'The program: move' "$JD_T_OUT"
_jd_t_contains 'agent-setup, old journal only: the config in the new place is kept' \
  'It exists already.' "$JD_T_OUT"

# A config in each place: the agent shows both, and deletes nothing
# without a yes.
_jd_t_wipe
_jd_t_put _jd_fx_config_single "$_jd_t_old"
_jd_t_put _jd_fx_config_second_only "$_jd_t_new"
_jd_t_run "$JD_T_BIN" agent-setup
_jd_t_contains 'agent-setup, both places: step 0 names the old config' \
  "An old configuration file that jd does not read: $_jd_t_old" "$JD_T_OUT"
_jd_t_contains 'agent-setup, both places: nothing is deleted without a yes' \
  'Delete the old file only when I say yes' "$JD_T_OUT"

# ------------------------------------------------------- the shell hook

# jd.sh asks the program where the config is. So with no $JD_CONFIG it
# finds the per-system commands in each place the program does.

# Source jd.sh with what is in the environment now. Sets $JD_T_LOADERR.
_jd_t_hook() {
  _jd_t_unload
  . "$JD_T_REPO/jd.sh" 2>"$JD_T_TMP/.loaderr"
  JD_T_LOADERR=$(cat "$JD_T_TMP/.loaderr")
}

# $1 name. The per-system commands are both there.
_jd_t_has_systems() {
  if command -v d25 >/dev/null 2>&1 && command -v p76 >/dev/null 2>&1; then
    _jd_t_ok "$1"
  else
    _jd_t_bad "$1" 'd25 and p76 are both defined' 'at least one is missing'
  fi
}

_jd_t_wipe
_jd_t_put _jd_fx_config_two "$_jd_t_new"
_jd_t_hook
_jd_t_has_systems 'hook: a config in ~/.config gives one command per system'
_jd_t_eq 'hook: loading says nothing' '' "$JD_T_LOADERR"
_jd_t_run d25
_jd_t_at 'hook: a per-system command goes to its root' "$JD_FX_ROOT"
_jd_t_run jd paths config
_jd_t_eq 'hook: jd paths config prints the path' "$_jd_t_new" "$JD_T_OUT"
_jd_t_at 'hook: jd paths does not move us' "$JD_T_TMP"
_jd_t_eq 'hook: jd.sh leaves no $_jd_hook_cfg in the shell' 'unset' "${_jd_hook_cfg-unset}"

_jd_t_wipe
_jd_t_put _jd_fx_config_two "$_jd_t_xdg/config/johnnydecimal/config.json"
XDG_CONFIG_HOME="$_jd_t_xdg/config"
export XDG_CONFIG_HOME
_jd_t_hook
_jd_t_has_systems 'hook: a config in $XDG_CONFIG_HOME gives one command per system'
unset XDG_CONFIG_HOME

# The old place. A new shell is not where the user is told: the line
# comes with the command, so shell start stays quiet.
_jd_t_wipe
_jd_t_put _jd_fx_config_two "$_jd_t_old"
_jd_t_hook
_jd_t_has_systems 'hook: a config in ~/.jd still gives one command per system'
_jd_t_eq 'hook: loading says nothing about the old place' '' "$JD_T_LOADERR"
_jd_t_run jd 11.11
_jd_t_at 'hook: jd still moves the shell' "$_jd_t_f11"
_jd_t_contains 'hook: and the command says the config is in the old place' \
  'the config is in ~/.jd, the old place' "$JD_T_ERR"

_jd_t_wipe
_jd_t_hook
if command -v d25 >/dev/null 2>&1; then
  _jd_t_bad 'hook: no config, no per-system command' 'no d25' 'd25 is defined'
else
  _jd_t_ok 'hook: no config, no per-system command'
fi
_jd_t_eq 'hook: no config, loading says nothing' '' "$JD_T_LOADERR"

# The zsh prompt reads the same config, through the hook.
if [ -z "${ZSH_VERSION-}" ]; then
  _jd_t_skipped 'zsh prompt: finds the config with no $JD_CONFIG' 'zsh only, and this is bash'
else
  _jd_t_wipe
  _jd_t_put _jd_fx_config_two "$_jd_t_new"
  _jd_t_hook
  _jd_t_run_from "$JD_FX_ROOT" _jd_pwd
  _jd_t_eq 'zsh prompt: a config in ~/.config' 'D25:~' "$JD_T_OUT"

  _jd_t_wipe
  _jd_t_put _jd_fx_config_two "$_jd_t_old"
  _jd_t_hook
  _jd_t_run_from "$JD_FX_ROOT" _jd_pwd
  _jd_t_eq 'zsh prompt: a config in ~/.jd, the old place' 'D25:~' "$JD_T_OUT"

  # Sourced on its own, with no jd.sh before it, the file asks the
  # program itself.
  _jd_t_wipe
  _jd_t_put _jd_fx_config_second_only "$_jd_t_new"
  unset -f _jd_pwd
  . "$JD_T_REPO/lib/prompt.zsh"
  _jd_t_run_from "$JD_FX_ROOT2" _jd_pwd
  _jd_t_eq 'zsh prompt: sourced on its own, it still finds the config' 'P76:~' "$JD_T_OUT"
fi

_jd_t_wipe
_jd_t_summary
