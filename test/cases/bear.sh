# SPDX-License-Identifier: MIT
# bear.sh - a JDex in Bear
#
# Nothing here runs Bear. $JD_BEARCLI names a stub, which prints a tag
# list and a note list from files, and writes each note it is asked to
# create to a file. A stub 'open' on $PATH records each URL.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_build_templates

_jd_t_bear="$JD_T_TMP/bear"
mkdir -p "$_jd_t_bear/bin"
cat >"$_jd_t_bear/bearcli" <<EOF
#!/bin/sh
d='$_jd_t_bear'
printf '%s\n' "\$*" >>"\$d/calls"
case \$1 in
  tags) cat "\$d/tags.json" ;;
  list) cat "\$d/notes.json" ;;
  app) printf '%s\n' "\$3" >>"\$d/opened" ;;
  create)
    n=\$(cat "\$d/count" 2>/dev/null || echo 0)
    n=\$((n + 1))
    echo "\$n" >"\$d/count"
    cat >"\$d/created.\$n"
    printf '{"id":"NEW-%s"}\n' "\$n"
    ;;
esac
EOF
cat >"$_jd_t_bear/bin/open" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>'$_jd_t_bear/opened'
EOF
chmod +x "$_jd_t_bear/bearcli" "$_jd_t_bear/bin/open"
JD_BEARCLI="$_jd_t_bear/bearcli"
PATH="$_jd_t_bear/bin:$PATH"
export JD_BEARCLI PATH

# The library. D25's tags are at the top level. P76's are below its own
# tag, '#P76 Personal#'.
cat >"$_jd_t_bear/tags.json" <<'EOF'
[
  {"tag": "#10-19 Area one#"},
  {"tag": "#10-19 Area one/11 Category eleven#"},
  {"tag": "#10-19 Area one/11 Category eleven/11.13#"},
  {"tag": "#20-29 Area two#"},
  {"tag": "#20-29 Area two/21 Category, twentyone#"},
  {"tag": "#W0000-9999 Work packages#"},
  {"tag": "#W0000-9999 Work packages/active#"},
  {"tag": "#Other"},
  {"tag": "#P76 Personal#"},
  {"tag": "#P76 Personal/30-39 Area three#"},
  {"tag": "#P76 Personal/30-39 Area three/31 Category thirtyone#"}
]
EOF
cat >"$_jd_t_bear/notes.json" <<'EOF'
[
  {"id": "N1", "title": "11.11 First ID", "location": "notes",
   "tags": ["#10-19 Area one#", "#10-19 Area one/11 Category eleven#"]},
  {"id": "N2", "title": "11.12 Second ID", "location": "archive",
   "tags": ["#10-19 Area one/11 Category eleven#"]},
  {"id": "N3", "title": "11.13 Tripsy travel", "location": "notes",
   "tags": ["#10-19 Area one/11 Category eleven/11.13#"]},
  {"id": "N4", "title": "11.14 In the trash", "location": "trash",
   "tags": ["#10-19 Area one/11 Category eleven#"]},
  {"id": "N5", "title": "21.11 Tripsy notes", "location": "notes",
   "tags": ["#20-29 Area two/21 Category, twentyone#"]},
  {"id": "N6", "title": "W0212~21.11 Kettle rebuild", "location": "notes",
   "tags": ["#W0000-9999 Work packages/active#"]},
  {"id": "N7", "title": "11.15 No tag", "location": "notes", "tags": []},
  {"id": "N8", "title": "21.12 Bear only", "location": "notes",
   "tags": ["#20-29 Area two/21 Category, twentyone#"]},
  {"id": "N9", "title": "31.11 Pear", "location": "notes",
   "tags": ["#P76 Personal/30-39 Area three/31 Category thirtyone#"]}
]
EOF

jq -n --arg r1 "$JD_FX_ROOT" --arg r2 "$JD_FX_ROOT2" '{version: 2, systems: [
  {sys: "D25", title: "Test system", root: $r1, jdex: {app: "bear"}, default: true},
  {sys: "P76", title: "Second system", root: $r2, jdex: {app: "bear"}}
]}' >"$JD_T_TMP/bear.json"
_jd_t_load "$JD_T_TMP/bear.json"

_jd_t_opened() { tail -n 1 "$_jd_t_bear/opened" 2>/dev/null; }

# ------------------------------------------------------------- jdex

_jd_t_run jdex 11.11
_jd_t_status 'id: exit status' 0
_jd_t_eq 'id: opens the note' N1 "$(_jd_t_opened)"
_jd_t_eq 'id: says what it opened' \
  'jd: opened 10-19 Area one/11 Category eleven/11.11 First ID in Bear' "$JD_T_ERR"
_jd_t_at 'id: does not change the directory' "$JD_T_TMP"
_jd_t_eq 'id: prints nothing on stdout' '' "$JD_T_OUT"

_jd_t_run jdex 11.12
_jd_t_eq 'id: an archived note is in the JDex' N2 "$(_jd_t_opened)"
_jd_t_run jdex 11.13
_jd_t_eq 'id: a tag below the category counts as the category' N3 "$(_jd_t_opened)"
_jd_t_run jdex 11.14
_jd_t_contains 'id: a note in the trash is not in the JDex' 'no match for 11.14' "$JD_T_ERR"
_jd_t_run jdex 11.15
_jd_t_contains 'id: a note with no category tag is not in the JDex' 'no match for 11.15' "$JD_T_ERR"

_jd_t_run jdex 11
_jd_t_eq 'category: opens the tag' \
  'bear://x-callback-url/open-tag?name=10-19%20Area%20one%2F11%20Category%20eleven' "$(_jd_t_opened)"
_jd_t_run jdex 21
_jd_t_eq 'category: a tag with a comma' \
  'bear://x-callback-url/open-tag?name=20-29%20Area%20two%2F21%20Category%2C%20twentyone' "$(_jd_t_opened)"
_jd_t_run jdex 10-19
_jd_t_eq 'area: opens the tag' 'bear://x-callback-url/open-tag?name=10-19%20Area%20one' "$(_jd_t_opened)"
_jd_t_run jdex 12
_jd_t_contains 'category: no tag is no match' 'no match for category 12' "$JD_T_ERR"

_jd_t_run jdex W0212
_jd_t_eq 'wp: opens the note' N6 "$(_jd_t_opened)"
_jd_t_run jdex w0212
_jd_t_eq 'wp: ignores case' N6 "$(_jd_t_opened)"

_jd_t_run jdex tripsy
_jd_t_status 'search: two matches, exit status' 1
_jd_t_contains 'search: lists the first' '11.13 Tripsy travel' "$JD_T_ERR"
_jd_t_contains 'search: lists the second' '21.11 Tripsy notes' "$JD_T_ERR"
_jd_t_run jdex 11 tripsy
_jd_t_eq 'search in a category: one match' N3 "$(_jd_t_opened)"
_jd_t_run jdex kettle
_jd_t_eq 'search: a work package' N6 "$(_jd_t_opened)"

_jd_t_run p76 jdex 31.11
_jd_t_eq 'base: a system below its own tag' N9 "$(_jd_t_opened)"
_jd_t_run p76 jdex 11.11
_jd_t_contains 'base: not the other system' 'no match for 11.11' "$JD_T_ERR"
_jd_t_run p76 jdex
_jd_t_eq 'base: jdex alone opens the system tag' \
  'bear://x-callback-url/open-tag?name=P76%20Personal' "$(_jd_t_opened)"
_jd_t_run jdex
_jd_t_eq 'jdex alone opens Bear' '-b net.shinyfrog.bear' "$(_jd_t_opened)"

# ------------------------------------------------------- the filesystem

# A note in Bear with no folder: jd creates the folder from its title.
_jd_t_run jd 21.12
_jd_t_status 'create id: exit status' 0
_jd_t_at 'create id: from a note in Bear' \
  "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.12 Bear only"

# ------------------------------------------------------------ jd new id

_jd_t_run jd new id --dry-run 11 Bear made
_jd_t_status 'new id: dry run, exit status' 0
_jd_t_contains 'new id: the next ID, with the trash left out' '11.14 Bear made' "$JD_T_ERR"
_jd_t_contains 'new id: names the tag' 'note    Bear: 11.14 Bear made, #10-19 Area one/11 Category eleven#' "$JD_T_ERR"

_jd_t_run jd new id 11 Bear made
_jd_t_status 'new id: exit status' 0
_jd_t_at 'new id: goes to the new folder' "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.14 Bear made"
_jd_t_eq 'new id: the title is the first line' '# 11.14 Bear made' "$(sed -n 1p "$_jd_t_bear/created.1")"
_jd_t_eq 'new id: the tag is the second line' '#10-19 Area one/11 Category eleven#' "$(sed -n 2p "$_jd_t_bear/created.1")"
_jd_t_contains 'new id: the template follows' 'System template for 11.14 Bear made' "$(cat "$_jd_t_bear/created.1")"

_jd_t_run jd new id --json 21 With a comma
_jd_t_eq 'new id: a tag with a comma' '#20-29 Area two/21 Category, twentyone#' "$(sed -n 2p "$_jd_t_bear/created.2")"
_jd_t_eq 'new id: --json names the note by its link' 'bear://x-callback-url/open-note?id=NEW-2' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.note')"

_jd_t_run jd new id --json 12 No tag
_jd_t_status 'new id: no category tag, exit status' 1
_jd_t_eq 'new id: no category tag' 'no_category_jdex' "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# ------------------------------------------------------------ jd new wp

_jd_t_run jd new wp --json --dry-run 11.11 Bear work
_jd_t_status 'new wp: dry run, exit status' 0
_jd_t_eq 'new wp: the next number' 'W0213' "$(printf '%s' "$JD_T_OUT" | jq -r '.num')"
_jd_t_eq 'new wp: the link to the note' 'bear://x-callback-url/open-note?title=W0213~11.11%20Bear%20work' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.notesUrl')"
_jd_t_eq 'new wp: the link to the ID note' '[[11.11 First ID]]' "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"

_jd_t_run jd new wp 11.11 Bear work
_jd_t_status 'new wp: exit status' 0
_jd_t_eq 'new wp: the title' '# W0213~11.11 Bear work' "$(sed -n 1p "$_jd_t_bear/created.3")"
_jd_t_eq 'new wp: the tag' '#W0000-9999 Work packages#' "$(sed -n 2p "$_jd_t_bear/created.3")"
_jd_t_contains 'new wp: the parent link' '[[11.11 First ID]]' "$(cat "$_jd_t_bear/created.3")"

_jd_t_run p76 new wp --dry-run 31.11 No area yet
_jd_t_contains 'new wp: no area tag, so the note creates one below the base' \
  '#P76 Personal/W0000-9999 Work packages#' "$JD_T_ERR"

# --------------------------------------------------------------- errors

JD_BEARCLI="$JD_T_TMP/no such bearcli"
_jd_t_run jdex 11.11
_jd_t_status 'no bearcli: exit status' 1
_jd_t_contains 'no bearcli: says where it looked' "there is no bearcli at $JD_T_TMP/no such bearcli" "$JD_T_ERR"
JD_BEARCLI="$_jd_t_bear/bearcli"

_jd_fx_reset
_jd_t_summary
