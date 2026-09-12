# SPDX-License-Identifier: MIT
# move.sh - jd move, which moves a file or folder into an ID and journals
# it, and jd undo move, which moves it back
#
# The mess is a folder outside every fixture system, under $JD_T_TMP.
# The journal is ~/.jd/journal.jsonl, and $HOME is under $JD_T_TMP too,
# so nothing here touches a real journal.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

JD_BETA=1
export JD_BETA

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_mess="$JD_T_TMP/mess"
_jd_t_f11="$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"
_jd_t_f12="$JD_FX_ROOT/10-19 Area one/12 Category twelve"
_jd_t_w189="$JD_FX_ROOT/10-19 Area one/W0189 Work package one"
_jd_t_p31="$JD_FX_ROOT2/30-39 Area three/31 Category thirtyone/31.11 Pear"
_jd_t_journal="$HOME/.jd/journal.jsonl"

# A fresh mess. Called before each group, so a group starts from the
# same files whatever the one before it did.
_jd_t_mess_build() {
  rm -rf "$_jd_t_mess"
  mkdir -p "$_jd_t_mess/Photos" "$_jd_t_mess/-dashed"
  printf 'x\n' >"$_jd_t_mess/Invoice & co, 2026.pdf"
  printf 'y\n' >"$_jd_t_mess/Photos/a.jpg"
  printf 'z\n' >"$_jd_t_mess/plain.txt"
  : >"$_jd_t_mess/.Stub.pdf.icloud"
}

# JSON field $1 of the last run's stdout.
_jd_t_json() { printf '%s' "$JD_T_OUT" | jq -r "$1"; }

# Field $2 of journal line $1, counted from 1.
_jd_t_jline() { sed -n "${1}p" "$_jd_t_journal" | jq -r "$2"; }

_jd_t_lines() { grep -c '^' "$_jd_t_journal" 2>/dev/null || printf 0; }

_jd_t_exists() {
  if [ -e "$2" ]; then _jd_t_ok "$1"; else _jd_t_bad "$1" "$2" 'nothing'; fi
}
_jd_t_gone() {
  if [ -e "$2" ]; then _jd_t_bad "$1" 'nothing' "$2"; else _jd_t_ok "$1"; fi
}

# ------------------------------------------------------------------ help

_jd_t_run jd move --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' 'usage: <system> move <path> <id>' "$JD_T_OUT"

_jd_t_run jd undo move --help
_jd_t_status 'undo help: exit status' 0
_jd_t_contains 'undo help: prints the usage line' 'usage: <system> undo move [<path>]' "$JD_T_OUT"

_jd_t_run jd help
_jd_t_contains 'jd help: names move' 'move <path> 21.34' "$JD_T_OUT"
_jd_t_contains 'jd help: names undo move' 'undo move' "$JD_T_OUT"

# ------------------------------------------------------------------ beta

_jd_t_mess_build
JD_BETA=0 _jd_t_run jd move "$_jd_t_mess/plain.txt" 11.11 --json
_jd_t_status 'beta off: exit status' 1
_jd_t_eq 'beta off: code' beta_off "$(_jd_t_json .code)"
_jd_t_exists 'beta off: moves nothing' "$_jd_t_mess/plain.txt"

JD_BETA=0 _jd_t_run jd move --help
_jd_t_status 'beta off: help still works' 0

# ------------------------------------------------------------- the words

_jd_t_run jd move --json
_jd_t_status 'no path: exit status' 1
_jd_t_eq 'no path: code' no_path "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" --json
_jd_t_eq 'no id: code' no_id "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" 11.11 extra --json
_jd_t_eq 'three words: code' unexpected_word "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" 11.11 --bogus --json
_jd_t_eq 'unknown flag: code' unknown_option "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" pear --json
_jd_t_eq 'a word is not an id: code' not_an_id "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" 11.99 --json
_jd_t_eq 'no such id: code' no_match "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" 19.99 --json
_jd_t_eq 'id in the JDex with no category folder: code' no_category "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/nothing-here" 11.11 --json
_jd_t_eq 'no source: code' no_source "$(_jd_t_json .code)"
_jd_t_eq 'no source: path' "$_jd_t_mess/nothing-here" "$(_jd_t_json .path)"

_jd_t_run jd jdex move "$_jd_t_mess/plain.txt" 11.11
_jd_t_status 'jdex move: refused' 1
_jd_t_contains 'jdex move: says why' 'works in the filesystem' "$JD_T_ERR"

_jd_t_run jd undo --json
_jd_t_eq 'undo with no noun: code' no_noun "$(_jd_t_json .code)"
_jd_t_run jd undo new --json
_jd_t_eq 'undo of another noun: code' unknown_noun "$(_jd_t_json .code)"

if [ "$(_jd_t_lines)" -eq 0 ]; then
  _jd_t_ok 'a refused move writes no journal line'
else
  _jd_t_bad 'a refused move writes no journal line' '0 lines' "$(_jd_t_lines) lines"
fi

# --------------------------------------------------------------- dry run

_jd_t_run jd move "$_jd_t_mess/plain.txt" 11.11 --dry-run
_jd_t_status 'dry run: exit status' 0
_jd_t_eq 'dry run: prints no path on stdout' '' "$JD_T_OUT"
_jd_t_contains 'dry run: names the source' "from    $_jd_t_mess/plain.txt" "$JD_T_ERR"
_jd_t_contains 'dry run: names the target' "to      $_jd_t_f11/plain.txt" "$JD_T_ERR"
_jd_t_contains 'dry run: says it moved nothing' 'nothing was moved' "$JD_T_ERR"
_jd_t_exists 'dry run: the file stays' "$_jd_t_mess/plain.txt"
_jd_t_gone 'dry run: nothing arrives' "$_jd_t_f11/plain.txt"
_jd_t_eq 'dry run: no journal line' 0 "$(_jd_t_lines)"

_jd_t_run jd move "$_jd_t_mess/plain.txt" 11.11 --dry-run --json
_jd_t_eq 'dry run json: ok' true "$(_jd_t_json .ok)"
_jd_t_eq 'dry run json: dryRun' true "$(_jd_t_json .dryRun)"
_jd_t_eq 'dry run json: at is empty, because nothing was written' '' "$(_jd_t_json .at)"

# ----------------------------------------------------------- moving a file

_jd_t_run_from "$_jd_t_mess" jd move 'Invoice & co, 2026.pdf' 11.11
_jd_t_status 'file: exit status' 0
_jd_t_eq 'file: prints the new path' "$_jd_t_f11/Invoice & co, 2026.pdf" "$JD_T_OUT"
_jd_t_at 'file: the shell does not cd' "$_jd_t_mess"
_jd_t_exists 'file: it is in the ID folder' "$_jd_t_f11/Invoice & co, 2026.pdf"
_jd_t_gone 'file: it has left the mess' "$_jd_t_mess/Invoice & co, 2026.pdf"
_jd_t_eq 'file: one journal line' 1 "$(_jd_t_lines)"
_jd_t_eq 'journal: sys' D25 "$(_jd_t_jline 1 .sys)"
_jd_t_eq 'journal: id' 11.11 "$(_jd_t_jline 1 .id)"
_jd_t_eq 'journal: kind' file "$(_jd_t_jline 1 .kind)"
_jd_t_eq 'journal: from is absolute' "$_jd_t_mess/Invoice & co, 2026.pdf" "$(_jd_t_jline 1 .from)"
_jd_t_eq 'journal: to' "$_jd_t_f11/Invoice & co, 2026.pdf" "$(_jd_t_jline 1 .to)"
_jd_t_eq 'journal: the shell hook is a person' person "$(_jd_t_jline 1 .by)"
_jd_t_contains 'journal: at is UTC' 'Z' "$(_jd_t_jline 1 .at)"
_jd_t_eq 'journal: a move has no undoes' null "$(_jd_t_jline 1 .undoes)"

# -------------------------------------------------------- moving a folder

_jd_t_run jd move "$_jd_t_mess/Photos/" 11.11 --json
_jd_t_status 'folder: exit status' 0
_jd_t_eq 'folder: kind' folder "$(_jd_t_json .kind)"
_jd_t_eq 'folder: a trailing slash is dropped' "$_jd_t_f11/Photos" "$(_jd_t_json .to)"
_jd_t_exists 'folder: it moved whole' "$_jd_t_f11/Photos/a.jpg"
_jd_t_eq 'folder: one journal line for the folder' 2 "$(_jd_t_lines)"

# --------------------------------------------------------------- the json

printf 'agent\n' >"$_jd_t_mess/agent.txt"
_jd_t_run "$JD_T_BIN" move "$_jd_t_mess/agent.txt" W0189 --json
_jd_t_status 'json: exit status' 0
_jd_t_eq 'json: ok' true "$(_jd_t_json .ok)"
_jd_t_eq 'json: id is the W number' W0189 "$(_jd_t_json .id)"
_jd_t_eq 'json: to' "$_jd_t_w189/agent.txt" "$(_jd_t_json .to)"
_jd_t_eq 'json: the program is a program' program "$(_jd_t_json .by)"
_jd_t_eq 'json: names the journal' "$_jd_t_journal" "$(_jd_t_json .journal)"
_jd_t_eq 'json: a move has no undoes' null "$(_jd_t_json .undoes)"

# ----------------------------------------------------------- refusals

printf 'again\n' >"$_jd_t_mess/agent.txt"
_jd_t_run jd move "$_jd_t_mess/agent.txt" W0189 --json
_jd_t_status 'collision: exit status' 1
_jd_t_eq 'collision: code' exists "$(_jd_t_json .code)"
_jd_t_eq 'collision: path is the taken target' "$_jd_t_w189/agent.txt" "$(_jd_t_json .path)"
_jd_t_exists 'collision: the source stays' "$_jd_t_mess/agent.txt"
rm "$_jd_t_mess/agent.txt"

_jd_t_run jd move "$_jd_t_f11/Photos" 11.11 --json
_jd_t_eq 'already there: code' exists "$(_jd_t_json .code)"

_jd_t_run jd move "$_jd_t_mess/.Stub.pdf.icloud" 11.11 --json
_jd_t_eq 'icloud stub: code' not_downloaded "$(_jd_t_json .code)"
_jd_t_exists 'icloud stub: stays' "$_jd_t_mess/.Stub.pdf.icloud"

_jd_t_run jd move "$JD_FX_ROOT" 11.11 --json
_jd_t_eq 'target inside source: code' nested "$(_jd_t_json .code)"
_jd_t_exists 'target inside source: nothing moved' "$_jd_t_f11"

_jd_t_eq 'refusals: no journal lines' 3 "$(_jd_t_lines)"

# ------------------------------------------------- an id with no folder

_jd_t_run jd move "$_jd_t_mess/plain.txt" 12.99
_jd_t_status 'id in the JDex only: exit status' 0
_jd_t_contains 'id in the JDex only: the folder is made first' 'created 12.99 Made by jd' "$JD_T_ERR"
_jd_t_exists 'id in the JDex only: the file is in the new folder' "$_jd_t_f12/12.99 Made by jd/plain.txt"

# --------------------------------------------------------- another system

_jd_t_run jd --system P76 move "$_jd_t_mess/-dashed" 31.11 --json
_jd_t_status 'other system, no jdex: exit status' 0
_jd_t_eq 'other system: sys' P76 "$(_jd_t_json .sys)"
_jd_t_exists 'other system: a folder whose name starts with a dash moves' "$_jd_t_p31/-dashed"

# ---------------------------------------------------------- '--' and paths

# The flags go before '--'. After it, every word is a path or an ID.
mkdir "$_jd_t_mess/-flag"
_jd_t_run_from "$_jd_t_mess" jd move --json -- -flag 11.11
_jd_t_eq 'after --: a path that starts with a dash is a path' "$_jd_t_f11/-flag" "$(_jd_t_json .to)"

# ------------------------------------------------------------------ undo

# The journal so far, oldest first: the invoice, Photos, agent.txt to
# W0189, plain.txt to 12.99, -dashed to P76, -flag. The newest move not
# yet undone in D25 is -flag: the P76 move is in another system.
_jd_t_run jd undo move --dry-run
_jd_t_status 'undo dry run: exit status' 0
_jd_t_contains 'undo dry run: names the newest move in this system' "from    $_jd_t_f11/-flag" "$JD_T_ERR"
_jd_t_exists 'undo dry run: moves nothing' "$_jd_t_f11/-flag"
_jd_t_eq 'undo dry run: no journal line' 6 "$(_jd_t_lines)"

_jd_t_run_from "$_jd_t_mess" jd undo move
_jd_t_status 'undo: exit status' 0
_jd_t_eq 'undo: prints where it went back to' "$_jd_t_mess/-flag" "$JD_T_OUT"
_jd_t_at 'undo: the shell does not cd' "$_jd_t_mess"
_jd_t_exists 'undo: it is back' "$_jd_t_mess/-flag"
_jd_t_gone 'undo: it has left the ID' "$_jd_t_f11/-flag"
_jd_t_eq 'undo: one more journal line' 7 "$(_jd_t_lines)"
_jd_t_eq 'undo journal: from is where it was' "$_jd_t_f11/-flag" "$(_jd_t_jline 7 .from)"
_jd_t_eq 'undo journal: to is where it came from' "$_jd_t_mess/-flag" "$(_jd_t_jline 7 .to)"
_jd_t_eq 'undo journal: undoes names the original' "$(_jd_t_jline 6 .at)" "$(_jd_t_jline 7 .undoes)"
_jd_t_eq 'undo journal: id' 11.11 "$(_jd_t_jline 7 .id)"
_jd_t_eq 'undo journal: kind' folder "$(_jd_t_jline 7 .kind)"

# Undo again: the newest not-undone move in D25 is now plain.txt to 12.99.
_jd_t_run jd undo move --json
_jd_t_eq 'undo skips what is undone: id' 12.99 "$(_jd_t_json .id)"
_jd_t_exists 'undo skips what is undone: plain.txt is back' "$_jd_t_mess/plain.txt"

# By path: agent.txt in W0189, which is older than the moves above.
_jd_t_run jd undo move "$_jd_t_w189/agent.txt" --json
_jd_t_status 'undo by path: exit status' 0
_jd_t_eq 'undo by path: undoes that move' "$_jd_t_w189/agent.txt" "$(_jd_t_json .from)"
_jd_t_gone 'undo by path: it left the work package' "$_jd_t_w189/agent.txt"

# By path in the other system, with no --system.
_jd_t_run jd undo move "$_jd_t_p31/-dashed" --json
_jd_t_eq 'undo by path: finds a move in another system' P76 "$(_jd_t_json .sys)"
_jd_t_exists 'undo by path: it is back' "$_jd_t_mess/-dashed"

_jd_t_run jd undo move "$_jd_t_w189/agent.txt" --json
_jd_t_eq 'undo by path twice: code' nothing_to_undo "$(_jd_t_json .code)"

# What is left in D25: Photos and the invoice. Then nothing.
_jd_t_run jd undo move --json
_jd_t_eq 'undo: Photos' "$_jd_t_f11/Photos" "$(_jd_t_json .from)"
_jd_t_run jd undo move --json
_jd_t_eq 'undo: the invoice' "$_jd_t_f11/Invoice & co, 2026.pdf" "$(_jd_t_json .from)"
_jd_t_run jd undo move --json
_jd_t_status 'undo with nothing left: exit status' 1
_jd_t_eq 'undo with nothing left: code' nothing_to_undo "$(_jd_t_json .code)"
_jd_t_exists 'undo: everything is back in the mess' "$_jd_t_mess/Invoice & co, 2026.pdf"

# ------------------------------------------------------ undo refusals

_jd_t_mess_build
_jd_t_run jd move "$_jd_t_mess/plain.txt" 11.11 --json
mv "$_jd_t_f11/plain.txt" "$_jd_t_f11/renamed.txt"
_jd_t_run jd undo move --json
_jd_t_eq 'moved since: code' moved_since "$(_jd_t_json .code)"
_jd_t_eq 'moved since: path is where jd put it' "$_jd_t_f11/plain.txt" "$(_jd_t_json .path)"
mv "$_jd_t_f11/renamed.txt" "$_jd_t_f11/plain.txt"

printf 'other\n' >"$_jd_t_mess/plain.txt"
_jd_t_run jd undo move --json
_jd_t_eq 'source taken: code' source_exists "$(_jd_t_json .code)"
_jd_t_eq 'source taken: path is the taken source' "$_jd_t_mess/plain.txt" "$(_jd_t_json .path)"
_jd_t_exists 'source taken: the moved file stays put' "$_jd_t_f11/plain.txt"
rm "$_jd_t_mess/plain.txt"

_jd_t_run jd undo move --json
_jd_t_status 'undo after the way is clear: exit status' 0

# ------------------------------------------------------------- the journal

_jd_t_run jd move "$_jd_t_mess/Photos" 11.11 --json
_jd_t_status 'journal: a move to undo' 0
_jd_t_ln=$(_jd_t_lines)
_jd_t_run jd undo move --json
_jd_t_status 'journal: the undo' 0
_jd_t_eq 'the journal is append only: the undo adds a line' "$((_jd_t_ln + 1))" "$(_jd_t_lines)"
_jd_t_eq 'the journal is append only: the move it undid is still there' \
  "$_jd_t_f11/Photos" "$(_jd_t_jline "$_jd_t_ln" .to)"
if jq -c . "$_jd_t_journal" >/dev/null 2>&1; then
  _jd_t_ok 'the journal is one JSON object per line'
else
  _jd_t_bad 'the journal is one JSON object per line' 'valid JSON lines' "$(cat "$_jd_t_journal")"
fi

# A journal that cannot be written stops the move before it starts.
chmod 444 "$_jd_t_journal"
_jd_t_run jd move "$_jd_t_mess/Photos" 11.11 --json
chmod 644 "$_jd_t_journal"
if [ "$(id -u)" -eq 0 ]; then
  _jd_t_skipped 'journal not writable: code' 'root can write anything'
  _jd_t_skipped 'journal not writable: moves nothing' 'root can write anything'
else
  _jd_t_eq 'journal not writable: code' journal_not_writable "$(_jd_t_json .code)"
  _jd_t_exists 'journal not writable: moves nothing' "$_jd_t_mess/Photos"
fi

_jd_fx_reset
_jd_t_summary
