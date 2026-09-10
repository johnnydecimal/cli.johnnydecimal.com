# SPDX-License-Identifier: MIT
# new.sh - make a new work package
# Part of the Johnny.Decimal command line. Loaded by jd.sh, which sets
# $_JD_CLI_VERSION, $_JD_CLI_HELP_URL and $_JD_CLI_DIR.
#
# It defines _jd_new, which nav.sh calls for 'jd new'. One command makes
# every part of a work package:
#
#   - the next free W number
#   - the JDex note, from a template note
#   - the project in a task app, from a template project
#   - the links, each side pointing at the other
#   - the folder, from a template folder
#
# The task app and the note app are adapters, in lib/adapters. The core
# never names an app. Refer to lib/adapters/README.md.
#
# --json and --peek are the machine interface, for an agent that drives
# this command. --json is behind a flag, so the human output does not
# change. Refer to lib/new.sh's own comments below for the shape.
#
# Needs jq. Works in bash 3.2+ and zsh.

_jd_new_usage() {
  cat <<'EOF'
usage: <system> new <ID> <title>

  jd new 21.41 Video about work packages

It makes, in this order:

  - the next free W number, from the JDex and the filesystem
  - the project in your task app, from the template project
  - the JDex note, from the template note
  - the folder, from the template folder

The title needs no quotes. Everything after the ID is the title.

  -n, --dry-run       say what it would make, and make nothing
      --no-tasks      skip the task app
      --refresh       read the template project out of the task app
                      and write it to the template file
      --json          print one JSON object on stdout instead of the
                       usual lines. { "ok": true, ... } or, on error,
                       { "ok": false, "code": "...", ... }
      --peek          print the next free W number, and make nothing.
                       needs no ID and no title

This is a beta feature. 'jd beta on' turns beta on. JD_BETA=1 turns it
on for one shell.

The system's 'workPackages' block in the config says which templates and
which adapters to use.

A template note can hold a token jd does not fill in, such as
'{{?SCOPE}}' or '{{?DELIVERABLE What we hand over}}'. jd new leaves it
in the note as written, and names it: in 'toFill' with --json, or on
stderr otherwise. It is for whoever writes the note next, human or
agent, not for jd.
EOF
}

# ------------------------------------------------------------ small parts

# URL-encode $1.
_jd_new_uri() { jq -rn --arg s "$1" '$s | @uri'; }

# Escape $1 for the inside of a JSON string, with no quotes around it.
_jd_new_jstr() { jq -rn --arg s "$1" '$s | @json | .[1:-1]'; }

# An absolute path stays as it is. A relative one hangs off $1.
# $1 base, $2 path
_jd_new_path() {
  case $2 in
    /*) printf '%s' "$2" ;;
    *) printf '%s/%s' "$1" "$2" ;;
  esac
}

# One value out of the system's config entry. $1 jq expression.
_jd_new_cfg() {
  jq -r --arg s "$_JD_NEW_SYS" "($_JD_NEW_SEL) | ($1) // \"\"" \
    "$_JD_NEW_CFG" 2>/dev/null
}

# Load an adapter. $1 kind: tasks or notes. $2 name.
_jd_new_adapter() {
  local f
  f="$_JD_CLI_DIR/lib/adapters/$1/$2.sh"
  [ -f "$f" ] || {
    _jd_new_fail no_adapter "$f" "no $1 adapter named '$2' - see $_JD_CLI_DIR/lib/adapters"
    return 1
  }
  . "$f"
}

# Say what happened, on stderr, so that stdout stays the new path.
_jd_new_say() { printf '     %s\n' "$*" >&2; }

# Record an error's code and path for --json, then print it the normal
# way. $1 code, from the table in the README, $2 path this error is
# about (may be empty), $3+ the message. Always returns 1, the same as
# _jd_nav_err, so a caller still needs its own 'return 1' to leave the
# function it is in.
_jd_new_fail() {
  _JD_NEW_CODE=$1
  _JD_NEW_PATH=$2
  shift 2
  _JD_NEW_MSG=$*
  _jd_nav_err "$@"
}

# The {{?TOKEN}} and {{?TOKEN brief}} tokens in $1, one per line as
# 'TOKEN<tab>brief', in the order they first appear. A repeated token is
# printed once. TOKEN is [A-Z][A-Z0-9_]*. Everything after the first
# space, up to the closing braces, is the brief; no brief gives ''.
#
# _jd_new_fill never touches these. They match none of its known
# placeholders, so they reach the note exactly as they were written.
_jd_new_tokens() {
  local text=$1 line rest tok brief seen=' '
  printf '%s\n' "$text" | grep -Eo '\{\{\?[A-Z][A-Z0-9_]*([^}]*)?\}\}' 2>/dev/null |
  while IFS= read -r line; do
    rest=${line#'{{?'}
    rest=${rest%'}}'}
    case $rest in
      *' '*) tok=${rest%% *}; brief=${rest#* } ;;
      *) tok=$rest; brief='' ;;
    esac
    case $seen in
      *" $tok "*) continue ;;
    esac
    seen="$seen$tok "
    printf '%s\t%s\n' "$tok" "$brief"
  done
}

# Put the values into a template. $1 the text. $2 'json' to escape them
# for the inside of a JSON file. Anything else leaves them as they are.
#
#   {{W}}          W0216            {{ID}}         21.41
#   {{w}}          w0216            {{TITLE}}      Video about ...
#   {{NAME}}       W0216~21.41 Video about ...
#   {{NOTES_URL}}  the note app's link to this work package
#   {{TASKS_URL}}  the task app's link to it, empty until it exists
_jd_new_fill() {
  local t=$1 mode=${2-plain} up lo id ti nm nu tu
  up=$_JD_NEW_NUM
  lo=$(printf '%s' "$up" | tr 'A-Z' 'a-z')
  id=$_JD_NEW_ID
  ti=$_JD_NEW_TITLE
  nm=$_JD_NEW_NAME
  nu=$_JD_NEW_NOTES_URL
  tu=$_JD_NEW_TASKS_URL
  if [ "$mode" = json ]; then
    up=$(_jd_new_jstr "$up")
    lo=$(_jd_new_jstr "$lo")
    id=$(_jd_new_jstr "$id")
    ti=$(_jd_new_jstr "$ti")
    nm=$(_jd_new_jstr "$nm")
    nu=$(_jd_new_jstr "$nu")
    tu=$(_jd_new_jstr "$tu")
  fi
  t=${t//"{{NAME}}"/$nm}
  t=${t//"{{TITLE}}"/$ti}
  t=${t//"{{NOTES_URL}}"/$nu}
  t=${t//"{{TASKS_URL}}"/$tu}
  t=${t//"{{ID}}"/$id}
  t=${t//"{{W}}"/$up}
  t=${t//"{{w}}"/$lo}
  printf '%s' "$t"
}

# The note to write when the config names no template note.
_jd_new_default_note() {
  cat <<'EOF'
- Permalink:
	- ^{{w}}
- Related:
	- [Notes]({{NOTES_URL}})
	- [Tasks]({{TASKS_URL}})

---

## Scope

## Work log

## Notes
EOF
}

# The highest W number in either tree, plus one. $1 JDex area, $2 folder
# area. It reads both trees all the way down, because an archive folder
# holds work packages too, and their numbers are still used.
_jd_new_next_number() {
  local max n
  max=$(
    {
      find "$1" -iname 'w[0-9][0-9][0-9][0-9]*' 2>/dev/null
      find "$2" -iname 'w[0-9][0-9][0-9][0-9]*' 2>/dev/null
    } | sed 's|.*/||' | sed -n 's/^[Ww]\([0-9][0-9][0-9][0-9]\).*/\1/p' \
      | sort -n | tail -1
  )
  n=$(printf '%s' "$max" | sed 's/^0*//')
  [ -n "$n" ] || n=0
  n=$((n + 1))
  if [ "$n" -gt 9999 ]; then
    _jd_new_fail numbers_exhausted '' "the last work package number is W9999"
    return 1
  fi
  printf 'W%04d' "$n"
}

# --------------------------------------------------------------- --json

# The success object. $1 'true' or 'false' for dryRun, $2 note path,
# $3 folder path. Reads the rest from $_JD_NEW_*, set by the caller.
_jd_new_emit_ok() {
  jq -n \
    --arg sys "$_JD_NEW_SYS" \
    --arg num "$_JD_NEW_NUM" \
    --arg id "$_JD_NEW_ID" \
    --arg title "$_JD_NEW_TITLE" \
    --arg name "$_JD_NEW_NAME" \
    --arg note "$2" \
    --arg folder "$3" \
    --arg notesUrl "$_JD_NEW_NOTES_URL" \
    --arg tasksUrl "$_JD_NEW_TASKS_URL" \
    --argjson toFill "$_JD_NEW_TOFILL_JSON" \
    --argjson warnings "$_JD_NEW_WARNINGS_JSON" \
    --argjson dryRun "$1" \
    '{ok: true, sys: $sys, num: $num, id: $id, title: $title, name: $name,
      note: $note, folder: $folder, notesUrl: $notesUrl, tasksUrl: $tasksUrl,
      toFill: $toFill, warnings: $warnings, dryRun: $dryRun}'
}

# The error object. Reads $_JD_NEW_CODE, $_JD_NEW_PATH, $_JD_NEW_MSG,
# which _jd_new_fail sets as it prints the human error.
#
# Some failures come from an adapter, which prints its own message and
# knows no code. The call site in _jd_new_inner sets the code for those,
# and the message stays empty. Both fall back here, so that 'code' is
# never empty: an agent branches on it, and an empty string tells it
# nothing.
_jd_new_emit_err() {
  local code=$_JD_NEW_CODE message=$_JD_NEW_MSG
  [ -n "$code" ] || code=unknown
  [ -n "$message" ] || message='see the message on stderr'
  jq -n \
    --arg code "$code" \
    --arg message "$message" \
    --arg path "$_JD_NEW_PATH" \
    '{ok: false, code: $code, message: $message, path: $path}'
}

# ---------------------------------------------------------- the command

# _jd_new is the entry point nav.sh calls. It resets the --json state,
# runs _jd_new_inner, and, only in --json mode, turns a failure into the
# error object on stdout. A success prints its own object, from inside
# _jd_new_inner, because what it holds depends on --peek and -n.
#
# $1 the sys id, or '#N' for the system at index N. Then the user's words.
_jd_new() {
  _JD_NEW_JSON=0
  _JD_NEW_PEEK=0
  _JD_NEW_CODE=''
  _JD_NEW_PATH=''
  _JD_NEW_MSG=''
  _JD_NEW_WARNINGS_JSON='[]'
  _JD_NEW_TOFILL_JSON='[]'
  _jd_new_inner "$@"
  _JD_NEW_STATUS=$?
  if [ "$_JD_NEW_JSON" -eq 1 ] && [ "$_JD_NEW_STATUS" -ne 0 ]; then
    _jd_new_emit_err
  fi
  return "$_JD_NEW_STATUS"
}

_jd_new_inner() {
  local dry=0 use_tasks=1 refresh=0
  local root jdex jw fw note_tpl folder_tpl notes_ad tasks_ad
  local note_path dir text tpl_path ep tofill_names

  _JD_NEW_SYS=$1
  shift
  case $_JD_NEW_SYS in
    '#'*) _JD_NEW_SEL=".systems[${_JD_NEW_SYS#'#'}]" ;;
    *) _JD_NEW_SEL='.systems[] | select(.sys == $s)' ;;
  esac
  _JD_NEW_CFG=$(_jd_nav_config)

  while [ $# -gt 0 ]; do
    case $1 in
      -h|--help|help) _jd_new_usage; return 0 ;;
      -n|--dry-run) dry=1 ;;
      --no-tasks) use_tasks=0 ;;
      --refresh) refresh=1 ;;
      --json) _JD_NEW_JSON=1 ;;
      --peek) _JD_NEW_PEEK=1 ;;
      --) shift; break ;;
      -*) _jd_new_fail unknown_option '' "unknown option '$1'"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  command -v jq >/dev/null 2>&1 || { _jd_new_fail no_jq '' "jq is not installed"; return 1; }
  [ -f "$_JD_NEW_CFG" ] || {
    _jd_new_fail no_config "$_JD_NEW_CFG" "no config at $_JD_NEW_CFG - see $_JD_CLI_HELP_URL"
    return 1
  }

  # 'jd new' is a beta feature, gated by the one flag in lib/beta.sh.
  # --help still works with beta off, because the flags are read above.
  _jd_beta_on || {
    _jd_new_fail beta_off "$_JD_NEW_CFG" "'jd new' is a beta feature - turn beta on with 'jd beta on'"
    _jd_beta_warn
    return 1
  }

  root=$(_jd_new_cfg '.root')
  jdex=$(_jd_new_cfg '.jdex')
  [ -n "$root" ] || { _jd_new_fail unknown_system '' "system '$_JD_NEW_SYS' is not in $_JD_NEW_CFG"; return 1; }
  [ -d "$root" ] || { _jd_new_fail no_root "$root" "folder does not exist: $root"; return 1; }
  [ -n "$jdex" ] || {
    _jd_new_fail no_jdex_path '' "'jd new' needs a jdex path for $_JD_NEW_SYS in $_JD_NEW_CFG"
    return 1
  }
  [ -d "$jdex" ] || { _jd_new_fail no_jdex "$jdex" "folder does not exist: $jdex"; return 1; }

  # Both work package areas, found by the start of the number, the same
  # way nav.sh finds them.
  jw=$(_jd_nav_find "$jdex" 1 d -iname 'W0000*')
  fw=$(_jd_nav_find "$root" 1 d -iname 'W0000*')
  if [ "$(printf '%s' "$jw" | grep -c '^')" -ne 1 ]; then
    _jd_new_fail no_wp_area_jdex "$jdex" "the JDex has no one folder named W0000... at the top: $jdex"
    return 1
  fi
  if [ "$(printf '%s' "$fw" | grep -c '^')" -ne 1 ]; then
    _jd_new_fail no_wp_area_root "$root" "the system has no one folder named W0000... at the top: $root"
    return 1
  fi

  # --peek needs no ID and no title, and loads no adapter, so it works
  # even when the task app is not running. It runs here: after the
  # config, the root, the JDex and both W0000 areas are known good, and
  # before anything below reads the ID or the title.
  if [ "$_JD_NEW_PEEK" -eq 1 ]; then
    _JD_NEW_NUM=$(_jd_new_next_number "$jw" "$fw") || return 1
    if [ "$_JD_NEW_JSON" -eq 1 ]; then
      jq -n --arg num "$_JD_NEW_NUM" --arg jdexArea "$jw" --arg folderArea "$fw" \
        '{ok: true, num: $num, jdexArea: $jdexArea, folderArea: $folderArea}'
    else
      printf '%s\n' "$_JD_NEW_NUM"
    fi
    return 0
  fi

  _JD_NEW_TASKS_TPL=$(_jd_new_cfg '.workPackages.tasks.template')
  [ -n "$_JD_NEW_TASKS_TPL" ] && \
    _JD_NEW_TASKS_TPL=$(_jd_new_path "$fw" "$_JD_NEW_TASKS_TPL")
  _JD_NEW_TASKS_SOURCE=$(_jd_new_cfg '.workPackages.tasks.source')
  _JD_NEW_NOTES_VAULT=$(_jd_new_cfg '.workPackages.notes.vault')
  _JD_NEW_JDEX=$jdex

  note_tpl=$(_jd_new_cfg '.workPackages.noteTemplate')
  folder_tpl=$(_jd_new_cfg '.workPackages.folderTemplate')
  notes_ad=$(_jd_new_cfg '.workPackages.notes.adapter')
  tasks_ad=$(_jd_new_cfg '.workPackages.tasks.adapter')
  [ -n "$notes_ad" ] || notes_ad=none
  [ -n "$tasks_ad" ] || tasks_ad=none
  [ "$use_tasks" -eq 1 ] || tasks_ad=none

  # --refresh reads the template project out of the task app. It makes
  # no work package, so it happens before the ID and title are read.
  if [ "$refresh" -eq 1 ]; then
    _jd_new_adapter tasks "$tasks_ad" || return 1
    jd_tasks_check || { _JD_NEW_CODE=tasks_check_failed; return 1; }
    jd_tasks_refresh || { _JD_NEW_CODE=refresh_failed; return 1; }
    return 0
  fi

  # The ID, then everything else as the title. '$*' joins the words with
  # a space, so the title needs no quotes.
  [ $# -gt 0 ] || { _jd_new_usage >&2; _JD_NEW_CODE=no_id; return 1; }
  _JD_NEW_ID=$1
  shift
  case $_JD_NEW_ID in
    [0-9][0-9].[0-9][0-9]) ;;
    *) _jd_new_fail not_an_id '' "'$_JD_NEW_ID' is not an ID - the first word must be one, like 21.41"; return 1 ;;
  esac
  _JD_NEW_TITLE=$*
  case $_JD_NEW_TITLE in
    '') _jd_new_fail no_title '' "a work package needs a title"; return 1 ;;
    */*) _jd_new_fail title_has_slash '' "a title cannot hold '/'"; return 1 ;;
  esac

  _JD_NEW_NUM=$(_jd_new_next_number "$jw" "$fw") || return 1
  _JD_NEW_NAME="$_JD_NEW_NUM~$_JD_NEW_ID $_JD_NEW_TITLE"
  note_path="$jw/$_JD_NEW_NAME.md"
  dir="$fw/$_JD_NEW_NAME"
  if [ -e "$note_path" ] || [ -e "$dir" ]; then
    ep=$dir
    [ -e "$dir" ] || ep=$note_path
    _jd_new_fail exists "$ep" "$_JD_NEW_NAME already exists"
    return 1
  fi

  # The templates, read now, so that a missing one stops the command
  # before it makes anything.
  if [ -n "$note_tpl" ]; then
    tpl_path=$(_jd_new_path "$jw" "$note_tpl")
    [ -f "$tpl_path" ] || { _jd_new_fail no_note_template "$tpl_path" "no template note at $tpl_path"; return 1; }
    text=$(cat "$tpl_path")
  else
    text=$(_jd_new_default_note)
  fi
  if [ -n "$folder_tpl" ]; then
    folder_tpl=$(_jd_new_path "$fw" "$folder_tpl")
    [ -d "$folder_tpl" ] || { _jd_new_fail no_folder_template "$folder_tpl" "no template folder at $folder_tpl"; return 1; }
  fi

  # The '{{?TOKEN}}' tokens the note template asks the user, or their
  # agent, to fill in. jd never fills these in; it only carries them
  # through and names them.
  _JD_NEW_TOFILL_JSON=$(_jd_new_tokens "$text" | jq -R -s '
    split("\n") | map(select(length > 0)) | map(split("\t")) |
    map({token: .[0], brief: (.[1] // "")})
  ')
  tofill_names=$(printf '%s' "$_JD_NEW_TOFILL_JSON" | jq -r 'map(.token) | join(", ")')

  _jd_new_adapter notes "$notes_ad" || return 1
  _jd_new_adapter tasks "$tasks_ad" || return 1
  jd_notes_check || { _JD_NEW_CODE=notes_check_failed; return 1; }
  jd_tasks_check || { _JD_NEW_CODE=tasks_check_failed; return 1; }

  _JD_NEW_NOTES_URL=$(jd_notes_url) || { _JD_NEW_CODE=notes_url_failed; return 1; }
  _JD_NEW_TASKS_URL=''

  if [ "$dry" -eq 1 ]; then
    printf 'jd: %s\n' "$_JD_NEW_NAME" >&2
    _jd_new_say "note    $note_path"
    [ -n "$tofill_names" ] && _jd_new_say "to fill  $tofill_names"
    _jd_new_say "folder  $dir"
    [ -n "$folder_tpl" ] && _jd_new_say "from    $folder_tpl"
    _jd_new_say "notes   $notes_ad, $_JD_NEW_NOTES_URL"
    _jd_new_say "tasks   $tasks_ad"
    _jd_new_say 'nothing was made'
    [ "$_JD_NEW_JSON" -eq 1 ] && _jd_new_emit_ok true "$note_path" "$dir"
    return 0
  fi

  printf 'jd: %s\n' "$_JD_NEW_NAME" >&2

  # The task app first. It is the only step that talks to another
  # program, so it is the only one that fails in a way this cannot
  # predict. Nothing is written to disk until it is done. It prints its
  # own message on failure, so this only records the code.
  if [ "$tasks_ad" != none ]; then
    _JD_NEW_TASKS_URL=$(jd_tasks_create "$_JD_NEW_NAME") || {
      _JD_NEW_CODE=tasks_failed
      _JD_NEW_PATH=''
      _JD_NEW_MSG='the task app failed to make the work package'
      return 1
    }
    _jd_new_say "tasks   $_JD_NEW_TASKS_URL"
  fi

  # The JDex note, with both links in it.
  _jd_new_fill "$text" >"$note_path" || {
    _jd_new_fail write_failed "$note_path" "could not write $note_path"
    return 1
  }
  printf '\n' >>"$note_path"
  _jd_new_say "note    $note_path"
  [ -n "$tofill_names" ] && _jd_new_say "to fill  $tofill_names"

  # The folder, and the template folders inside it.
  mkdir -- "$dir" || { _jd_new_fail mkdir_failed "$dir" "could not make $dir"; return 1; }
  if [ -n "$folder_tpl" ]; then
    cp -R -- "$folder_tpl/." "$dir/" || {
      _jd_new_fail copy_failed "$folder_tpl" "could not copy $folder_tpl"
      return 1
    }
    find "$dir" -name '.DS_Store' -exec rm -f -- {} + 2>/dev/null
  fi
  _jd_new_say "folder  $dir"

  # The task app's own note, now that both links exist. The task app
  # holds the same '- Related:' block as the JDex note. This is a
  # warning, not an error: the work package exists, so 'ok' stays true.
  if [ "$tasks_ad" != none ]; then
    jd_tasks_link "$_JD_NEW_TASKS_URL" || {
      _JD_NEW_WARNINGS_JSON='["tasks_link_failed"]'
      _jd_nav_err "the work package is made, but the task app did not take the links"
    }
  fi

  cd -- "$dir" || return 1
  if [ "$_JD_NEW_JSON" -eq 1 ]; then
    _jd_new_emit_ok false "$note_path" "$dir"
  else
    pwd
  fi
}
