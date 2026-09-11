# SPDX-License-Identifier: MIT
# new.sh - make a new ID or work package
# Part of the Johnny.Decimal command line. Loaded by jd.sh, which sets
# $_JD_CLI_VERSION, $_JD_CLI_HELP_URL and $_JD_CLI_DIR.
#
# It defines _jd_new, which nav.sh calls for 'jd new'. The word after
# 'new' is the noun. It says what to make, and it is never left out:
#
#   jd new id 21 A title       the next free ID in category 21
#   jd new id 21.34 A title    exactly ID 21.34
#   jd new wp 21.34 A title    a work package for ID 21.34
#
# An ID is a JDex note and a folder. A work package is those two, a W
# number, and a project in a task app, with links from each to the
# others.
#
# Templates live in the filesystem, and are found by number. No config
# names them.
#
#   ID template.md                  21.03, then 20.03, then 00.03
#   Work package template.md        W0003
#   Work package template/          W0003. Its contents are copied in
#   Work package template.<adapter>.json
#                                   W0003. The task app's project
#
# With no template note, the note is blank, and jd says so. With no
# template folder, the folder is empty.
#
# The task app and the note app are adapters, in lib/adapters. The core
# never names an app. Refer to lib/adapters/README.md.
#
# --json, with --dry-run, is the machine interface, for an agent that drives
# this command. Refer to the comments above _jd_new_emit_ok for the
# shape.
#
# Needs jq. Works in bash 3.2+ and zsh.

# The fixed names of the templates.
_JD_NEW_ID_TPL='ID template.md'
_JD_NEW_WP_TPL='Work package template'

_jd_new_usage() {
  cat <<'EOF'
usage: <system> new <noun> ...

  jd new id 21 A title          make the next free ID in category 21
  jd new id 21.34 A title       make ID 21.34
  jd new wp 21.34 A title       make a work package for ID 21.34

'jd new id --help' and 'jd new wp --help' say more.

This is a beta feature. 'jd beta on' turns beta on. JD_BETA=1 turns it
on for one shell.
EOF
}

_jd_new_usage_id() {
  cat <<'EOF'
usage: <system> new id <category or ID> <title>

  jd new id 21 A title          the next free ID in category 21
  jd new id 21.34 A title       exactly ID 21.34, if it is not used

It makes:

  - the JDex note, from the ID template
  - the folder

The next free ID is one more than the highest ID in the category in
the JDex. It counts the entries directly in the category, and directly
in its archive, the .09 ID. A folder with no JDex entry is not an ID, so
it is not counted. The ID is never lower than .11. A gap is not filled.

If the filesystem already has a folder with the new ID's number, jd
stops, and names the folder.

The ID template is the first 'ID template.md' that jd finds in the
filesystem, in the templates ID of the category, then of the area, then
of the system. For category 21: 21.03, 20.03, 00.03. With no template,
the note is blank, and jd says so.

The title needs no quotes. It is every word after the category or ID,
up to the first word that starts with '--'. A '-' anywhere else is part
of the title. Flags can go before the noun, after it, or after the
title.

      --dry-run       say what it would make, and make nothing
      --json          print one JSON object on stdout instead of the
                       usual lines. { "ok": true, ... } or, on error,
                       { "ok": false, "code": "...", ... }

The template can hold {{ID}}, {{TITLE}} and {{NAME}}, which is the ID
and the title together.

A template note can hold a token, such as '{{?SCOPE}}' or
'{{?DELIVERABLE What we hand over}}'. Its flag is its name in lower
case, with '-' for '_': --scope, --deliverable. Give a value after the
title:

  jd new wp 21.41 A title --scope "What we do" --deliverable=Video

A token with no value becomes its brief, 'What we hand over', or
nothing. jd names each flag you did not set: in 'toFill' with --json,
or on stderr otherwise. Anything else in double braces that jd does not
know is left out of the note, and jd warns. The note never holds '{{'.

This is a beta feature. 'jd beta on' turns beta on.
EOF
}

_jd_new_usage_wp() {
  cat <<'EOF'
usage: <system> new wp <ID> <title>

  jd new wp 21.41 Video about work packages

It makes, in this order:

  - the next free W number, from the JDex and the filesystem
  - the project in your task app, from the template project
  - the JDex note, from the template note
  - the folder, from the template folder

The templates are in the W0003 folder in the filesystem:

  Work package template.md        the note. None: the note is blank
  Work package template/          copied into the new folder. None:
                                   the folder is empty
  Work package template.things.json
                                   the task app's project, for the
                                   things adapter

The title needs no quotes. It is every word after the ID, up to the
first word that starts with '--'. A '-' anywhere else is part of the
title. Flags can go before the noun, after it, or after the title.

      --dry-run       say what it would make, and make nothing
      --no-tasks      skip the task app
      --refresh       read the template project out of the task app
                      and write it to the template file. jd also does
                      this before it makes each work package
      --json          print one JSON object on stdout instead of the
                       usual lines. { "ok": true, ... } or, on error,
                       { "ok": false, "code": "...", ... }

The system's 'workPackages' block in the config says which adapters to
use.

A template note can hold a token, such as '{{?SCOPE}}' or
'{{?DELIVERABLE What we hand over}}'. Its flag is its name in lower
case, with '-' for '_': --scope, --deliverable. Give a value after the
title:

  jd new wp 21.41 A title --scope "What we do" --deliverable=Video

A token with no value becomes its brief, 'What we hand over', or
nothing. jd names each flag you did not set: in 'toFill' with --json,
or on stderr otherwise. Anything else in double braces that jd does not
know is left out of the note, and jd warns. The note never holds '{{'.

This is a beta feature. 'jd beta on' turns beta on.
EOF
}

# ------------------------------------------------------------ small parts

# URL-encode $1.
_jd_new_uri() { jq -rn --arg s "$1" '$s | @uri'; }

# Escape $1 for the inside of a JSON string, with no quotes around it.
_jd_new_jstr() { jq -rn --arg s "$1" '$s | @json | .[1:-1]'; }

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
# way. $1 code, $2 path this error is about (may be empty), $3+ the
# message. Always returns 1, the same as _jd_nav_err, so a caller still
# needs its own 'return 1' to leave the function it is in.
_jd_new_fail() {
  _JD_NEW_CODE=$1
  _JD_NEW_PATH=$2
  shift 2
  _JD_NEW_MSG=$*
  _jd_nav_err "$@"
}

# Add a warning code for --json. A warning does not stop the command:
# 'ok' stays true. Each code is listed once. $1 code.
_jd_new_warn() {
  _JD_NEW_WARNINGS_JSON=$(printf '%s' "$_JD_NEW_WARNINGS_JSON" |
    jq -c --arg c "$1" 'if index($c) then . else . + [$c] end')
}

# The one templates folder in a list of matches, or nothing, in
# $_JD_NEW_ONE. More than one is an error. It sets a variable and does
# not print, so that a caller need not run it in a subshell, where the
# error code would be lost. $1 matches, $2 their number, for the message.
_jd_new_one() {
  _JD_NEW_ONE=''
  if [ "$(printf '%s' "$1" | grep -c '^')" -gt 1 ]; then
    _jd_new_fail template_ambiguous "$(printf '%s' "$1" | head -1)" \
      "there is more than one $2 folder, so jd cannot tell which one holds the templates"
    return 1
  fi
  _JD_NEW_ONE=$1
}

# The jq that reads a template note. One regular expression finds every
# '{{...}}' in it, and sorts each into one of three kinds:
#
#   {{ID}}                  a placeholder jd knows. $fixed holds its value
#   {{?SCOPE}}              a token. Its value comes from a flag, --scope,
#   {{?SCOPE What we do}}   or else it is the brief. No brief gives ''
#   {{anything else}}       unknown. It is left out of the note
#
# A token name is [A-Z][A-Z0-9_]*. Its flag is the name in lower case,
# with '-' for '_': {{?DELIVERABLE_DATE}} is --deliverable-date.
#
# The note is filled in one pass, so a value is put in exactly as it was
# given, even one that holds '{{'.
_JD_NEW_JQ='
def re: "\\{\\{(?<q>\\?)?(?<n>[^} \\n]*)(?: (?<b>[^}\\n]*))?\\}\\}";
def caps: .captures | map({(.name): .string}) | add;
def tok: .q == "?" and ((.n // "") | test("^[A-Z][A-Z0-9_]*$"));
def fix: .q == null and ((.n // "") as $n | $fixed | has($n));
def flag: "--" + (ascii_downcase | gsub("_"; "-"));
def tokens: reduce (match(re; "g") | caps | select(tok)) as $c ([];
  if any(.[]; .token == $c.n) then .
  else . + [{token: $c.n, brief: ($c.b // ""), flag: ($c.n | flag)}] end);
def unknown: [match(re; "g") | .string as $s | caps | select((tok or fix) | not) | $s] | unique;
def fill: gsub(re; if tok then (.n as $n | $vals[$n]) // .b // ""
                   elif fix then (.n as $n | $fixed[$n]) else "" end);
'

# The placeholders jd knows, with no values, for when only the names
# matter.
_JD_NEW_FIXED_NAMES='{"W":"","w":"","ID":"","TITLE":"","NAME":"","NOTES_URL":"","TASKS_URL":""}'

# Put the values into the task app's template. $1 the text. $2 'json'
# to escape them for the inside of a JSON file. Anything else leaves
# them as they are. A note is filled by _jd_new_render, not this.
#
#   {{W}}          W0216            {{ID}}         21.41
#   {{w}}          w0216            {{TITLE}}      Video about ...
#   {{NAME}}       W0216~21.41 Video about ..., or 21.41 Video about ...
#   {{NOTES_URL}}  the note app's link to this work package
#   {{TASKS_URL}}  the task app's link to it, empty until it exists
#
# An ID has no W number and no links, so those are empty for an ID.
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

# A flag that every 'jd new' knows. Returns 1 if $1 is not one.
_jd_new_flag() {
  case $1 in
    --help) _JD_NEW_HELP=1 ;;
    --dry-run) _JD_NEW_DRY=1 ;;
    --no-tasks) _JD_NEW_USE_TASKS=0 ;;
    --refresh) _JD_NEW_REFRESH=1 ;;
    --json) _JD_NEW_JSON=1 ;;
    *) return 1 ;;
  esac
}

# The words after the ID. The title is every word up to the first flag,
# a word that starts with '--' and a letter. Any other word stays in the
# title, so 'SBS video - 14.20' and 'Cut costs -20%' are titles. After a
# flag there is no more title. $@ the words.
#
# A flag jd does not know is a token flag, '--scope value' or
# '--scope=value'. It is kept in $_JD_NEW_VALUES_JSON, by token name, and
# checked against the template once the template is read.
_jd_new_rest() {
  local words='' name val
  while [ $# -gt 0 ]; do
    case $1 in
      --[a-z]*) break ;;
    esac
    words="$words${words:+ }$1"
    shift
  done
  _JD_NEW_TITLE=$words
  while [ $# -gt 0 ]; do
    _jd_new_flag "$1" && { shift; continue; }
    case $1 in
      --[a-z]*=*) name=${1%%=*}; val=${1#*=} ;;
      --[a-z]*)
        name=$1
        [ $# -gt 1 ] || {
          _jd_new_fail no_value '' "'$name' needs a value: $name \"...\""
          return 1
        }
        val=$2
        shift
        ;;
      -*) _jd_new_fail unknown_option '' "unknown option '$1'"; return 1 ;;
      *)
        _jd_new_fail unexpected_word '' "'$1' comes after a flag - the title goes before the flags"
        return 1
        ;;
    esac
    case ${name#--} in
      *[!a-z0-9-]*) _jd_new_fail unknown_option '' "unknown option '$name'"; return 1 ;;
    esac
    _JD_NEW_VALUES_JSON=$(printf '%s' "$_JD_NEW_VALUES_JSON" | jq -c \
      --arg k "$(printf '%s' "${name#--}" | tr 'a-z-' 'A-Z_')" --arg v "$val" \
      '. + {($k): $v}')
    shift
  done
}

# Check the title. $_JD_NEW_TITLE, set by _jd_new_rest.
_jd_new_title() {
  case $_JD_NEW_TITLE in
    '') _jd_new_fail no_title '' "the new $_JD_NEW_NOUN_NAME needs a title"; return 1 ;;
    */*) _jd_new_fail title_has_slash '' "a title cannot hold '/'"; return 1 ;;
  esac
}

# Read the template note, or none. Sets $_JD_NEW_TEXT and the toFill
# list, checks the token flags, and warns about unknown placeholders.
# $1 the template file, or empty.
_jd_new_read_template() {
  local tokens given bad unknown
  _JD_NEW_TEXT=''
  [ -n "$1" ] && _JD_NEW_TEXT=$(cat "$1")
  tokens=$(jq -cn --arg t "$_JD_NEW_TEXT" --argjson fixed "$_JD_NEW_FIXED_NAMES" --argjson vals '{}' \
    "$_JD_NEW_JQ"' $t | tokens')

  # A token flag the template has no token for is a mistake. Say which
  # flags the template does have.
  bad=$(jq -rn --argjson tokens "$tokens" --argjson vals "$_JD_NEW_VALUES_JSON" \
    '$vals | keys - ($tokens | map(.token)) | first // empty')
  if [ -n "$bad" ]; then
    given="--$(printf '%s' "$bad" | tr 'A-Z_' 'a-z-')"
    if [ "$tokens" = '[]' ]; then
      _jd_new_fail unknown_option '' "unknown option '$given' - the template has no tokens"
    else
      _jd_new_fail unknown_option '' "unknown option '$given' - the template's tokens are $(
        printf '%s' "$tokens" | jq -r 'map(.flag) | join(", ")')"
    fi
    return 1
  fi

  # toFill is every token that got no value. The note has its brief.
  _JD_NEW_TOFILL_JSON=$(jq -cn --argjson tokens "$tokens" --argjson vals "$_JD_NEW_VALUES_JSON" \
    '$tokens | map(select(.token as $t | $vals | has($t) | not))')
  _JD_NEW_TOFILL_NAMES=$(printf '%s' "$_JD_NEW_TOFILL_JSON" | jq -r 'map(.flag) | join(", ")')

  unknown=$(jq -rn --arg t "$_JD_NEW_TEXT" --argjson fixed "$_JD_NEW_FIXED_NAMES" --argjson vals '{}' \
    "$_JD_NEW_JQ"' $t | unknown | join(", ")')
  if [ -n "$unknown" ]; then
    _jd_nav_err "the template has $unknown, which jd does not know, so the note leaves it out"
    _jd_new_warn unknown_placeholder
  fi
  return 0
}

# The note, filled in: the placeholders, the tokens, and nothing left in
# double braces. Reads $_JD_NEW_TEXT and the values in $_JD_NEW_*.
_jd_new_render() {
  local lo
  lo=$(printf '%s' "$_JD_NEW_NUM" | tr 'A-Z' 'a-z')
  jq -jn --arg t "$_JD_NEW_TEXT" --argjson vals "$_JD_NEW_VALUES_JSON" \
    --argjson fixed "$(jq -cn \
      --arg W "$_JD_NEW_NUM" --arg w "$lo" --arg ID "$_JD_NEW_ID" \
      --arg TITLE "$_JD_NEW_TITLE" --arg NAME "$_JD_NEW_NAME" \
      --arg NOTES_URL "$_JD_NEW_NOTES_URL" --arg TASKS_URL "$_JD_NEW_TASKS_URL" \
      '$ARGS.named')" \
    "$_JD_NEW_JQ"' $t | fill'
}

# Say that no template was found, and that the note will be blank.
# $1 what was looked for, for the message.
_jd_new_no_template() {
  _jd_nav_err "no $1 template, so the JDex note is blank"
  _jd_new_warn no_template
}

# Write the note, from $_JD_NEW_TEXT. $1 the note path. A blank template
# gives an empty file.
_jd_new_write_note() {
  _jd_new_render >"$1" || {
    _jd_new_fail write_failed "$1" "could not write $1"
    return 1
  }
  [ -n "$_JD_NEW_TEXT" ] && printf '\n' >>"$1"
  _jd_new_say "note    $1"
  [ -n "$_JD_NEW_TOFILL_NAMES" ] && _jd_new_say "not set $_JD_NEW_TOFILL_NAMES, so the note has the brief"
  return 0
}

# --------------------------------------------------------------- --json

# The success object. $1 'true' or 'false' for dryRun, $2 note path,
# $3 folder path. Reads the rest from $_JD_NEW_*, set by the caller.
#
#   noun      "id" or "wp"
#   num       the W number. Empty for an ID
#   id        the ID
#   name      the name of the note and the folder
#   template  the template note used. Empty when there was none
#   toFill    the {{?TOKEN}} tokens that got no value, each with its
#             brief and its flag. The note has the brief in its place
#   warnings  codes for what went wrong but did not stop the command
_jd_new_emit_ok() {
  jq -n \
    --arg noun "$_JD_NEW_NOUN" \
    --arg sys "$_JD_NEW_SYS" \
    --arg num "$_JD_NEW_NUM" \
    --arg id "$_JD_NEW_ID" \
    --arg title "$_JD_NEW_TITLE" \
    --arg name "$_JD_NEW_NAME" \
    --arg note "$2" \
    --arg folder "$3" \
    --arg template "$_JD_NEW_TEMPLATE" \
    --arg notesUrl "$_JD_NEW_NOTES_URL" \
    --arg tasksUrl "$_JD_NEW_TASKS_URL" \
    --argjson toFill "$_JD_NEW_TOFILL_JSON" \
    --argjson warnings "$_JD_NEW_WARNINGS_JSON" \
    --argjson dryRun "$1" \
    '{ok: true, noun: $noun, sys: $sys, num: $num, id: $id, title: $title,
      name: $name, note: $note, folder: $folder, template: $template,
      notesUrl: $notesUrl, tasksUrl: $tasksUrl, toFill: $toFill,
      warnings: $warnings, dryRun: $dryRun}'
}

# The error object. Reads $_JD_NEW_CODE, $_JD_NEW_PATH, $_JD_NEW_MSG,
# which _jd_new_fail sets as it prints the human error.
#
# Some failures come from an adapter, which prints its own message and
# knows no code. The call site sets the code for those, and the message
# stays empty. Both fall back here, so that 'code' is never empty: an
# agent branches on it, and an empty string tells it nothing.
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

# _jd_new is the entry point nav.sh calls. It resets the state, runs
# _jd_new_inner, and, only in --json mode, turns a failure into the
# error object on stdout. A success prints its own object, because what
# it holds depends on the noun and --dry-run.
#
# $1 the sys id, or '#N' for the system at index N. Then the user's words.
_jd_new() {
  _JD_NEW_JSON=0
  _JD_NEW_HELP=0
  _JD_NEW_VALUES_JSON='{}'
  _JD_NEW_DRY=0
  _JD_NEW_USE_TASKS=1
  _JD_NEW_REFRESH=0
  _JD_NEW_CODE=''
  _JD_NEW_PATH=''
  _JD_NEW_MSG=''
  _JD_NEW_WARNINGS_JSON='[]'
  _JD_NEW_TOFILL_JSON='[]'
  _JD_NEW_TOFILL_NAMES=''
  _JD_NEW_TEXT=''
  _JD_NEW_TEMPLATE=''
  _JD_NEW_NOUN=''
  _JD_NEW_NUM=''
  _JD_NEW_ID=''
  _JD_NEW_TITLE=''
  _JD_NEW_NAME=''
  _JD_NEW_NOTES_URL=''
  _JD_NEW_TASKS_URL=''
  _jd_new_inner "$@"
  _JD_NEW_STATUS=$?
  if [ "$_JD_NEW_JSON" -eq 1 ] && [ "$_JD_NEW_STATUS" -ne 0 ]; then
    _jd_new_emit_err
  fi
  return "$_JD_NEW_STATUS"
}

_jd_new_inner() {

  _JD_NEW_SYS=$1
  shift
  case $_JD_NEW_SYS in
    '#'*) _JD_NEW_SEL=".systems[${_JD_NEW_SYS#'#'}]" ;;
    *) _JD_NEW_SEL='.systems[] | select(.sys == $s)' ;;
  esac
  _JD_NEW_CFG=$(_jd_nav_config)

  # Flags can come before the noun, after it, or after the title. The
  # first word that is not a flag is the noun. The next one is the ID.
  # _jd_new_rest reads the title and the flags after it.
  while [ $# -gt 0 ]; do
    case $1 in
      help) _JD_NEW_HELP=1 ;;
      --) shift; break ;;
      -*)
        _jd_new_flag "$1" || { _jd_new_fail unknown_option '' "unknown option '$1'"; return 1; }
        ;;
      *)
        [ -z "$_JD_NEW_NOUN" ] || break
        _JD_NEW_NOUN=$1
        ;;
    esac
    shift
  done

  if [ "$_JD_NEW_HELP" -eq 1 ]; then
    case $_JD_NEW_NOUN in
      id) _jd_new_usage_id ;;
      wp) _jd_new_usage_wp ;;
      *) _jd_new_usage ;;
    esac
    return 0
  fi

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

  case $_JD_NEW_NOUN in
    id) _JD_NEW_NOUN_NAME=ID ;;
    wp) _JD_NEW_NOUN_NAME='work package' ;;
    '')
      _jd_new_usage >&2
      _jd_new_fail no_noun '' "say what to make: 'jd new id' or 'jd new wp'"
      return 1
      ;;
    *)
      _jd_new_fail unknown_noun '' "cannot make '$_JD_NEW_NOUN' - say what to make: 'jd new id' or 'jd new wp'"
      return 1
      ;;
  esac

  _JD_NEW_ROOT=$(_jd_new_cfg '.root')
  _JD_NEW_JDEX=$(_jd_new_cfg '.jdex')
  [ -n "$_JD_NEW_ROOT" ] || { _jd_new_fail unknown_system '' "system '$_JD_NEW_SYS' is not in $_JD_NEW_CFG"; return 1; }
  [ -d "$_JD_NEW_ROOT" ] || { _jd_new_fail no_root "$_JD_NEW_ROOT" "folder does not exist: $_JD_NEW_ROOT"; return 1; }
  [ -n "$_JD_NEW_JDEX" ] || {
    _jd_new_fail no_jdex_path '' "'jd new' needs a jdex path for $_JD_NEW_SYS in $_JD_NEW_CFG"
    return 1
  }
  [ -d "$_JD_NEW_JDEX" ] || { _jd_new_fail no_jdex "$_JD_NEW_JDEX" "folder does not exist: $_JD_NEW_JDEX"; return 1; }

  case $_JD_NEW_NOUN in
    id) _jd_new_id "$@" ;;
    wp) _jd_new_wp "$@" ;;
  esac
}

# -------------------------------------------------------------------- id

# The two-digit IDs used in category $1, one per line. $2 the JDex
# category.
#
# Only the JDex counts. The JDex defines the IDs, so a folder in the
# filesystem with no JDex entry is not an ID.
#
# It reads the entries directly in the category, and the entries
# directly in its archive, the .09 ID. Nothing deeper counts: a folder
# deep inside an ID can hold names from some other system.
_jd_new_used_ids() {
  local a
  {
    _jd_nav_find "$2" 1 a -name "$1.[0-9][0-9]*"
    _jd_nav_find "$2" 1 d -name "$1.09" -o -name "$1.09 *" |
    while IFS= read -r a; do
      _jd_nav_find "$a" 1 a -name "$1.[0-9][0-9]*"
    done
  } | sed 's|.*/||' | sed -n "s/^$1\.\([0-9][0-9]\)\([^0-9].*\)\{0,1\}\$/\1/p" \
    | sort -u
}

# The ID template for category $1: the first 'ID template.md' in the
# category's .03, the area's .03, then the system's 00.03. Each is found
# at ID depth, by the start of its name, the same way nav.sh finds an
# ID. Sets $_JD_NEW_TEMPLATE to the path, or leaves it empty.
_jd_new_id_template() {
  local c=$1 m
  for m in "$c.03" "${c%?}0.03" 00.03; do
    _jd_new_one "$(_jd_nav_find "$_JD_NEW_ROOT" 3 d -name "$m" -o -name "$m *")" "$m" || return 1
    if [ -n "$_JD_NEW_ONE" ] && [ -f "$_JD_NEW_ONE/$_JD_NEW_ID_TPL" ]; then
      _JD_NEW_TEMPLATE="$_JD_NEW_ONE/$_JD_NEW_ID_TPL"
      return 0
    fi
  done
  return 0
}

_jd_new_id() {
  local scope c nn max jcat fcat note_path dir used

  [ $# -gt 0 ] || { _jd_new_usage_id >&2; _JD_NEW_CODE=no_id; return 1; }
  scope=$1
  shift
  _jd_new_rest "$@" || return 1
  [ "$_JD_NEW_HELP" -eq 1 ] && { _jd_new_usage_id; return 0; }

  if [ "$_JD_NEW_REFRESH" -eq 1 ] || [ "$_JD_NEW_USE_TASKS" -eq 0 ]; then
    _jd_new_fail unknown_option '' "--refresh and --no-tasks are for 'jd new wp' only"
    return 1
  fi
  case $scope in
    [0-9][0-9]|[0-9][0-9].) c=${scope%.}; nn='' ;;
    [0-9][0-9].[0-9][0-9]) c=${scope%.*}; nn=${scope#*.} ;;
    *)
      _jd_new_fail not_an_id '' "'$scope' is not a category or an ID - the first word must be one, like 21 or 21.41"
      return 1
      ;;
  esac

  # The category, in both trees, found by the start of its name.
  jcat=$(_jd_nav_find "$_JD_NEW_JDEX" 2 d -name "$c" -o -name "$c *")
  fcat=$(_jd_nav_find "$_JD_NEW_ROOT" 2 d -name "$c" -o -name "$c *")
  if [ "$(printf '%s' "$jcat" | grep -c '^')" -ne 1 ]; then
    _jd_new_fail no_category_jdex "$_JD_NEW_JDEX" "the JDex has no one folder for category $c: $_JD_NEW_JDEX"
    return 1
  fi
  if [ "$(printf '%s' "$fcat" | grep -c '^')" -ne 1 ]; then
    _jd_new_fail no_category_root "$_JD_NEW_ROOT" "the system has no one folder for category $c: $_JD_NEW_ROOT"
    return 1
  fi

  used=$(_jd_new_used_ids "$c" "$jcat")
  if [ -n "$nn" ]; then
    if printf '%s\n' "$used" | grep -qx "$nn"; then
      _jd_new_fail exists '' "$c.$nn is already used"
      return 1
    fi
  else
    # One more than the highest, and never lower than .11. The leading
    # zero goes first, because '08' is not a number to the shell.
    max=$(printf '%s\n' "$used" | tail -1)
    max=${max#0}
    [ -n "$max" ] || max=0
    max=$((max + 1))
    [ "$max" -ge 11 ] || max=11
    if [ "$max" -gt 99 ]; then
      _jd_new_fail ids_exhausted "$jcat" "category $c has no free ID: $c.99 is in the JDex"
      return 1
    fi
    nn=$(printf '%02d' "$max")
  fi
  _JD_NEW_ID="$c.$nn"

  # The ID is not in the JDex, but the filesystem may still have a folder
  # with its number. jd does not make a second one. The name must be the
  # ID alone or the ID and a space: '21.53+ Extension' is not 21.53.
  dir=$(_jd_nav_find "$fcat" 1 a -name "$_JD_NEW_ID" -o -name "$_JD_NEW_ID *")
  if [ -n "$dir" ]; then
    dir=$(printf '%s' "$dir" | head -1)
    _jd_new_fail folder_exists "$dir" "$_JD_NEW_ID is not in the JDex, but the filesystem has it: $dir"
    return 1
  fi

  _jd_new_title || return 1
  _JD_NEW_NAME="$_JD_NEW_ID $_JD_NEW_TITLE"
  note_path="$jcat/$_JD_NEW_NAME.md"
  dir="$fcat/$_JD_NEW_NAME"
  if [ -e "$note_path" ] || [ -e "$dir" ]; then
    _jd_new_fail exists "$dir" "$_JD_NEW_NAME already exists"
    return 1
  fi

  _jd_new_id_template "$c" || return 1
  _jd_new_read_template "$_JD_NEW_TEMPLATE" || return 1

  printf 'jd: %s\n' "$_JD_NEW_NAME" >&2
  [ -n "$_JD_NEW_TEMPLATE" ] || _jd_new_no_template ID

  if [ "$_JD_NEW_DRY" -eq 1 ]; then
    _jd_new_say "note    $note_path"
    [ -n "$_JD_NEW_TEMPLATE" ] && _jd_new_say "from    $_JD_NEW_TEMPLATE"
    [ -n "$_JD_NEW_TOFILL_NAMES" ] && _jd_new_say "not set $_JD_NEW_TOFILL_NAMES, so the note has the brief"
    _jd_new_say "folder  $dir"
    _jd_new_say 'nothing was made'
    [ "$_JD_NEW_JSON" -eq 1 ] && _jd_new_emit_ok true "$note_path" "$dir"
    return 0
  fi

  _jd_new_write_note "$note_path" || return 1
  mkdir -- "$dir" || { _jd_new_fail mkdir_failed "$dir" "could not make $dir"; return 1; }
  _jd_new_say "folder  $dir"

  cd -- "$dir" || return 1
  if [ "$_JD_NEW_JSON" -eq 1 ]; then
    _jd_new_emit_ok false "$note_path" "$dir"
  else
    pwd
  fi
}

# -------------------------------------------------------------------- wp

# The highest W number in the JDex, plus one. $1 the JDex work package
# area.
#
# Only the JDex counts, the same as for an ID. It reads the entries
# directly in the area, and the entries directly in its archive, W0009.
# Nothing deeper counts: a folder deep inside a work package can hold
# names from some other system.
_jd_new_next_number() {
  local max n a
  max=$(
    {
      _jd_nav_find "$1" 1 a -iname 'w[0-9][0-9][0-9][0-9]*'
      _jd_nav_find "$1" 1 d -iname 'W0009' -o -iname 'W0009 *' |
      while IFS= read -r a; do
        _jd_nav_find "$a" 1 a -iname 'w[0-9][0-9][0-9][0-9]*'
      done
    } | sed 's|.*/||' | sed -n 's/^[Ww]\([0-9][0-9][0-9][0-9]\)\([^0-9].*\)\{0,1\}$/\1/p' \
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

# 2.5 read the template paths from the config. jd finds them in W0003
# now, so a config that still names one is out of date. Say so, once
# for each key, and carry on.
_jd_new_old_keys() {
  local k
  for k in noteTemplate folderTemplate tasks.template; do
    [ -n "$(_jd_new_cfg ".workPackages.$k")" ] || continue
    _jd_nav_err "the config sets workPackages.$k, which jd no longer reads - delete it. The templates are in W0003"
    _jd_new_warn config_key_ignored
  done
}

_jd_new_wp() {
  local jw fw w3 folder_tpl notes_ad tasks_ad note_path dir ep

  # Both work package areas, found by the start of the number, the same
  # way nav.sh finds them.
  jw=$(_jd_nav_find "$_JD_NEW_JDEX" 1 d -iname 'W0000*')
  fw=$(_jd_nav_find "$_JD_NEW_ROOT" 1 d -iname 'W0000*')
  if [ "$(printf '%s' "$jw" | grep -c '^')" -ne 1 ]; then
    _jd_new_fail no_wp_area_jdex "$_JD_NEW_JDEX" "the JDex has no one folder named W0000... at the top: $_JD_NEW_JDEX"
    return 1
  fi
  if [ "$(printf '%s' "$fw" | grep -c '^')" -ne 1 ]; then
    _jd_new_fail no_wp_area_root "$_JD_NEW_ROOT" "the system has no one folder named W0000... at the top: $_JD_NEW_ROOT"
    return 1
  fi

  # The ID, then the title and any flags after it.
  if [ $# -gt 0 ]; then
    _JD_NEW_ID=$1
    shift
    _jd_new_rest "$@" || return 1
  fi
  [ "$_JD_NEW_HELP" -eq 1 ] && { _jd_new_usage_wp; return 0; }

  _jd_new_old_keys

  # The templates folder, W0003, in the filesystem work package area.
  _jd_new_one "$(_jd_nav_find "$fw" 1 d -iname 'W0003' -o -iname 'W0003 *')" W0003 || return 1
  w3=$_JD_NEW_ONE

  notes_ad=$(_jd_new_cfg '.workPackages.notes.adapter')
  tasks_ad=$(_jd_new_cfg '.workPackages.tasks.adapter')
  [ -n "$notes_ad" ] || notes_ad=none
  [ -n "$tasks_ad" ] || tasks_ad=none
  [ "$_JD_NEW_USE_TASKS" -eq 1 ] || tasks_ad=none

  _JD_NEW_TASKS_TPL=''
  [ -n "$w3" ] && _JD_NEW_TASKS_TPL="$w3/$_JD_NEW_WP_TPL.$tasks_ad.json"
  _JD_NEW_TASKS_SOURCE=$(_jd_new_cfg '.workPackages.tasks.source')
  _JD_NEW_NOTES_VAULT=$(_jd_new_cfg '.workPackages.notes.vault')

  # --refresh reads the template project out of the task app. It makes
  # no work package, so it happens before the ID and title are read.
  if [ "$_JD_NEW_REFRESH" -eq 1 ]; then
    [ -z "$_JD_NEW_ID" ] || {
      _jd_new_fail unknown_option '' "--refresh makes no work package, so it takes no ID"
      return 1
    }
    _jd_new_adapter tasks "$tasks_ad" || return 1
    jd_tasks_check || { _JD_NEW_CODE=tasks_check_failed; return 1; }
    jd_tasks_refresh || { _JD_NEW_CODE=refresh_failed; return 1; }
    return 0
  fi

  [ -n "$_JD_NEW_ID" ] || { _jd_new_usage_wp >&2; _JD_NEW_CODE=no_id; return 1; }
  case $_JD_NEW_ID in
    [0-9][0-9].[0-9][0-9]) ;;
    *) _jd_new_fail not_an_id '' "'$_JD_NEW_ID' is not an ID - the first word must be one, like 21.41"; return 1 ;;
  esac
  _jd_new_title || return 1

  _JD_NEW_NUM=$(_jd_new_next_number "$jw") || return 1

  # The number is not in the JDex, but the filesystem may still have a
  # folder with it. jd does not make a second one. 'W0301+ Extension' is
  # not W0301.
  dir=$(_jd_nav_find "$fw" 1 a -iname "$_JD_NEW_NUM" -o -iname "$_JD_NEW_NUM *" -o -iname "$_JD_NEW_NUM~*")
  if [ -n "$dir" ]; then
    dir=$(printf '%s' "$dir" | head -1)
    _jd_new_fail folder_exists "$dir" "$_JD_NEW_NUM is not in the JDex, but the filesystem has it: $dir"
    return 1
  fi

  _JD_NEW_NAME="$_JD_NEW_NUM~$_JD_NEW_ID $_JD_NEW_TITLE"
  note_path="$jw/$_JD_NEW_NAME.md"
  dir="$fw/$_JD_NEW_NAME"
  if [ -e "$note_path" ] || [ -e "$dir" ]; then
    ep=$dir
    [ -e "$dir" ] || ep=$note_path
    _jd_new_fail exists "$ep" "$_JD_NEW_NAME already exists"
    return 1
  fi

  # The templates, read now, so that a problem stops the command before
  # it makes anything.
  folder_tpl=''
  if [ -n "$w3" ]; then
    [ -f "$w3/$_JD_NEW_WP_TPL.md" ] && _JD_NEW_TEMPLATE="$w3/$_JD_NEW_WP_TPL.md"
    [ -d "$w3/$_JD_NEW_WP_TPL" ] && folder_tpl="$w3/$_JD_NEW_WP_TPL"
  fi
  _jd_new_read_template "$_JD_NEW_TEMPLATE" || return 1

  _jd_new_adapter notes "$notes_ad" || return 1
  _jd_new_adapter tasks "$tasks_ad" || return 1
  jd_notes_check || { _JD_NEW_CODE=notes_check_failed; return 1; }
  jd_tasks_check || { _JD_NEW_CODE=tasks_check_failed; return 1; }

  _JD_NEW_NOTES_URL=$(jd_notes_url) || { _JD_NEW_CODE=notes_url_failed; return 1; }
  _JD_NEW_TASKS_URL=''

  printf 'jd: %s\n' "$_JD_NEW_NAME" >&2
  [ -n "$_JD_NEW_TEMPLATE" ] || _jd_new_no_template 'work package'

  if [ "$_JD_NEW_DRY" -eq 1 ]; then
    _jd_new_say "note    $note_path"
    [ -n "$_JD_NEW_TEMPLATE" ] && _jd_new_say "from    $_JD_NEW_TEMPLATE"
    [ -n "$_JD_NEW_TOFILL_NAMES" ] && _jd_new_say "not set $_JD_NEW_TOFILL_NAMES, so the note has the brief"
    _jd_new_say "folder  $dir"
    [ -n "$folder_tpl" ] && _jd_new_say "from    $folder_tpl"
    _jd_new_say "notes   $notes_ad, $_JD_NEW_NOTES_URL"
    _jd_new_say "tasks   $tasks_ad"
    _jd_new_say 'nothing was made'
    [ "$_JD_NEW_JSON" -eq 1 ] && _jd_new_emit_ok true "$note_path" "$dir"
    return 0
  fi

  # The task app first. It is the only step that talks to another
  # program, so it is the only one that fails in a way this cannot
  # predict. Nothing is written to disk until it is done, except the
  # task app's own template file, which jd_tasks_prepare may refresh.
  # The adapter prints its own message on failure, so this only records
  # the code.
  if [ "$tasks_ad" != none ]; then
    jd_tasks_prepare || { _JD_NEW_CODE=tasks_prepare_failed; return 1; }
    _JD_NEW_TASKS_URL=$(jd_tasks_create "$_JD_NEW_NAME") || {
      _JD_NEW_CODE=tasks_failed
      _JD_NEW_PATH=''
      _JD_NEW_MSG='the task app failed to make the work package'
      return 1
    }
    _jd_new_say "tasks   $_JD_NEW_TASKS_URL"
  fi

  # The JDex note, with both links in it.
  _jd_new_write_note "$note_path" || return 1

  # The folder, and the contents of the template folder.
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
      _jd_new_warn tasks_link_failed
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
