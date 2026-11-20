# SPDX-License-Identifier: MIT
# upgrade.sh - 'jd upgrade', which lists what an install of the Life
# Admin System or the Small Business System needs to reach the current
# release, and 'jd login', which stores the API key that it uses
# Part of the Johnny.Decimal command line. Sourced by bin/jd, after
# paths.sh, nav.sh, jdex.sh and bear.sh.
#
# The names follow apt and Homebrew: 'jd update' updates jd, and 'jd
# upgrade' updates the system.
#
# The history of each system is for its owners only. jd reads it from
# the Johnny.Decimal API, GET /api/v1/systems/<las|sbs>/history, with the
# key that 'jd login' writes. $JD_API_URL replaces the address of the
# site, for a copy of the site that runs on this machine. The tests set
# $JD_UPGRADE_HISTORY to a file, and jd reads the history from that file
# instead.
#
# The work is in lib/upgrade.jq. jq runs it twice: the first run lists
# what jd must read from the disk (which folders are empty, which notes
# to read, which template folders to list), and the second run sets the
# state of each item from what this file read.
#
# This version lists only. It is read-only.
#
# Requires jq, and curl for the API. Works in bash 3.2+ and zsh.

_JD_UPGRADE_API_DEFAULT=https://johnnydecimal.com
_JD_UPGRADE_KEYS_URL=https://accounts.johnnydecimal.com/user/api-keys

_jd_upgrade_usage() {
  cat <<'EOF'
usage: <system> upgrade --dry-run [--json] [--from <release>]

  jd upgrade --dry-run    list what this install of the Life Admin
                          System or the Small Business System needs to
                          reach the current release

jd reads the release from 00.00/VERSION.json, or from an older version
file, or from the folder names. It reads the history of the system
from the Johnny.Decimal API, with the key that 'jd login' writes. The
history needs Pro and the system.

Each item is a change from a release after yours. Its state is one of:

  todo   jd can apply the change
  ask    you decide: for example, the folder contains files, or you
         renamed it
  done   the install already has it

jd matches each folder and JDex note on its number, never on its full
name.

This version lists only, and is read-only. Without --dry-run, jd exits
with an error.

      --dry-run         print the list
      --json            print one JSON object on stdout.
                        { "ok": true, ... } or, on error,
                        { "ok": false, "code": "...", ... }
      --from <release>  the release that is installed, such as
                        2025-08-17, if jd cannot find it
EOF
}

_jd_login_usage() {
  cat <<EOF
usage: <system> login

  jd login            read an API key, and write it to the file that
                      'jd paths key' prints

At a terminal, jd asks for the key and does not echo it. From a script,
jd reads one line on stdin. The file has mode 600. To remove the key,
delete the file.

Generate a key at $_JD_UPGRADE_KEYS_URL
EOF
}

# --------------------------------------------------------------- login

_jd_login() {
  local path dir key tmp
  case ${1-} in
    -h | --help | help) _jd_login_usage; return 0 ;;
    '') ;;
    *) _jd_nav_err "unexpected word '$1' - see 'jd login --help'"; return 1 ;;
  esac
  path=$(_jd_paths_key)
  if [ -t 0 ]; then
    printf 'Generate a key at %s\nAPI key: ' "$_JD_UPGRADE_KEYS_URL" >&2
    stty -echo 2>/dev/null
    IFS= read -r key
    stty echo 2>/dev/null
    printf '\n' >&2
  else
    IFS= read -r key
  fi
  key=$(printf '%s' "$key" | tr -d '[:space:]')
  if [ -z "$key" ]; then
    _jd_nav_err "no key. Generate one at $_JD_UPGRADE_KEYS_URL"
    return 1
  fi
  dir=$(dirname -- "$path")
  mkdir -p -- "$dir" || return 1
  tmp="$path.tmp.$$"
  (umask 077 && printf '%s\n' "$key" >"$tmp") || {
    rm -f -- "$tmp"
    _jd_nav_err "could not write $path"
    return 1
  }
  mv -f -- "$tmp" "$path" || return 1
  chmod 600 "$path" 2>/dev/null
  printf 'jd: wrote the API key to %s\n' "$path" >&2
}

# ------------------------------------------------------------- upgrade

# $1 1 for JSON, $2 code, $3 message.
_jd_upgrade_fail() {
  if [ "$1" -eq 1 ]; then
    jq -n --arg code "$2" --arg message "$3" '{ok: false, code: $code, message: $message}'
  fi
  _jd_nav_err "$3"
}

# The area, category and ID folders of the system at $1, as JSON.
_jd_upgrade_scan_disk() {
  find -L "$1" -mindepth 1 -maxdepth 3 -type d 2>/dev/null |
    jq -R -s --arg root "$1" '
      def areare: "^([0-9][0-9]-[0-9][0-9]|[Ww]0000-9999)([^0-9]|$)";
      [split("\n")[] | select(length > 0)
       | . as $loc | ltrimstr($root + "/") | split("/") as $p
       | select($p[0] | test(areare))
       | ($p[0] | capture("^(?<n>[0-9][0-9]-[0-9][0-9]|[Ww]0000-9999)").n | ascii_upcase) as $a
       | if ($p | length) == 1 then {kind: "area", num: $a, name: $p[0], loc: $loc}
         elif ($a | test("^W")) then empty
         elif ($p[1] | test("^[0-9][0-9]([^0-9.+-]|$)")) and ($p[1][0:1] == $a[0:1]) then
           if ($p | length) == 2 then {kind: "category", num: $p[1][0:2], name: $p[1], loc: $loc}
           elif ($p[2] | test("^[0-9][0-9]\\.[0-9][0-9]([^0-9+]|$)")) and ($p[2][0:2] == $p[1][0:2]) then
             {kind: "id", num: $p[2][0:5], name: $p[2], loc: $loc}
           else empty end
         else empty end]'
}

# The JDex of a Markdown JDex at $1, as JSON. $2 nested or flat. A note
# whose name starts with an ID is that ID's note. '13.02+OPS1' and
# 'W0003~00.03 Template' are notes with no ID.
_jd_upgrade_scan_jdex_md() {
  {
    find -L "$1" -mindepth 1 -maxdepth 4 -name .obsidian -prune -o -name '*.md' -type f -print 2>/dev/null |
      sed 's/^/f /'
    if [ "$2" = nested ]; then
      find -L "$1" -mindepth 1 -maxdepth 2 -name .obsidian -prune -o -type d -print 2>/dev/null |
        sed 's/^/d /'
    fi
  } | jq -R -s --arg root "$1" '
      [split("\n")[] | select(length > 0)
       | .[0:1] as $t | .[2:] as $loc
       | ($loc | ltrimstr($root + "/") | split("/")) as $p
       | if $t == "f" then
           ($p[-1] | sub("\\.md$"; "")) as $name
           | if ($name | test("^[0-9][0-9]\\.[0-9][0-9]\\+")) or ($name | test("^[Ww][0-9]{4}")) then
               {kind: "note", num: null, name: $name, loc: $loc}
             elif ($name | test("^[0-9][0-9]\\.[0-9][0-9]([^0-9]|$)")) then
               {kind: "id", num: $name[0:5], name: $name, loc: $loc}
             else empty end
         elif ($p | length) == 1 and ($p[0] | test("^[0-9][0-9]-[0-9][0-9]([^0-9]|$)")) then
           {kind: "area", num: $p[0][0:5], name: $p[0], loc: $loc}
         elif ($p | length) == 1 and ($p[0] | test("^[Ww]0000-9999([^0-9]|$)")) then
           {kind: "area", num: "W0000-9999", name: $p[0], loc: $loc}
         elif ($p | length) == 2 and ($p[0] | test("^[0-9][0-9]-[0-9][0-9]")) and ($p[1] | test("^[0-9][0-9]([^0-9.+-]|$)")) then
           {kind: "category", num: $p[1][0:2], name: $p[1], loc: $loc}
         else empty end]'
}

# The notes of a Bear JDex, as JSON. $_JD_JDEX_SYS is set.
_jd_upgrade_scan_jdex_bear() {
  _jd_bear_load || return 1
  printf '%s\n' "$_JD_BEAR_INDEX" | jq -R -s '
    [split("\n")[] | split("\t") | select(.[0] == "N")
     | {id: .[1], name: .[2]}
     | if (.name | test("^[0-9][0-9]\\.[0-9][0-9]([^0-9+]|$)")) then
         {kind: "id", num: .name[0:5], name, loc: ("bear:" + .id)}
       else {kind: "note", num: null, name, loc: ("bear:" + .id)} end]'
}

# The version file of the system at $1, as JSON, or null. The path in
# 'file' is relative to $1.
_jd_upgrade_marker() {
  local root=$1 d f
  d=$(_jd_nav_find "$root" 3 d -name '00.00' -o -name '00.00 *' | head -n 1)
  f=''
  if [ -n "$d" ]; then
    f=$(find "$d" -mindepth 1 -maxdepth 1 -type f -iname 'version.json' 2>/dev/null | head -n 1)
    [ -n "$f" ] || f=$(find "$d" -mindepth 1 -maxdepth 1 -type f -iname 'version.txt' 2>/dev/null | head -n 1)
  fi
  if [ -z "$f" ]; then
    d=$(_jd_nav_find "$root" 3 d -name '11.02' -o -name '11.02 *' | head -n 1)
    [ -n "$d" ] && f=$(find "$d" -mindepth 1 -maxdepth 1 -type f -iname 'version.txt' 2>/dev/null | head -n 1)
  fi
  if [ -z "$f" ]; then
    printf 'null\n'
    return 0
  fi
  jq -n --arg file "${f#"$root"/}" --rawfile text "$f" '{file: $file, text: $text}'
}

# Write the history of system $1 (las or sbs) to $2. $3 1 for JSON.
_jd_upgrade_history() {
  local type=$1 out=$2 json=$3 key keyfile base code msg raw=$2.raw hdr=$2.hdr
  if [ -n "${JD_UPGRADE_HISTORY-}" ]; then
    cp -- "$JD_UPGRADE_HISTORY" "$raw" 2>/dev/null || {
      _jd_upgrade_fail "$json" no_history "cannot read $JD_UPGRADE_HISTORY"
      return 1
    }
  else
    command -v curl >/dev/null 2>&1 || {
      _jd_upgrade_fail "$json" no_curl "curl is not installed"
      return 1
    }
    keyfile=$(_jd_paths_key)
    key=$(sed -n 1p "$keyfile" 2>/dev/null | tr -d '[:space:]')
    if [ -z "$key" ]; then
      _jd_upgrade_fail "$json" no_key "no API key. Generate one at $_JD_UPGRADE_KEYS_URL, then run 'jd login'"
      return 1
    fi
    # The key goes to curl in a file, so that it is not in the list of
    # processes.
    (umask 077 && printf 'Authorization: Bearer %s\n' "$key" >"$hdr")
    base=${JD_API_URL:-$_JD_UPGRADE_API_DEFAULT}
    base=${base%/}
    code=$(curl -sS --max-time 60 -o "$raw" -w '%{http_code}' -H @"$hdr" \
      "$base/api/v1/systems/$type/history" 2>/dev/null)
    rm -f -- "$hdr"
    case $code in
      200) ;;
      000 | '')
        _jd_upgrade_fail "$json" no_connection "cannot connect to $base"
        return 1
        ;;
      401)
        _jd_upgrade_fail "$json" bad_key "the API key is not valid. Generate one at $_JD_UPGRADE_KEYS_URL, then run 'jd login'"
        return 1
        ;;
      403)
        # No Pro, or not an owner of the system. The server's sentence
        # says which, and where to buy it.
        msg=$(jq -r '.error.message // empty' "$raw" 2>/dev/null)
        _jd_upgrade_fail "$json" forbidden "${msg:-the account cannot read the history of the $type}"
        return 1
        ;;
      *)
        msg=$(jq -r '.error.message // empty' "$raw" 2>/dev/null)
        _jd_upgrade_fail "$json" "http_$code" "${msg:-the server returned HTTP $code}"
        return 1
        ;;
    esac
  fi
  if ! jq '.data // .' "$raw" >"$out" 2>/dev/null; then
    _jd_upgrade_fail "$json" bad_history "the history is not JSON"
    return 1
  fi
  rm -f -- "$raw"
  if [ "$(jq -r '.schema' "$out")" != 1 ]; then
    _jd_upgrade_fail "$json" bad_history "the history has schema $(jq -r '.schema' "$out"). This version of jd reads schema 1. 'jd update' updates jd"
    return 1
  fi
  if [ "$(jq -r '.system' "$out")" != "$type" ]; then
    _jd_upgrade_fail "$json" bad_history "the history is of the system '$(jq -r '.system' "$out")', not '$type'"
    return 1
  fi
}

# Read from the disk what the plan in $1 needs, and write it to $2 as
# JSON: { empty: {path: bool}, note: {loc: text}, tree: {path: [{rel,
# type}]} }.
_jd_upgrade_checks() {
  local plan=$1 out=$2 us rs p icon
  us=$(printf '\037')
  rs=$(printf '\036')
  icon=$(printf 'Icon\r')
  {
    jq -r '.needs.empty[]' "$plan" | while IFS= read -r p; do
      if [ -n "$(find -L "$p" -mindepth 1 ! -type d ! -name .DS_Store ! -name "$icon" -print 2>/dev/null | head -n 1)" ]; then
        printf 'E%s%s%sfalse%s' "$us" "$p" "$us" "$rs"
      else
        printf 'E%s%s%strue%s' "$us" "$p" "$us" "$rs"
      fi
    done
    jq -r '.needs.note[]' "$plan" | while IFS= read -r p; do
      printf 'N%s%s%s' "$us" "$p" "$us"
      case $p in
        bear:*) _jd_bear cat "${p#bear:}" 2>/dev/null ;;
        *) cat -- "$p" 2>/dev/null ;;
      esac
      printf '%s' "$rs"
    done
    jq -r '.needs.tree[]' "$plan" | while IFS= read -r p; do
      find -L "$p" -mindepth 1 -type d 2>/dev/null | while IFS= read -r f; do
        printf 'T%s%s%sd%s%s%s' "$us" "$p" "$us" "$us" "${f#"$p"/}" "$rs"
      done
      find -L "$p" -mindepth 1 ! -type d ! -name .DS_Store ! -name "$icon" 2>/dev/null | while IFS= read -r f; do
        printf 'T%s%s%sf%s%s%s' "$us" "$p" "$us" "$us" "${f#"$p"/}" "$rs"
      done
      # A folder with nothing in it still needs an entry.
      printf 'T%s%s%s-%s%s' "$us" "$p" "$us" "$us" "$rs"
    done
  } | jq -R -s '
    reduce (split("\u001e")[] | select(length > 0) | split("\u001f")) as $r
      ({empty: {}, note: {}, tree: {}};
       if $r[0] == "E" then .empty[$r[1]] = ($r[2] == "true")
       elif $r[0] == "N" then .note[$r[1]] = ($r[2:] | join("\u001f"))
       elif $r[2] == "-" then .tree[$r[1]] += []
       else .tree[$r[1]] += [{type: $r[2], rel: ($r[3:] | join("\u001f"))}] end)' >"$out"
}

# The result in $1, as lines for a person. $2 the sys id, $3 the JDex
# kind.
_jd_upgrade_print() {
  jq -r --arg sys "$2" --arg jdex "$3" '
    def sysname: if .system == "las" then "Life Admin System" else "Small Business System" end;
    # The side that needs the change, when the other one does not.
    def side($st):
      if $jdex == "none" or (.op | IN("move", "rename", "repurpose", "add", "remove") | not) then ""
      elif .folderState == $st and .noteState != $st then " (in the system)"
      elif .noteState == $st and .folderState != $st then " (in the JDex)"
      else "" end;
    def pad: . + ([range(0; 14 - length)] | map(" ") | join(""));
    def what:
      if .op == "move" then "move          \(.from) → \(.name)"
      elif .op == "rename" then "rename        \(.name)"
      elif .op == "repurpose" then "repurpose     \(.name). The old contents "
        + (if (.contents | type) == "object" then "go to \(.contents.moveTo)" else "are obsolete" end)
      elif .op == "add" then "add           \(.name)"
      elif .op == "remove" then "remove        \(.id) \(.title)"
      elif .op == "description" then "description   \(.id)"
      elif .op == "removeTemplate" then ("remove " + .type | pad) + "\(.id)/\(.path)"
      elif .op == "addTemplate" then ("add " + .type | pad) + "\(.id)/\(.path)"
      elif .op == "removeNote" then "remove note   \(.id)  \(.title)"
      elif .op == "addNote" then "add note      \(.id)  \(.title)"
      elif .op == "duplicate" then "duplicate     \(.id)  \(.folders | map(split("/")[-1]) | join(", "))"
      else "\(.op)  \(.id)" end;
    [.items[] | select(.state == "todo")] as $todo
    | [.items[] | select(.state == "ask")] as $ask
    | [.items[] | select(.state == "done")] as $done
    | "\($sys) is the \(sysname), release \(.release.installed). From \(.release.source)",
      "The current release is \(.release.current).",
      (if .release.installed == .release.current then "There is nothing to upgrade."
       elif ($todo | length) == 0 and ($ask | length) == 0 then "The install already has every change."
       else empty end),
      (if ($todo | length) > 0 then "", "To do:", ($todo[] | "  " + what + side("todo")) else empty end),
      (if ($ask | length) > 0 then "", "Ask:", ($ask[] | "  " + what + side("ask"), "                \(.reason)") else empty end),
      (if ($done | length) > 0 then "", "Done: \($done | length)" else empty end)' "$1"
}

# Run lib/upgrade.jq. $1 the stage, $2 the history file, if there is
# one. It reads the locals of _jd_upgrade: $t, $from and $kind.
_jd_upgrade_jq() {
  printf '{}\n' >"$t/h0.json"
  jq -n --arg stage "$1" --arg from "$from" --arg jdexKind "$kind" \
    --slurpfile h "${2:-$t/h0.json}" --slurpfile disk "$t/disk.json" \
    --slurpfile jdex "$t/jdex.json" --slurpfile marker "$t/marker.json" \
    --slurpfile checks "$t/checks.json" -f "$_JD_CLI_DIR/lib/upgrade.jq"
}

# $1 sys, $2 root, $3 JDex path, then the words after 'upgrade'.
_jd_upgrade() {
  local sys=$1 root=$2 jdex=$3 json=0 dry=0 from='' w t type kind
  shift 3
  for w in "$@"; do
    case $w in
      -h | --help | help) _jd_upgrade_usage; return 0 ;;
      --json) json=1 ;;
    esac
  done
  while [ $# -gt 0 ]; do
    case $1 in
      --json) ;;
      --dry-run) dry=1 ;;
      --from)
        shift
        from=${1-}
        [ -n "$from" ] || { _jd_upgrade_fail "$json" bad_option "--from requires a release"; return 1; }
        ;;
      --from=*) from=${1#--from=} ;;
      -*) _jd_upgrade_fail "$json" unknown_option "unknown option '$1'"; return 1 ;;
      *) _jd_upgrade_fail "$json" unexpected_word "unexpected word '$1'"; return 1 ;;
    esac
    shift
  done
  if [ "$dry" -eq 0 ]; then
    _jd_upgrade_fail "$json" not_yet "jd upgrade cannot apply changes yet: run jd upgrade --dry-run"
    return 1
  fi

  t=$(mktemp -d "${TMPDIR:-/tmp}/jd-upgrade.XXXXXX") || return 1
  _jd_upgrade_run
  w=$?
  # The folder contains the history, which is for owners only.
  rm -rf -- "$t"
  return $w
}

# The work of _jd_upgrade. It reads that function's locals.
_jd_upgrade_run() {
  _jd_upgrade_scan_disk "$root" >"$t/disk.json"
  _jd_upgrade_marker "$root" >"$t/marker.json"
  printf '{}\n' >"$t/checks.json"

  kind=$_JD_JDEX_KIND
  case $kind in
    nested | flat)
      if [ -d "$jdex" ]; then
        _jd_upgrade_scan_jdex_md "$jdex" "$kind" >"$t/jdex.json"
      else
        kind=none
      fi
      ;;
    bear) _jd_upgrade_scan_jdex_bear >"$t/jdex.json" || return 1 ;;
    *) kind=none ;;
  esac
  [ "$kind" = none ] && printf '[]\n' >"$t/jdex.json"

  type=$(_jd_upgrade_jq system | jq -r '. // empty')
  if [ -z "$type" ]; then
    _jd_upgrade_fail "$json" not_a_system "$sys is not an install of the Life Admin System or the Small Business System"
    return 1
  fi
  _jd_upgrade_history "$type" "$t/history.json" "$json" || return 1

  _jd_upgrade_jq plan "$t/history.json" >"$t/plan.json" || {
    _jd_upgrade_fail "$json" internal "jd could not read the history"
    return 1
  }
  if [ "$(jq -r '.ok' "$t/plan.json")" != true ]; then
    [ "$json" -eq 1 ] && cat "$t/plan.json"
    _jd_nav_err "$(jq -r '.message' "$t/plan.json")"
    return 1
  fi
  _jd_upgrade_checks "$t/plan.json" "$t/checks.json"
  _jd_upgrade_jq result "$t/history.json" >"$t/result.json" || {
    _jd_upgrade_fail "$json" internal "jd could not read the history"
    return 1
  }
  if [ "$json" -eq 1 ]; then
    jq --arg sys "$sys" '{ok, sys: $sys} + .' "$t/result.json"
  else
    _jd_upgrade_print "$t/result.json" "$sys" "$kind"
  fi
}
