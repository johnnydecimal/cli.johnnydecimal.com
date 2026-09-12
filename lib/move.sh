# SPDX-License-Identifier: MIT
# move.sh - move a file or a folder into an ID, and undo a move
# Part of the Johnny.Decimal command line. Sourced by bin/jd, which sets
# $_JD_CLI_VERSION, $_JD_CLI_HELP_URL and $_JD_CLI_DIR.
#
# It defines _jd_move and _jd_undo, which nav.sh calls for 'jd move' and
# 'jd undo':
#
#   jd move <path> <id>        move the file or folder at <path> into
#                              the folder for <id>, an ID or a W number
#   jd undo move               undo the newest move not yet undone
#   jd undo move <path>        undo the move that put <path> where it is
#
# Every move is one line in the journal, ~/.jd/journal.jsonl, and so is
# every undo. The journal is append only. It is what answers 'where did
# that file go', and it is what makes undo possible. A move that cannot
# be journaled is not made.
#
# The CLI moves and journals. It decides nothing about where a file
# belongs, and it writes nothing into the JDex. An agent that files a
# mess reads the JSON result and writes the note itself.
#
# Needs jq. Works in bash 3.2+ and zsh.

_jd_move_usage() {
  cat <<'EOF'
usage: <system> move <path> <id>

  jd move ~/Downloads/invoice.pdf 21.34     into the folder for 21.34
  jd move ~/Desktop/Photos W0189            a folder moves whole

It moves the file or folder at <path> into the folder for <id>, and
prints the new path. <id> is an ID, like 21.34, or a W number, like
W0189. An ID that is in the JDex but has no folder gets its folder made.

It refuses, and moves nothing, when:

  - the target folder already holds something with that name. It never
    renames. Rename the file and try again
  - the file is an iCloud stub, a '.name.icloud' file that is not
    downloaded. Download it first. A Dropbox file that is online-only
    is not detected: jd moves the placeholder
  - the target folder is inside the thing you are moving

Every move is one line in ~/.jd/journal.jsonl: when, which system, the
ID, from, to, and whether a person or a program asked. 'jd undo move'
reads it. Nothing is written into the JDex.

      --dry-run       say what it would do, and move nothing
      --json          print one JSON object on stdout instead of the
                       usual lines. { "ok": true, ... } or, on error,
                       { "ok": false, "code": "...", ... }

This is a beta feature. 'jd beta on' turns beta on. JD_BETA=1 turns it
on for one shell.
EOF
}

_jd_undo_usage() {
  cat <<'EOF'
usage: <system> undo move [<path>]

  jd undo move                 undo the newest move in this system
                               that is not yet undone
  jd undo move ~/D25/.../invoice.pdf
                               undo the move that put that path where
                               it is, whichever system it is in

It reads ~/.jd/journal.jsonl, moves the file or folder back to where it
came from, and prints that path. The undo is one more line in the
journal. The journal is never edited.

It refuses, and moves nothing, when:

  - the moved thing is no longer where jd put it
  - something else is now where it came from

      --dry-run       say what it would do, and move nothing
      --json          print one JSON object on stdout instead of the
                       usual lines

This is a beta feature. 'jd beta on' turns beta on.
EOF
}

# ------------------------------------------------------------ small parts

_jd_move_journal() { printf '%s' "$HOME/.jd/journal.jsonl"; }

# Say what happened, on stderr, so that stdout stays the new path.
_jd_move_say() { printf '     %s\n' "$*" >&2; }

# Record an error's code and path for --json, then print it the normal
# way. $1 code, $2 path this error is about (may be empty), $3+ the
# message. Always returns 1, so a caller still needs its own 'return 1'.
_jd_move_fail() {
  _JD_MOVE_CODE=$1
  _JD_MOVE_PATH=$2
  shift 2
  _JD_MOVE_MSG=$*
  _jd_nav_err "$@"
}

# The absolute path of $1, with no trailing slash. The folder above it
# has to exist, or there is nothing to make absolute. Prints nothing and
# returns 1 if it does not.
_jd_move_abs() {
  local p=$1 d b
  case $p in
    */) p=${p%/} ;;
  esac
  d=$(dirname -- "$p")
  b=$(basename -- "$p")
  d=$(cd -- "$d" 2>/dev/null && pwd) || return 1
  case $d in
    /) printf '/%s' "$b" ;;
    *) printf '%s/%s' "$d" "$b" ;;
  esac
}

# Who asked. The shell hook sets JD_HOOK, and a person types into the
# shell. Anything else is a program: a script, cron, an agent.
_jd_move_by() {
  if [ -n "${JD_HOOK-}" ]; then printf 'person'; else printf 'program'; fi
}

_jd_move_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_jd_move_host() { uname -n 2>/dev/null; }

# The journal has to take a line before anything moves. Make its folder,
# then check the write. $1 the journal path.
_jd_move_journal_ready() {
  local j=$1 d
  d=$(dirname -- "$j")
  [ -d "$d" ] || mkdir -p -- "$d" 2>/dev/null
  if [ -e "$j" ]; then
    [ -f "$j" ] && [ -w "$j" ]
  else
    [ -d "$d" ] && [ -w "$d" ]
  fi
}

# One journal line, as JSON. $1 sys, $2 id, $3 kind, $4 from, $5 to,
# $6 by, $7 at, $8 host, $9 undoes (may be empty).
_jd_move_line() {
  jq -cn \
    --arg at "$7" --arg sys "$1" --arg id "$2" --arg kind "$3" \
    --arg from "$4" --arg to "$5" --arg by "$6" --arg host "$8" \
    --arg undoes "$9" \
    '{at: $at, sys: $sys, id: $id, kind: $kind, from: $from, to: $to,
      by: $by, host: $host}
     + (if $undoes == "" then {} else {undoes: $undoes} end)'
}

# Append $2 to the journal $1.
_jd_move_journal_append() {
  printf '%s\n' "$2" >>"$1"
}

# The folder for an ID or a W number in the filesystem, in
# $_JD_MOVE_FOLDER. $1 root, $2 jdex, $3 the ID. An ID in the JDex with
# no folder gets its folder made, as 'jd 21.34' does. It sets a variable
# and does not print, so that a caller need not run it in a subshell,
# where the error code would be lost. Returns 1 when there is no one
# folder.
_jd_move_folder() {
  local root=$1 jdex=$2 id=$3 m n
  _JD_MOVE_FOLDER=''
  case $id in
    [0-9][0-9].[0-9][0-9])
      m=$(_jd_nav_find "$root" 3 d -name "$id" -o -name "$id *")
      ;;
    [Ww][0-9][0-9][0-9][0-9])
      m=$(_jd_nav_find "$root" 2 d -iname "$id" -o -iname "$id *" -o -iname "$id~*")
      ;;
    *)
      _jd_move_fail not_an_id '' "'$id' is not an ID or a W number - say where to move it, like 21.34 or W0189"
      return 1
      ;;
  esac
  if [ -z "$m" ]; then
    m=$(_jd_nav_make_id "$root" "$jdex" "$id")
    case $? in
      1) _jd_move_fail no_match '' "no match for $id"; return 1 ;;
      2) _JD_MOVE_CODE=no_category; _JD_MOVE_MSG="the JDex has $id but there is no folder for its category"; return 1 ;;
    esac
  fi
  n=$(printf '%s' "$m" | grep -c '^')
  if [ "$n" -gt 1 ]; then
    {
      printf 'jd: %s matches for %s:\n' "$n" "$id"
      printf '%s\n' "$m" | while IFS= read -r p; do
        printf '%s\n' "${p#"$root"/}"
      done | _jd_nav_tree
    } >&2
    _JD_MOVE_CODE=ambiguous
    _JD_MOVE_PATH=$(printf '%s' "$m" | head -1)
    _JD_MOVE_MSG="$n matches for $id"
    return 1
  fi
  _JD_MOVE_FOLDER=$m
}

# --------------------------------------------------------------- --json

# The success object. $1 'true' or 'false' for dryRun. The rest is in
# $_JD_MOVE_*, set by the caller.
#
#   kind      "file" or "folder"
#   by        "person" from the shell, "program" from anything else
#   at        when the journal line was written. Empty in a dry run
#   journal   the journal file
#   undoes    for an undo, the 'at' of the move it undid
_jd_move_emit_ok() {
  jq -n \
    --arg sys "$_JD_MOVE_SYS" \
    --arg id "$_JD_MOVE_ID" \
    --arg kind "$_JD_MOVE_KIND" \
    --arg from "$_JD_MOVE_FROM" \
    --arg to "$_JD_MOVE_TO" \
    --arg by "$_JD_MOVE_BY" \
    --arg at "$_JD_MOVE_AT" \
    --arg journal "$_JD_MOVE_JOURNAL" \
    --arg undoes "$_JD_MOVE_UNDOES" \
    --argjson dryRun "$1" \
    '{ok: true, sys: $sys, id: $id, kind: $kind, from: $from, to: $to,
      by: $by, at: $at, dryRun: $dryRun, journal: $journal}
     + (if $undoes == "" then {} else {undoes: $undoes} end)'
}

# The error object, in the shape 'jd new' uses. 'code' is never empty:
# an agent branches on it.
_jd_move_emit_err() {
  local code=$_JD_MOVE_CODE message=$_JD_MOVE_MSG
  [ -n "$code" ] || code=unknown
  [ -n "$message" ] || message='see the message on stderr'
  jq -n \
    --arg code "$code" \
    --arg message "$message" \
    --arg path "$_JD_MOVE_PATH" \
    '{ok: false, code: $code, message: $message, path: $path}'
}

# ------------------------------------------------------------- the words

# Reset the state both commands share. $1 sys, $2 root, $3 jdex.
_jd_move_reset() {
  _JD_MOVE_SYS=$1
  _JD_MOVE_ROOT=$2
  _JD_MOVE_JDEX=$3
  _JD_MOVE_JSON=0
  _JD_MOVE_HELP=0
  _JD_MOVE_DRY=0
  _JD_MOVE_CODE=''
  _JD_MOVE_PATH=''
  _JD_MOVE_MSG=''
  _JD_MOVE_ID=''
  _JD_MOVE_KIND=''
  _JD_MOVE_FROM=''
  _JD_MOVE_TO=''
  _JD_MOVE_BY=''
  _JD_MOVE_AT=''
  _JD_MOVE_UNDOES=''
  _JD_MOVE_JOURNAL=$(_jd_move_journal)
  _JD_MOVE_FOLDER=''
  _JD_MOVE_W1=''
  _JD_MOVE_W2=''
  _JD_MOVE_NWORDS=0
}

# Read the flags, and up to two words, into $_JD_MOVE_W1 and
# $_JD_MOVE_W2. A flag can go anywhere. '--' ends the flags, so a path
# that starts with '-' can follow it. $@ the words.
_jd_move_words() {
  local end=0 w
  # --json first, so that a bad word still gets the JSON error it asked
  # for. Only up to '--': after that every word is a path or an ID.
  for w in "$@"; do
    case $w in
      --) break ;;
      --json) _JD_MOVE_JSON=1 ;;
    esac
  done
  while [ $# -gt 0 ]; do
    if [ "$end" -eq 0 ]; then
      case $1 in
        --) end=1; shift; continue ;;
        help | --help) _JD_MOVE_HELP=1; shift; continue ;;
        --dry-run) _JD_MOVE_DRY=1; shift; continue ;;
        --json) _JD_MOVE_JSON=1; shift; continue ;;
        -*) _jd_move_fail unknown_option '' "unknown option '$1'"; return 1 ;;
      esac
    fi
    _JD_MOVE_NWORDS=$((_JD_MOVE_NWORDS + 1))
    case $_JD_MOVE_NWORDS in
      1) _JD_MOVE_W1=$1 ;;
      2) _JD_MOVE_W2=$1 ;;
      *) _jd_move_fail unexpected_word '' "unexpected word '$1'"; return 1 ;;
    esac
    shift
  done
}

# The checks both commands make before anything else: jq, beta, the
# journal. $1 the name of the command, for the message.
_jd_move_gate() {
  command -v jq >/dev/null 2>&1 || { _jd_move_fail no_jq '' "jq is not installed"; return 1; }
  _jd_beta_on || {
    _jd_move_fail beta_off '' "'$1' is a beta feature - turn beta on with 'jd beta on'"
    _jd_beta_warn
    return 1
  }
  _jd_move_journal_ready "$_JD_MOVE_JOURNAL" || {
    _jd_move_fail journal_not_writable "$_JD_MOVE_JOURNAL" "cannot write the journal, so nothing moves: $_JD_MOVE_JOURNAL"
    return 1
  }
}

# Move $_JD_MOVE_FROM to $_JD_MOVE_TO, then journal it. The move comes
# first, so that the journal never claims a move that did not happen.
# If the journal then cannot take the line, the thing has moved and the
# line is printed on stderr, so it is not lost.
_jd_move_do() {
  local line
  mv -- "$_JD_MOVE_FROM" "$_JD_MOVE_TO" || {
    _jd_move_fail move_failed "$_JD_MOVE_FROM" "could not move $_JD_MOVE_FROM"
    return 1
  }
  _JD_MOVE_AT=$(_jd_move_now)
  line=$(_jd_move_line "$_JD_MOVE_SYS" "$_JD_MOVE_ID" "$_JD_MOVE_KIND" \
    "$_JD_MOVE_FROM" "$_JD_MOVE_TO" "$_JD_MOVE_BY" "$_JD_MOVE_AT" \
    "$(_jd_move_host)" "$_JD_MOVE_UNDOES")
  _jd_move_journal_append "$_JD_MOVE_JOURNAL" "$line" || {
    _jd_move_fail journal_failed "$_JD_MOVE_TO" \
      "moved, but could not write the journal. The line was: $line"
    return 1
  }
}

# ------------------------------------------------------------------ move

# _jd_move is the entry point nav.sh calls for 'jd move'. $1 the sys id,
# $2 the root, $3 the jdex (may be empty), then the user's words.
_jd_move() {
  _jd_move_reset "$1" "$2" "$3"
  shift 3
  _jd_move_inner "$@"
  _JD_MOVE_STATUS=$?
  if [ "$_JD_MOVE_JSON" -eq 1 ] && [ "$_JD_MOVE_STATUS" -ne 0 ]; then
    _jd_move_emit_err
  fi
  return "$_JD_MOVE_STATUS"
}

_jd_move_inner() {
  local src id folder name

  _jd_move_words "$@" || return 1
  if [ "$_JD_MOVE_HELP" -eq 1 ]; then
    _jd_move_usage
    return 0
  fi
  _jd_move_gate 'jd move' || return 1

  src=$_JD_MOVE_W1
  id=$_JD_MOVE_W2
  [ -n "$src" ] || { _jd_move_usage >&2; _jd_move_fail no_path '' "say what to move, and where: jd move <path> <id>"; return 1; }
  [ -n "$id" ] || { _jd_move_fail no_id '' "say where to move it: jd move <path> <id>"; return 1; }

  # The source. A stub is refused before anything is looked up.
  name=$(basename -- "${src%/}")
  case $name in
    .*.icloud)
      _jd_move_fail not_downloaded "$src" "$name is an iCloud stub that is not downloaded - download it first"
      return 1
      ;;
  esac
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    _jd_move_fail no_source "$src" "nothing at $src"
    return 1
  fi
  _JD_MOVE_FROM=$(_jd_move_abs "$src") || {
    _jd_move_fail no_source "$src" "nothing at $src"
    return 1
  }
  if [ -d "$_JD_MOVE_FROM" ] && [ ! -L "$_JD_MOVE_FROM" ]; then
    _JD_MOVE_KIND=folder
  else
    _JD_MOVE_KIND=file
  fi

  # The target folder.
  _jd_move_folder "$_JD_MOVE_ROOT" "$_JD_MOVE_JDEX" "$id" || return 1
  folder=$_JD_MOVE_FOLDER
  _JD_MOVE_ID=$(basename -- "$folder")
  _JD_MOVE_ID=${_JD_MOVE_ID%% *}
  case $_JD_MOVE_ID in
    *~*) _JD_MOVE_ID=${_JD_MOVE_ID%%~*} ;;
  esac
  _JD_MOVE_TO="$folder/$name"

  # A folder cannot go inside itself, and a thing that is already there
  # has nowhere to go.
  case "$folder/" in
    "$_JD_MOVE_FROM"/*)
      _jd_move_fail nested "$folder" "the folder for $id is inside $_JD_MOVE_FROM, so it cannot move there"
      return 1
      ;;
  esac
  if [ "$_JD_MOVE_FROM" = "$_JD_MOVE_TO" ]; then
    _jd_move_fail exists "$_JD_MOVE_TO" "$name is already in $folder"
    return 1
  fi
  if [ -e "$_JD_MOVE_TO" ] || [ -L "$_JD_MOVE_TO" ]; then
    _jd_move_fail exists "$_JD_MOVE_TO" "$folder already has $name - rename one of them and try again"
    return 1
  fi

  _JD_MOVE_BY=$(_jd_move_by)
  printf 'jd: move %s\n' "$name" >&2
  _jd_move_say "from    $_JD_MOVE_FROM"
  _jd_move_say "to      $_JD_MOVE_TO"

  if [ "$_JD_MOVE_DRY" -eq 1 ]; then
    _jd_move_say 'nothing was moved'
    [ "$_JD_MOVE_JSON" -eq 1 ] && _jd_move_emit_ok true
    return 0
  fi

  _jd_move_do || return 1

  if [ "$_JD_MOVE_JSON" -eq 1 ]; then
    _jd_move_emit_ok false
    return 0
  fi
  printf '%s\n' "$_JD_MOVE_TO"
}

# ------------------------------------------------------------------ undo

# _jd_undo is the entry point nav.sh calls for 'jd undo'. The word after
# 'undo' is the noun, and 'move' is the only one. $1 the sys id, $2 the
# root, $3 the jdex, then the user's words.
_jd_undo() {
  _jd_move_reset "$1" "$2" "$3"
  shift 3
  _jd_undo_inner "$@"
  _JD_MOVE_STATUS=$?
  if [ "$_JD_MOVE_JSON" -eq 1 ] && [ "$_JD_MOVE_STATUS" -ne 0 ]; then
    _jd_move_emit_err
  fi
  return "$_JD_MOVE_STATUS"
}

# The journal entry to undo, as one JSON object, or nothing. $1 the
# journal, $2 the sys, $3 the path, or empty for the newest move in the
# system.
#
# A move is undone when a later line has 'undoes' set to its 'at' and
# comes from where it went to. An undo line is never a candidate: undo
# of an undo is a new move, not a thing this does.
_jd_undo_find() {
  jq -cs --arg sys "$2" --arg path "$3" '
    . as $all
    | def undone: . as $o
        | any($all[]; (.undoes // "") == $o.at and .from == $o.to);
    map(select((.undoes // "") == ""))
    | map(select(if $path == "" then .sys == $sys else .to == $path end))
    | map(select(undone | not))
    | last // empty
  ' "$1" 2>/dev/null
}

_jd_undo_inner() {
  local noun path entry name from_dir

  _jd_move_words "$@" || return 1
  noun=$_JD_MOVE_W1
  path=$_JD_MOVE_W2
  if [ "$_JD_MOVE_HELP" -eq 1 ]; then
    _jd_undo_usage
    return 0
  fi
  case $noun in
    move) ;;
    '')
      _jd_undo_usage >&2
      _jd_move_fail no_noun '' "say what to undo: 'jd undo move'"
      return 1
      ;;
    *)
      _jd_move_fail unknown_noun '' "cannot undo '$noun' - 'jd undo move' is the only undo"
      return 1
      ;;
  esac
  _jd_move_gate 'jd undo move' || return 1

  if [ -n "$path" ]; then
    path=$(_jd_move_abs "$path") || {
      _jd_move_fail no_source "$_JD_MOVE_W2" "nothing at $_JD_MOVE_W2"
      return 1
    }
  fi
  if [ ! -f "$_JD_MOVE_JOURNAL" ]; then
    _jd_move_fail nothing_to_undo "$_JD_MOVE_JOURNAL" "there is no journal yet, so there is no move to undo"
    return 1
  fi
  entry=$(_jd_undo_find "$_JD_MOVE_JOURNAL" "$_JD_MOVE_SYS" "$path")
  if [ $? -ne 0 ] && [ -z "$entry" ]; then
    _jd_move_fail journal_unreadable "$_JD_MOVE_JOURNAL" "the journal is not one JSON object per line: $_JD_MOVE_JOURNAL"
    return 1
  fi
  if [ -z "$entry" ]; then
    if [ -n "$path" ]; then
      _jd_move_fail nothing_to_undo "$path" "the journal has no move to $path that is not undone"
    else
      _jd_move_fail nothing_to_undo "$_JD_MOVE_JOURNAL" "the journal has no move in $_JD_MOVE_SYS that is not undone"
    fi
    return 1
  fi

  # The undo is a move the other way. Its sys and id are the original's.
  _JD_MOVE_SYS=$(printf '%s' "$entry" | jq -r '.sys')
  _JD_MOVE_ID=$(printf '%s' "$entry" | jq -r '.id')
  _JD_MOVE_KIND=$(printf '%s' "$entry" | jq -r '.kind')
  _JD_MOVE_FROM=$(printf '%s' "$entry" | jq -r '.to')
  _JD_MOVE_TO=$(printf '%s' "$entry" | jq -r '.from')
  _JD_MOVE_UNDOES=$(printf '%s' "$entry" | jq -r '.at')
  name=$(basename -- "$_JD_MOVE_FROM")

  if [ ! -e "$_JD_MOVE_FROM" ] && [ ! -L "$_JD_MOVE_FROM" ]; then
    _jd_move_fail moved_since "$_JD_MOVE_FROM" "$name is no longer at $_JD_MOVE_FROM, so jd cannot move it back"
    return 1
  fi
  if [ -e "$_JD_MOVE_TO" ] || [ -L "$_JD_MOVE_TO" ]; then
    _jd_move_fail source_exists "$_JD_MOVE_TO" "something else is now at $_JD_MOVE_TO, so $name cannot go back"
    return 1
  fi
  from_dir=$(dirname -- "$_JD_MOVE_TO")
  [ -d "$from_dir" ] || {
    _jd_move_fail source_exists "$from_dir" "the folder $name came from is gone: $from_dir"
    return 1
  }

  _JD_MOVE_BY=$(_jd_move_by)
  printf 'jd: undo move %s\n' "$name" >&2
  _jd_move_say "from    $_JD_MOVE_FROM"
  _jd_move_say "to      $_JD_MOVE_TO"

  if [ "$_JD_MOVE_DRY" -eq 1 ]; then
    _jd_move_say 'nothing was moved'
    [ "$_JD_MOVE_JSON" -eq 1 ] && _jd_move_emit_ok true
    return 0
  fi

  _jd_move_do || return 1

  if [ "$_JD_MOVE_JSON" -eq 1 ]; then
    _jd_move_emit_ok false
    return 0
  fi
  printf '%s\n' "$_JD_MOVE_TO"
}
