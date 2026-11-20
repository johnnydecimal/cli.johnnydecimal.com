# SPDX-License-Identifier: MIT
# upgrade.sh - 'jd upgrade --dry-run', which lists what an install
# needs to reach the current release, and 'jd login'
#
# The history is synthetic: test/fixtures/upgrade-history.json. The real
# history is for owners only, and this repo is public. Its releases:
#
#   2024-01-01  the outline the install below starts from
#   2024-06-01  removes, a swap (11.21 and 11.22), a rotation of three
#               (11.31 to 11.33), a move to another category (12.11 to
#               13.11), renames, a repurpose, descriptions, an add, an
#               emoji, templates and a JDex-only note
#   2026-06-01  an add. In the window of the includeStandardZeros
#               option
#   2026-10-01  an emoji on the standard zero 11.00
#
# Nothing here uses the network. $JD_UPGRADE_HISTORY names the file.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

unset JD_BETA JD_API_URL
JD_UPGRADE_HISTORY="$JD_T_REPO/test/fixtures/upgrade-history.json"
export JD_UPGRADE_HISTORY

_jd_t_u="$JD_T_TMP/upgrade"
_jd_t_uroot="$_jd_t_u/U25 Test system"
_jd_t_ujdex="$_jd_t_u/U25 JDex"
_jd_t_ucfg="$_jd_t_u/config.json"

# The config. $1 the JDex app: obsidian, bear or none.
_jd_t_u_config() {
  mkdir -p "$_jd_t_u"
  case $1 in
    obsidian) _jd_t_j="\"jdex\": { \"app\": \"obsidian\", \"path\": \"$_jd_t_ujdex\" }," ;;
    bear) _jd_t_j='"jdex": { "app": "bear" },' ;;
    *) _jd_t_j='' ;;
  esac
  cat >"$_jd_t_ucfg" <<EOF
{
  "version": 2,
  "systems": [
    { "sys": "U25", "title": "Test system", "root": "$_jd_t_uroot", $_jd_t_j "default": true }
  ]
}
EOF
  _jd_t_load "$_jd_t_ucfg"
}

# An install of the 2024-01-01 release, emoji and ■ on, with a nested
# JDex. Every note starts with its description.
_jd_t_u_build() {
  rm -rf "$_jd_t_uroot" "$_jd_t_ujdex"
  _jd_t_a="$_jd_t_uroot/10-19 Life admin"
  _jd_t_c="$_jd_t_a/11 Alpha 🅰️"
  mkdir -p "$_jd_t_uroot/00-09 System area/00 System category ⚙️/00.00 Index of the system"
  for _jd_t_uname in '11.00 Index for 11' '11.01 Inbox for 11 📥' '11.10 ■ Fruit' '11.11 Apples' \
    '11.12 Bananas' '11.13 Cherries' '11.21 One' '11.22 Two' '11.31 Red' '11.32 Green' \
    '11.33 Blue' '11.41 Old thing' '11.42 Empty thing' '11.51 My own name' \
    '11.61 Described' '11.62 Edited'; do
    mkdir -p "$_jd_t_c/$_jd_t_uname"
  done
  mkdir -p "$_jd_t_a/12 Beta/12.11 Moves away" "$_jd_t_a/13 Gamma/13.12 Stays"
  mkdir -p "$_jd_t_c/11.11 Apples/Apple template/10 Seeds"
  printf 'x\n' >"$_jd_t_c/11.41 Old thing/a file.txt"
  printf 'x\n' >"$_jd_t_c/11.12 Bananas/a banana.txt"
  # An empty folder: .DS_Store does not count.
  printf 'x\n' >"$_jd_t_c/11.42 Empty thing/.DS_Store"

  _jd_t_ujcat="$_jd_t_ujdex/10-19 Life admin/11 Alpha 🅰️"
  mkdir -p "$_jd_t_ujcat" "$_jd_t_ujdex/10-19 Life admin/12 Beta" "$_jd_t_ujdex/10-19 Life admin/13 Gamma"
  for _jd_t_uname in '11.00 Index for 11' '11.13 Cherries' '11.41 Old thing' '11.42 Empty thing'; do
    printf '> Something.\n\n[Open in JDHQ](https://example.com/)\n' >"$_jd_t_ujcat/$_jd_t_uname.md"
  done
  printf '> Old words.\n' >"$_jd_t_ujcat/11.61 Described.md"
  printf '> Words I wrote.\n' >"$_jd_t_ujcat/11.62 Edited.md"
  printf '> Ops.\n\nMy own steps.\n' >"$_jd_t_ujcat/11.11+OPS1 Ops for apples.md"
}

# The version file. $1 its name, $2 its text, or no $1 for none.
_jd_t_u_marker() {
  _jd_t_d="$_jd_t_uroot/00-09 System area/00 System category ⚙️/00.00 Index of the system"
  rm -f "$_jd_t_d/VERSION.json" "$_jd_t_d/VERSION.txt"
  [ $# -eq 0 ] || printf '%s\n' "$2" >"$_jd_t_d/$1"
}

_jd_t_u_json() {
  _jd_t_run "$JD_T_BIN" upgrade --dry-run --json "$@"
}

# The field $2 of the item with op $1 and id $3 in the last result.
_jd_t_u_item() {
  printf '%s' "$JD_T_OUT" | jq -r --arg op "$1" --arg id "$3" \
    "[.items[] | select(.op == \$op and .id == \$id)] | first | .$2 // \"-\""
}

_jd_t_u_config obsidian
_jd_t_u_build

# ---------------------------------------------------------------- gates

_jd_t_cfg_beta_off=$(jq '.beta = false' "$_jd_t_ucfg")
printf '%s\n' "$_jd_t_cfg_beta_off" >"$_jd_t_ucfg"
_jd_t_run "$JD_T_BIN" upgrade --dry-run
_jd_t_status 'beta off: jd upgrade --dry-run is not a beta feature' 0
_jd_t_u_config obsidian

_jd_t_run "$JD_T_BIN" upgrade
_jd_t_status 'no --dry-run: exit status' 1
_jd_t_contains 'no --dry-run: says it cannot apply changes yet' 'cannot apply changes yet' "$JD_T_ERR"

_jd_t_run "$JD_T_BIN" upgrade --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' 'usage: <system> upgrade --dry-run' "$JD_T_OUT"

_jd_t_run "$JD_T_BIN" upgrade --dry-run --bogus
_jd_t_status 'unknown option: exit status' 1

# ------------------------------------------------- VERSION.json, 2024-01

_jd_t_u_marker VERSION.json '{"schema":1,"system":"las","release":"2024-01-01","created":"2024-01-02","settings":{"useEmoji":true,"useHeaderSquare":true,"casing":"preserve","spaceHandling":"preserve"}}'
_jd_t_u_json
_jd_t_status 'json: exit status' 0
_jd_t_eq 'json: ok' true "$(printf '%s' "$JD_T_OUT" | jq -r .ok)"
_jd_t_eq 'json: the system' las "$(printf '%s' "$JD_T_OUT" | jq -r .system)"
_jd_t_eq 'json: the installed release, from VERSION.json' '2024-01-01 00.00/VERSION.json' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '"\(.release.installed) \(.release.source)"')"
_jd_t_eq 'json: the current release' 2026-10-01 "$(printf '%s' "$JD_T_OUT" | jq -r .release.current)"

_jd_t_eq 'remove: a folder that contains files is ask' 'ask the folder contains files' \
  "$(_jd_t_u_item remove state 11.41) $(_jd_t_u_item remove reason 11.41)"
_jd_t_eq 'remove: an empty folder and an untouched note are todo' todo "$(_jd_t_u_item remove state 11.42)"
_jd_t_eq 'remove: the state of each side' 'ask todo' \
  "$(_jd_t_u_item remove folderState 11.41) $(_jd_t_u_item remove noteState 11.41)"

_jd_t_eq 'swap: 11.21 to 11.22' 'todo 11.21' "$(_jd_t_u_item move state 11.22) $(_jd_t_u_item move from 11.22)"
_jd_t_eq 'swap: 11.22 to 11.21' 'todo 11.22' "$(_jd_t_u_item move state 11.21) $(_jd_t_u_item move from 11.21)"
_jd_t_eq 'rotation: 11.31 to 11.33' 11.31 "$(_jd_t_u_item move from 11.33)"
_jd_t_eq 'rotation: 11.32 to 11.31' 11.32 "$(_jd_t_u_item move from 11.31)"
_jd_t_eq 'rotation: 11.33 to 11.32' 11.33 "$(_jd_t_u_item move from 11.32)"
_jd_t_eq 'move to another category: the new name' '13.11 Moved here' "$(_jd_t_u_item move name 13.11)"
_jd_t_eq 'move to another category: from 12.11' 'todo 12.11' \
  "$(_jd_t_u_item move state 13.11) $(_jd_t_u_item move from 13.11)"

_jd_t_eq 'rename: todo, with the new name' 'todo 11.13 Cherry trees' \
  "$(_jd_t_u_item rename state 11.13) $(_jd_t_u_item rename name 11.13)"
_jd_t_eq 'rename: a folder the person renamed is ask' 'ask the name differs from the name the install created' \
  "$(_jd_t_u_item rename state 11.51) $(_jd_t_u_item rename reason 11.51)"
_jd_t_eq 'emoji: a rename, with the emoji' 'todo 11.11 Apples 🍎' \
  "$(_jd_t_u_item rename state 11.11) $(_jd_t_u_item rename name 11.11)"
_jd_t_eq 'emoji: on a standard zero' 'todo 11.00 Index for 11 📇' \
  "$(_jd_t_u_item rename state 11.00) $(_jd_t_u_item rename name 11.00)"
_jd_t_eq 'emoji: a header keeps its ■' '-' "$(_jd_t_u_item rename state 11.10)"

_jd_t_eq 'repurpose: the old contents move to 13.12' 'todo 13.12' \
  "$(_jd_t_u_item repurpose state 11.12) $(printf '%s' "$JD_T_OUT" | jq -r '.items[] | select(.op == "repurpose") | .contents.moveTo')"

_jd_t_eq 'add: 11.71' todo "$(_jd_t_u_item add state 11.71)"
_jd_t_eq 'add: 11.72, from a later release' todo "$(_jd_t_u_item add state 11.72)"

_jd_t_eq 'description: the note still has the old one' todo "$(_jd_t_u_item description state 11.61)"
_jd_t_eq 'description: the person edited it' 'ask the description is not the one the install wrote' \
  "$(_jd_t_u_item description state 11.62) $(_jd_t_u_item description reason 11.62)"

_jd_t_eq 'template: the old one, top-most path only' 'todo Apple template' \
  "$(_jd_t_u_item removeTemplate state 11.11) $(_jd_t_u_item removeTemplate path 11.11)"
_jd_t_eq 'template: one remove, not one for each subfolder' 1 \
  "$(printf '%s' "$JD_T_OUT" | jq '[.items[] | select(.op == "removeTemplate")] | length')"
_jd_t_eq 'template: the new one' 'todo Orchard template' \
  "$(_jd_t_u_item addTemplate state 11.11) $(_jd_t_u_item addTemplate path 11.11)"

_jd_t_eq 'note: a JDex-only note the release removes is ask' ask "$(_jd_t_u_item removeNote state 11.11+OPS1)"

_jd_t_eq 'order: removes first, then moves' 'remove remove move' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '[.items[0:3][].op] | join(" ")')"

# Text.
_jd_t_run "$JD_T_BIN" upgrade --dry-run
_jd_t_status 'text: exit status' 0
_jd_t_contains 'text: names the system and the release' 'U25 is the Life Admin System, release 2024-01-01' "$JD_T_OUT"
_jd_t_contains 'text: a move' 'move          11.21 → 11.22 One' "$JD_T_OUT"
_jd_t_contains 'text: an ask, and its reason' 'the folder contains files' "$JD_T_OUT"
_jd_t_contains 'text: names the side' '11.00 Index for 11 📇' "$JD_T_OUT"

# Nothing changed on the disk.
_jd_t_eq 'nothing moved: 11.21 is still One' yes \
  "$([ -d "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.21 One" ] && echo yes)"

# A note the person wrote in.
printf 'My own text.\n' >>"$_jd_t_ujcat/11.42 Empty thing.md"
_jd_t_u_json
_jd_t_eq 'remove: a note that contains more than its description is ask' \
  'ask the note contains more than its description' \
  "$(_jd_t_u_item remove state 11.42) $(_jd_t_u_item remove reason 11.42)"

# --------------------------------------------------------------- done

mv "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.13 Cherries" \
  "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.13 Cherry trees"
mv "$_jd_t_ujdex/10-19 Life admin/11 Alpha 🅰️/11.13 Cherries.md" \
  "$_jd_t_ujdex/10-19 Life admin/11 Alpha 🅰️/11.13 Cherry trees.md"
mv "$_jd_t_uroot/10-19 Life admin/12 Beta/12.11 Moves away" \
  "$_jd_t_uroot/10-19 Life admin/13 Gamma/13.11 Moved here"
_jd_t_u_json
_jd_t_eq 'done: a rename the person made' done "$(_jd_t_u_item rename state 11.13)"
_jd_t_eq 'done: a move the person made' done "$(_jd_t_u_item move state 13.11)"

# ---------------------------------------------------- other markers

_jd_t_u_build
_jd_t_u_marker VERSION.txt 'Downloaded: 2024-06-01'
_jd_t_u_json
_jd_t_eq 'date: on the day of a release, the folder names decide' \
  '2024-01-01 00.00/VERSION.txt: Downloaded: 2024-06-01 and the folder names' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '"\(.release.installed) \(.release.source)"')"

_jd_t_u_marker VERSION.txt 'Downloaded: 2026-07-01'
_jd_t_u_json
_jd_t_eq 'date: the latest release on or before it' 2026-06-01 "$(printf '%s' "$JD_T_OUT" | jq -r .release.installed)"

_jd_t_u_marker VERSION.txt '2.0.3 2024-06-01'
_jd_t_u_json
_jd_t_eq 'marker: a site version matches a release' 2024-06-01 "$(printf '%s' "$JD_T_OUT" | jq -r .release.installed)"

_jd_t_u_marker
_jd_t_u_json
_jd_t_eq 'no marker: the folder names decide' '2024-01-01 the folder names' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '"\(.release.installed) \(.release.source)"')"
_jd_t_eq 'no marker: the settings, from the folder names' 'true true preserve preserve' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.settings | "\(.useEmoji) \(.useHeaderSquare) \(.casing) \(.spaceHandling)"')"

_jd_t_u_json --from 2024-06-01
_jd_t_eq '--from: names the release' '2024-06-01 --from' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '"\(.release.installed) \(.release.source)"')"
_jd_t_u_json --from 1999-01-01
_jd_t_status '--from: an unknown release fails' 1
_jd_t_eq '--from: the code' unknown_release "$(printf '%s' "$JD_T_OUT" | jq -r .code)"

# A date on the day of a release, and folders that fit both releases.
# 2026-06-01 and 2026-10-01 differ only in the emoji of 11.00, which the
# install does not have.
_jd_t_u_build
_jd_t_u_marker VERSION.txt 'Downloaded: 2026-10-01'
rm -rf "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.00 Index for 11"
_jd_t_u_json
_jd_t_eq 'tie: names that differ in an emoji stop jd' ambiguous_release "$(printf '%s' "$JD_T_OUT" | jq -r .code)"
mv "$_jd_t_uroot/00-09 System area/00 System category ⚙️" "$_jd_t_uroot/00-09 System area/00 System category"
mv "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.01 Inbox for 11 📥" "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.01 Inbox for 11"
mv "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️" "$_jd_t_uroot/10-19 Life admin/11 Alpha"
_jd_t_u_json
_jd_t_eq 'tie: the same names, so the earlier release' 2026-06-01 "$(printf '%s' "$JD_T_OUT" | jq -r .release.installed)"

# ------------------------------------------------- the standard zeros

_jd_t_u_build

_jd_t_u_marker VERSION.json '{"schema":1,"system":"las","release":"2026-06-01","created":"2026-06-02","settings":{"useEmoji":true,"useHeaderSquare":true,"casing":"preserve","spaceHandling":"preserve"}}'
rm -rf "$_jd_t_uroot/10-19 Life admin/11 Alpha 🅰️/11.00 Index for 11" \
  "$_jd_t_ujdex/10-19 Life admin/11 Alpha 🅰️/11.00 Index for 11.md"
_jd_t_u_json
_jd_t_eq 'standard zeros: a missing one is ask, not an error' ask "$(_jd_t_u_item rename state 11.00)"
_jd_t_contains 'standard zeros: the reason names the downloads' 'left out the standard zeros' \
  "$(_jd_t_u_item rename reason 11.00)"

# --------------------------------------------------------- not a system

_jd_t_u_build
_jd_t_u_marker
mv "$_jd_t_uroot/10-19 Life admin" "$_jd_t_uroot/10-19 Something else"
_jd_t_u_json
_jd_t_status 'not a system: exit status' 1
_jd_t_eq 'not a system: the code' not_a_system "$(printf '%s' "$JD_T_OUT" | jq -r .code)"

# ------------------------------------------------------------------ Bear

_jd_t_u_build
_jd_t_u_marker VERSION.json '{"schema":1,"system":"las","release":"2024-01-01","created":"2024-01-02","settings":{"useEmoji":true,"useHeaderSquare":true,"casing":"preserve","spaceHandling":"preserve"}}'
_jd_t_bear="$_jd_t_u/bear"
mkdir -p "$_jd_t_bear"
cat >"$_jd_t_bear/bearcli" <<EOF
#!/bin/sh
d='$_jd_t_bear'
case \$1 in
  tags) printf '[{"tag": "#10-19 Life admin#"}, {"tag": "#10-19 Life admin/11 Alpha#"}]\n' ;;
  list) printf '[{"id": "B1", "title": "11.61 Described", "location": "notes", "tags": ["#10-19 Life admin/11 Alpha#"]},
    {"id": "B2", "title": "11.62 Edited", "location": "notes", "tags": ["#10-19 Life admin/11 Alpha#"]}]\n' ;;
  cat) case \$2 in
      B1) printf '# 11.61 Described\n> Old words.\n' ;;
      B2) printf '# 11.62 Edited\n> Words I wrote.\n' ;;
    esac ;;
esac
EOF
chmod +x "$_jd_t_bear/bearcli"
JD_BEARCLI="$_jd_t_bear/bearcli"
export JD_BEARCLI
_jd_t_u_config bear
_jd_t_u_json
_jd_t_eq 'bear: reads the note, and the description is todo' 'todo bear:B1' \
  "$(_jd_t_u_item description state 11.61) $(_jd_t_u_item description note 11.61)"
_jd_t_eq 'bear: an edited description is ask' ask "$(_jd_t_u_item description state 11.62)"
unset JD_BEARCLI

# ------------------------------------------------------------- no JDex

_jd_t_u_config none
_jd_t_u_json
_jd_t_eq 'no JDex: no description items' 0 \
  "$(printf '%s' "$JD_T_OUT" | jq '[.items[] | select(.op == "description")] | length')"
_jd_t_eq 'no JDex: folders only' todo "$(_jd_t_u_item rename state 11.13)"

# --------------------------------------------------------- login and key

_jd_t_eq 'paths key: beside the config' "$_jd_t_u/api-key" "$("$JD_T_BIN" paths key)"
_jd_t_run sh -c "printf 'ak_test_key\n' | '$JD_T_BIN' login"
_jd_t_status 'login: exit status' 0
_jd_t_eq 'login: writes the key' ak_test_key "$(cat "$_jd_t_u/api-key")"
_jd_t_eq 'login: mode 600' '-rw-------' "$(ls -l "$_jd_t_u/api-key" | cut -c1-10)"
_jd_t_run sh -c "printf '\n' | '$JD_T_BIN' login"
_jd_t_status 'login: an empty key fails' 1

# No history file, and no key: the API is not called.
rm -f "$_jd_t_u/api-key"
_jd_t_run env -u JD_UPGRADE_HISTORY JD_API_URL=http://127.0.0.1:9 "$JD_T_BIN" upgrade --dry-run --json
_jd_t_status 'no key: exit status' 1
_jd_t_eq 'no key: the code' no_key "$(printf '%s' "$JD_T_OUT" | jq -r .code)"

# A key, but no Pro: the server returns 403 and a sentence. A stub curl
# returns it, and records the header it was sent.
_jd_t_ubin="$_jd_t_u/bin"
mkdir -p "$_jd_t_ubin"
cat >"$_jd_t_ubin/curl" <<EOF
#!/bin/sh
while [ \$# -gt 0 ]; do
  case \$1 in
    -o) shift; out=\$1 ;;
    -H) shift; cat "\${1#@}" >'$_jd_t_u/curl-header' ;;
  esac
  shift
done
printf '{"error":{"code":"FORBIDDEN","message":"The API needs a Pro membership for anything but the documentation"}}' >"\$out"
printf 403
EOF
chmod +x "$_jd_t_ubin/curl"
printf 'ak_test_key\n' >"$_jd_t_u/api-key"
_jd_t_run env -u JD_UPGRADE_HISTORY PATH="$_jd_t_ubin:$PATH" JD_API_URL=http://127.0.0.1:9 \
  "$JD_T_BIN" upgrade --dry-run --json
_jd_t_status 'no Pro: exit status' 1
_jd_t_eq 'no Pro: the code' forbidden "$(printf '%s' "$JD_T_OUT" | jq -r .code)"
_jd_t_contains "no Pro: prints the server's sentence" 'needs a Pro membership' "$JD_T_ERR"
_jd_t_eq 'no Pro: the key is in the header' 'Authorization: Bearer ak_test_key' "$(cat "$_jd_t_u/curl-header")"
rm -f "$_jd_t_u/api-key"

_jd_t_summary
