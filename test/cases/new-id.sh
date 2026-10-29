# SPDX-License-Identifier: MIT
# new-id.sh - jd new id, which makes an ID: a JDex note and a folder
#
# The IDs in the fixture, per category, in both trees:
#   11   11.11 to 11.13, and a decoy 11.11 too deep to be an ID
#   12   12.11, and 12.99 in the JDex only, so the category is full
#   13   in the filesystem only
#   19   in the JDex only
#   21   21.11 and 21.35. 21.03 holds the category's ID template
#   22   22.11 and 22.12. No 22.03, so the area template is used

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

unset JD_BETA

_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_f21="$JD_FX_ROOT/20-29 Area two/21 Category twentyone"
_jd_t_j21="$JD_FX_JDEX/20-29 Area two/21 Category twentyone"
_jd_t_f22="$JD_FX_ROOT/20-29 Area two/22 Category twentytwo"
_jd_t_j22="$JD_FX_JDEX/20-29 Area two/22 Category twentytwo"
_jd_t_j11="$JD_FX_JDEX/10-19 Area one/11 Category eleven"
_jd_t_cat_tpl="$_jd_t_f21/21.03 Templates for category 21/ID template.md"

# JSON field $1 of the last run's stdout.
_jd_t_json() { printf '%s' "$JD_T_OUT" | jq -r "$1"; }

# ------------------------------------------------------------------ help

_jd_t_run jd new id --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' \
  'usage: <system> new id <category or ID> <title>' "$JD_T_OUT"
_jd_t_contains 'help: says where the template is looked for' \
  '21.03, 20.03, 00.03' "$JD_T_OUT"

# --------------------------------------------------------------- dry run

_jd_t_run jd new id --dry-run 21 A dry run
_jd_t_status 'dry run: exit status' 0
_jd_t_contains 'dry run: names the next free ID' '21.36 A dry run' "$JD_T_ERR"
_jd_t_contains 'dry run: names the template' "$_jd_t_cat_tpl" "$JD_T_ERR"
_jd_t_contains 'dry run: says it made nothing' 'nothing was made' "$JD_T_ERR"
_jd_t_at 'dry run: does not move us' "$JD_T_TMP"
if [ -e "$_jd_t_f21/21.36 A dry run" ] || [ -e "$_jd_t_j21/21.36 A dry run.md" ]; then
  _jd_t_bad 'dry run: makes nothing' 'nothing' 'a folder or a note'
else
  _jd_t_ok 'dry run: makes nothing'
fi

# ------------------------------------------------------------- making one

_jd_t_run jd new id 21 A real one, with '&' and a comma
_jd_t_status 'make: exit status' 0
_jd_t_name='21.36 A real one, with & and a comma'
_jd_t_at 'make: leaves us in the new folder' "$_jd_t_f21/$_jd_t_name"
_jd_t_eq 'make: prints the new folder' "$_jd_t_f21/$_jd_t_name" "$JD_T_OUT"
_jd_t_lacks 'make: says nothing about a missing template' 'no ID template' "$JD_T_ERR"
if [ -d "$_jd_t_f21/$_jd_t_name" ]; then
  _jd_t_ok 'make: the folder is there'
else
  _jd_t_bad 'make: the folder is there' "$_jd_t_f21/$_jd_t_name" 'nothing'
fi
_jd_t_note=$(cat "$_jd_t_j21/$_jd_t_name.md" 2>/dev/null)
_jd_t_contains 'make: the note is in the JDex category, from the category template' \
  "Category template for $_jd_t_name" "$_jd_t_note"
_jd_t_contains 'make: a token with no value becomes its brief' \
  'Why this ID exists' "$_jd_t_note"
_jd_t_lacks 'make: no double braces are left in the note' '{{' "$_jd_t_note"
_jd_t_contains 'make: names the flag that was not set' \
  'not set --purpose, so the note has the brief' "$JD_T_ERR"

_jd_t_run jd new id --dry-run 21 The one after
_jd_t_contains 'make: the next ID counts the one just made' \
  '21.37 The one after' "$JD_T_ERR"

_jd_t_run d25 new id --dry-run 21. With a dot
_jd_t_status 'make: d25, and a category with a dot, exit status' 0
_jd_t_contains 'make: 21. is category 21' '21.37 With a dot' "$JD_T_ERR"

# --------------------------------------------------- finding the template

_jd_t_run jd new id 22 From the area
_jd_t_status 'template: category 22, exit status' 0
_jd_t_eq 'template: 22 has no 22.03, so 20.03 is used' \
  'Area template for 22.13, From the area' \
  "$(cat "$_jd_t_j22/22.13 From the area.md" 2>/dev/null)"

_jd_t_run jd new id 11 From the system
_jd_t_status 'template: category 11, exit status' 0
_jd_t_eq 'template: 11 has no 11.03 and no 10.03, so 00.03 is used' \
  'System template for 11.14 From the system' \
  "$(cat "$_jd_t_j11/11.14 From the system.md" 2>/dev/null)"
_jd_t_contains 'template: an unknown placeholder is named' '{{FOO}}' "$JD_T_ERR"
_jd_t_run jd new id --dry-run --json 11 Unknown placeholder
_jd_t_eq 'template: an unknown placeholder is a warning' 'unknown_placeholder' \
  "$(_jd_t_json '.warnings | join(",")')"

# A .03 folder with no ID template in it is passed over.
mkdir -p "$_jd_t_f22/22.03 Templates for category 22"
_jd_t_run jd new id --dry-run --json 22 Past an empty 22.03
_jd_t_eq 'template: an empty 22.03 is passed over' \
  "$JD_FX_ROOT/20-29 Area two/20 Management of area 20-29/20.03 Templates for area 20-29/ID template.md" \
  "$(_jd_t_json '.template')"
rm -rf "$_jd_t_f22/22.03 Templates for category 22"

# Two 21.03 folders: jd cannot tell which one to use, so it stops.
mkdir -p "$_jd_t_f21/21.03 A second templates folder"
_jd_t_run jd new id --json 21 Two templates folders
_jd_t_status 'template: two 21.03 folders, exit status' 1
_jd_t_eq 'template: two 21.03 folders, the code is template_ambiguous' \
  'template_ambiguous' "$(_jd_t_json '.code')"
rm -rf "$_jd_t_f21/21.03 A second templates folder"

# ------------------------------------------------------- the next free ID

# 12.99 is in the JDex only. It still counts, so category 12 is full.
_jd_t_run jd new id --json 12 No room
_jd_t_status 'next: a full category, exit status' 1
_jd_t_eq 'next: a full category, the code is ids_exhausted' 'ids_exhausted' \
  "$(_jd_t_json '.code')"

# A folder in the filesystem with no JDex entry is not an ID, so it is
# not counted. 22.13 was made above, so the next is 22.14.
mkdir -p "$_jd_t_f22/22.50 Only in the filesystem"
_jd_t_run jd new id --dry-run 22 Past the folder
_jd_t_contains 'next: a folder with no JDex entry is not counted' \
  '22.14 Past the folder' "$JD_T_ERR"

# But jd does not make a second folder with the same number.
_jd_t_run jd new id --json 22.50 A second 22.50
_jd_t_status 'next: a folder with that number, exit status' 1
_jd_t_eq 'next: a folder with that number, the code is folder_exists' \
  'folder_exists' "$(_jd_t_json '.code')"
_jd_t_eq 'next: a folder with that number, the path is the folder' \
  "$_jd_t_f22/22.50 Only in the filesystem" "$(_jd_t_json '.path')"
if [ -e "$_jd_t_j22/22.50 A second 22.50.md" ]; then
  _jd_t_bad 'next: a folder with that number, makes no note' 'no note' 'a note'
else
  _jd_t_ok 'next: a folder with that number, makes no note'
fi
_jd_t_run jd new id --dry-run 22.50 A dry run
_jd_t_status 'next: a folder with that number, a dry run refuses too' 1

# An extend-the-end is not the same number.
mkdir -p "$_jd_t_f22/22.14+ An extension"
_jd_t_run jd new id --dry-run 22 Past the extension
_jd_t_status 'next: 22.14+ does not stop 22.14' 0
_jd_t_contains 'next: 22.14+ does not stop 22.14, the ID' '22.14 Past the extension' "$JD_T_ERR"
rm -rf "$_jd_t_f22/22.14+ An extension" "$_jd_t_f22/22.50 Only in the filesystem"

# An ID inside an archive ID, in the JDex, counts too.
mkdir -p "$_jd_t_j22/22.09 Archive"
printf 'note\n' >"$_jd_t_j22/22.09 Archive/22.60 Archived.md"
_jd_t_run jd new id --dry-run 22 After the archive
_jd_t_contains 'next: an archived ID in the JDex is counted' '22.61 After the archive' "$JD_T_ERR"

# An archived ID in the filesystem only is a folder with no JDex entry.
mkdir -p "$_jd_t_f22/22.09 Archive/22.80 Archived folder"
_jd_t_run jd new id --dry-run 22 Past the archived folder
_jd_t_contains 'next: an archived folder with no JDex entry is not counted' \
  '22.61 Past the archived folder' "$JD_T_ERR"
rm -rf "$_jd_t_f22/22.09 Archive"

# Only the category and its archive count. A note deep inside an ID can
# hold a number from some other system, and it must not count.
mkdir -p "$_jd_t_j22/22.12 Widget two/Sample system"
printf 'note\n' >"$_jd_t_j22/22.12 Widget two/Sample system/22.95 Deep decoy.md"
mkdir -p "$_jd_t_j22/22.09 Archive/Old"
printf 'note\n' >"$_jd_t_j22/22.09 Archive/Old/22.96 Deeper in the archive.md"
_jd_t_run jd new id --dry-run 22 Past the decoys
_jd_t_contains 'next: a number deep inside an ID is not counted' \
  '22.61 Past the decoys' "$JD_T_ERR"
rm -rf "$_jd_t_j22/22.12 Widget two" "$_jd_t_j22/22.09 Archive/Old"

# A category with only standard zeros starts at .11.
mkdir -p "$JD_FX_JDEX/20-29 Area two/20 Management of area 20-29"
_jd_t_run jd new id --dry-run 20 The first real ID
_jd_t_contains 'next: the first ID after the standard zeros is .11' \
  '20.11 The first real ID' "$JD_T_ERR"

# ------------------------------------------------------------ an exact ID

_jd_t_run jd new id 22.70 Exactly this one
_jd_t_status 'exact: exit status' 0
_jd_t_at 'exact: makes that ID' "$_jd_t_f22/22.70 Exactly this one"
if [ -f "$_jd_t_j22/22.70 Exactly this one.md" ]; then
  _jd_t_ok 'exact: the note is there'
else
  _jd_t_bad 'exact: the note is there' '22.70 Exactly this one.md' 'nothing'
fi

# No gap is filled: the next one is after the highest.
_jd_t_run jd new id --dry-run 22 After the exact one
_jd_t_contains 'exact: the next free ID is after it' \
  '22.71 After the exact one' "$JD_T_ERR"

_jd_t_run jd new id 22.03 Templates for category 22
_jd_t_status 'exact: a standard zero can be made' 0

_jd_t_run jd new id --json 22.11 Already taken
_jd_t_status 'exact: a used ID, exit status' 1
_jd_t_eq 'exact: a used ID, the code is exists' 'exists' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 12.99 In the JDex only
_jd_t_eq 'exact: an ID in the JDex only is used' 'exists' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 22.60 In the archive
_jd_t_eq 'exact: an archived ID is used' 'exists' "$(_jd_t_json '.code')"

# ------------------------------------------------------------ token flags
#
# 21.03's template holds {{?PURPOSE Why this ID exists}}. 21.36 is made.

_jd_t_run jd new id 21 With a purpose --purpose 'To test {{ID}} & more'
_jd_t_status 'token: a flag after the title, exit status' 0
_jd_t_at 'token: the title ends at the flag' "$_jd_t_f21/21.37 With a purpose"
_jd_t_note=$(cat "$_jd_t_j21/21.37 With a purpose.md" 2>/dev/null)
_jd_t_contains 'token: the value takes the place of the token, as given' \
  'To test {{ID}} & more' "$_jd_t_note"
_jd_t_lacks 'token: the brief is not used' 'Why this ID exists' "$_jd_t_note"
_jd_t_lacks 'token: says nothing about a flag that was not set' 'not set' "$JD_T_ERR"

_jd_t_run jd new id --json 21 With equals --purpose=Equals
_jd_t_status 'token: --flag=value, exit status' 0
_jd_t_contains 'token: --flag=value works' 'Equals' \
  "$(cat "$_jd_t_j21/21.38 With equals.md" 2>/dev/null)"
_jd_t_eq 'token: toFill is empty when every token has a value' '[]' \
  "$(printf '%s' "$JD_T_OUT" | jq -c '.toFill')"

_jd_t_run jd new id --dry-run --json 21 A dry run for an agent
_jd_t_eq 'token: a dry run lists the flag for each token' '--purpose' \
  "$(_jd_t_json '.toFill[0].flag')"
_jd_t_eq 'token: and its brief' 'Why this ID exists' "$(_jd_t_json '.toFill[0].brief')"

_jd_t_run jd new id 21 Flags at the end --dry-run --json
_jd_t_status 'token: -n and --json after the title, exit status' 0
_jd_t_eq 'token: -n and --json after the title work' 'true' "$(_jd_t_json '.dryRun')"
_jd_t_eq 'token: the title stops before them' 'Flags at the end' "$(_jd_t_json '.title')"

# A '-' is part of the title, unless the word is a flag.
_jd_t_run jd new id --dry-run --json 21 SBS video - 14.20 Syncthing
_jd_t_eq 'title: a lone - is part of the title' 'SBS video - 14.20 Syncthing' \
  "$(_jd_t_json '.title')"
_jd_t_run jd new id --dry-run --json 21 Plan -n and -h
_jd_t_eq 'title: -n and -h are part of the title' 'Plan -n and -h' "$(_jd_t_json '.title')"
_jd_t_run jd new id --dry-run --json 21 Cut costs -20% and re-do it
_jd_t_eq 'title: a word that starts with - is part of the title' \
  'Cut costs -20% and re-do it' "$(_jd_t_json '.title')"
_jd_t_run jd new id --json 21 Cut costs -20% --purpose x --dry-run
_jd_t_eq 'title: it ends at the first flag' 'Cut costs -20%' "$(_jd_t_json '.title')"

_jd_t_run jd new id --json 21 Wrong flag --nope x
_jd_t_eq 'token: a flag with no token, the code is unknown_option' 'unknown_option' \
  "$(_jd_t_json '.code')"
_jd_t_contains 'token: a flag with no token, names the ones there are' \
  "the template's tokens are --purpose" "$JD_T_ERR"

_jd_t_run jd new id --json 22 No tokens here --purpose x
_jd_t_contains 'token: a template with no tokens says so' 'the template has no tokens' "$JD_T_ERR"

_jd_t_run jd new id --json 21 No value --purpose
_jd_t_eq 'token: a flag with no value, the code is no_value' 'no_value' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 21 A title --purpose x more words
_jd_t_eq 'token: words after a flag, the code is unexpected_word' 'unexpected_word' \
  "$(_jd_t_json '.code')"

if [ -e "$_jd_t_j21/21.39 Wrong flag.md" ] || [ -e "$_jd_t_j21/21.39 No value.md" ]; then
  _jd_t_bad 'token: a flag error makes nothing' 'nothing' 'a note'
else
  _jd_t_ok 'token: a flag error makes nothing'
fi

# ------------------------------------------------------------------ --json

_jd_t_run jd new id --json 21 A JSON title
_jd_t_status 'json make: exit status' 0
_jd_t_eq 'json make: ok is true' 'true' "$(_jd_t_json '.ok')"
_jd_t_eq 'json make: the noun is id' 'id' "$(_jd_t_json '.noun')"
_jd_t_eq 'json make: the ID' '21.39' "$(_jd_t_json '.id')"
_jd_t_eq 'json make: the name' '21.39 A JSON title' "$(_jd_t_json '.name')"
_jd_t_eq 'json make: the template' "$_jd_t_cat_tpl" "$(_jd_t_json '.template')"
_jd_t_eq 'json make: toFill names PURPOSE' 'PURPOSE' \
  "$(_jd_t_json '.toFill | map(.token) | join(",")')"
_jd_t_eq 'json make: no warnings' '' "$(_jd_t_json '.warnings | join(",")')"
if [ -f "$(_jd_t_json '.note')" ] && [ -d "$(_jd_t_json '.folder')" ]; then
  _jd_t_ok 'json make: the note and folder paths exist'
else
  _jd_t_bad 'json make: the note and folder paths exist' 'both' \
    "$(_jd_t_json '.note') / $(_jd_t_json '.folder')"
fi

# --------------------------------------------------------- what it refuses

_jd_t_run jd new id --json banana A title
_jd_t_eq 'refuse: not a category or an ID' 'not_an_id' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 2 A title
_jd_t_eq 'refuse: one digit is not a category' 'not_an_id' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 21
_jd_t_eq 'refuse: no title' 'no_title' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json
_jd_t_eq 'refuse: no category or ID' 'no_id' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 21 a/b
_jd_t_eq 'refuse: a title with a slash' 'title_has_slash' "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 13 No JDex category
_jd_t_eq 'refuse: the category is not in the JDex' 'no_category_jdex' \
  "$(_jd_t_json '.code')"

_jd_t_run jd new id --json 19 No folder category
_jd_t_eq 'refuse: the category is not in the filesystem' 'no_category_root' \
  "$(_jd_t_json '.code')"

_jd_t_run jd new id --json --refresh 21 A title
_jd_t_eq 'refuse: --refresh is for work packages' 'unknown_option' \
  "$(_jd_t_json '.code')"
_jd_t_contains 'refuse: says --refresh is for jd new wp' "'jd new wp'" "$JD_T_ERR"

_jd_t_run jd new id --no-tasks 21 A title
_jd_t_status 'refuse: --no-tasks is for work packages' 1

_jd_t_run p76 new id --json 31 No JDex here
_jd_t_eq 'refuse: a system with no JDex' 'no_jdex_path' "$(_jd_t_json '.code')"

# ----------------------------------------------------------- no template
#
# No .03 holds an ID template. The ID is still made, with a blank note,
# and jd says so.

_jd_fx_reset
_jd_t_run jd new id --json 22 No template
_jd_t_status 'no template: exit status' 0
_jd_t_eq 'no template: ok is true' 'true' "$(_jd_t_json '.ok')"
_jd_t_eq 'no template: the warning is no_template' 'no_template' \
  "$(_jd_t_json '.warnings | join(",")')"
_jd_t_eq 'no template: the template is empty' '' "$(_jd_t_json '.template')"
_jd_t_contains 'no template: says it found no template' 'no ID template' "$JD_T_ERR"
_jd_t_contains 'no template: says the note is blank' 'blank' "$JD_T_ERR"
if [ -f "$_jd_t_j22/22.13 No template.md" ]; then
  _jd_t_ok 'no template: the note is made'
else
  _jd_t_bad 'no template: the note is made' '22.13 No template.md' 'nothing'
fi
_jd_t_eq 'no template: the note is blank' '' \
  "$(cat "$_jd_t_j22/22.13 No template.md" 2>/dev/null)"

_jd_t_run jd new id --dry-run 22 A dry run with no template
_jd_t_contains 'no template: a dry run says so too' 'no ID template' "$JD_T_ERR"

# ------------------------------------------------------------ a flat JDex
#
# Some JDexes have no category folders: the notes sit in the root. The
# root is then the category. Here the JDex is a flat folder, and the
# filesystem is the nested one from the fixture.
#   21   21.11 and 21.35, as in the nested fixture
#   22   22.11, a decoy that 21 must not count
#   37   no notes yet, but the filesystem has the category

_jd_fx_reset
_jd_fx_build_templates
_jd_t_flat="$JD_T_TMP/flat jdex"
mkdir -p "$_jd_t_flat"
mkdir -p "$JD_FX_ROOT/20-29 Area two/37 Category thirtyseven"
for _jd_t_flatnote in '21.11 Tripsy notes' '21.35 Some title' '22.11 Widget one' '22.95 A high one'; do
  _jd_fx_note "$_jd_t_flat/$_jd_t_flatnote.md"
done
_jd_t_jdex_nested=$JD_FX_JDEX
JD_FX_JDEX=$_jd_t_flat
_jd_fx_config_new "$JD_T_TMP/new-flat.json"
JD_FX_JDEX=$_jd_t_jdex_nested
_jd_t_load "$JD_T_TMP/new-flat.json"

_jd_t_run jd new id --dry-run 21 Flat next
_jd_t_status 'flat: next free ID, exit status' 0
_jd_t_contains 'flat: the next ID counts only its own category' '21.36 Flat next' "$JD_T_ERR"
_jd_t_contains 'flat: the note goes in the JDex root' \
  "note    $_jd_t_flat/21.36 Flat next.md" "$JD_T_ERR"

_jd_t_run jd new id 21 Flat made
_jd_t_status 'flat: make, exit status' 0
if [ -f "$_jd_t_flat/21.36 Flat made.md" ] && [ -d "$_jd_t_f21/21.36 Flat made" ]; then
  _jd_t_ok 'flat: the note is in the root and the folder in the category'
else
  _jd_t_bad 'flat: the note is in the root and the folder in the category' \
    "$_jd_t_flat/21.36 Flat made.md" 'nothing'
fi
_jd_t_contains 'flat: the note comes from the template' \
  'Category template for 21.36 Flat made' "$(cat "$_jd_t_flat/21.36 Flat made.md" 2>/dev/null)"

_jd_t_run jd new id --dry-run 21 After the one made
_jd_t_contains 'flat: the next ID counts the one just made' '21.37 After the one made' "$JD_T_ERR"

_jd_t_run jd new id 21.50 Flat exact
_jd_t_status 'flat: an exact ID, exit status' 0
[ -f "$_jd_t_flat/21.50 Flat exact.md" ] && _jd_t_ok 'flat: an exact ID, the note is there' ||
  _jd_t_bad 'flat: an exact ID, the note is there' '21.50 Flat exact.md' 'nothing'

_jd_t_run jd new id --json 21.35 Flat taken
_jd_t_status 'flat: a used ID, exit status' 1
_jd_t_eq 'flat: a used ID, the code is exists' 'exists' "$(_jd_t_json '.code')"

# An ID inside the archive, 21.09, counts as in a nested JDex.
mkdir -p "$_jd_t_flat/21.09 Archive"
_jd_fx_note "$_jd_t_flat/21.09 Archive/21.60 Archived.md"
_jd_t_run jd new id --dry-run 21 After the archive
_jd_t_contains 'flat: an archived ID is counted' '21.61 After the archive' "$JD_T_ERR"
rm -rf "$_jd_t_flat/21.09 Archive"

# 22.11 is used, and 21 does not mind it.
_jd_t_run jd new id --json 22.11 Flat other category
_jd_t_eq 'flat: another category is counted for itself' 'exists' "$(_jd_t_json '.code')"

# A category with no notes yet starts at .11.
_jd_t_run jd new id --dry-run 37 Flat first
_jd_t_status 'flat: an empty category, exit status' 0
_jd_t_contains 'flat: an empty category starts at .11' '37.11 Flat first' "$JD_T_ERR"

# A folder two levels down is not a category in a flat JDex, whatever
# its name. The notes in the root still count.
mkdir -p "$_jd_t_flat/attachments/21 photos"
_jd_t_run jd new id --dry-run 21 Flat with a folder
_jd_t_contains 'flat: a folder named like the category is not the category' \
  "note    $_jd_t_flat/21.51 Flat with a folder.md" "$JD_T_ERR"
rm -rf "$_jd_t_flat/attachments"

# A flat JDex where every ID is a folder that contains its own note, as
# the Obsidian 'Folder notes' plugin does. It is still flat, and the
# folders count.
_jd_t_fnflat="$JD_T_TMP/folder note jdex"
mkdir -p "$_jd_t_fnflat/21.11 Tripsy notes" "$_jd_t_fnflat/21.40 A folder ID"
_jd_fx_note "$_jd_t_fnflat/21.11 Tripsy notes/21.11 Tripsy notes.md"
_jd_fx_note "$_jd_t_fnflat/21.40 A folder ID/21.40 A folder ID.md"
JD_FX_JDEX=$_jd_t_fnflat
_jd_fx_config_new "$JD_T_TMP/new-fnflat.json"
JD_FX_JDEX=$_jd_t_jdex_nested
_jd_t_load "$JD_T_TMP/new-fnflat.json"
_jd_t_run jd new id --dry-run 21 After the folders
_jd_t_status 'flat, folder notes: exit status' 0
_jd_t_contains 'flat, folder notes: the folders are counted, and the note goes in the root' \
  "note    $_jd_t_fnflat/21.41 After the folders.md" "$JD_T_ERR"

# A folder named like an ID, with no note of its own name, does not
# make a JDex flat.
rm -f "$_jd_t_fnflat/21.11 Tripsy notes/21.11 Tripsy notes.md" \
  "$_jd_t_fnflat/21.40 A folder ID/21.40 A folder ID.md"
_jd_t_run jd new id --json --dry-run 21 Not flat
_jd_t_eq 'flat, folder notes: with no folder note, it is not flat' 'no_category_jdex' \
  "$(_jd_t_json '.code')"
rm -rf "$_jd_t_fnflat"
_jd_t_load "$JD_T_TMP/new-flat.json"

# A JDex with no folder and no NN.NN note is still not a JDex jd can write to.
rm -f "$_jd_t_flat"/*.md
_jd_t_run jd new id --json 21 Flat empty
_jd_t_eq 'flat: no folder and no notes, the code is no_category_jdex' \
  'no_category_jdex' "$(_jd_t_json '.code')"

# Two folders for the category are ambiguous. The area folder makes
# this JDex a nested one, so the note in the root does not count.
_jd_fx_note "$_jd_t_flat/22.11 Widget one.md"
mkdir -p "$_jd_t_flat/20-29 Area/21 One" "$_jd_t_flat/20-29 Area/21 Two"
_jd_t_run jd new id --json 21 Flat ambiguous
_jd_t_eq 'flat: two category folders is still no_category_jdex' \
  'no_category_jdex' "$(_jd_t_json '.code')"

# The nested JDex is unchanged: back to the fixture config.
_jd_fx_reset
_jd_fx_build_templates
_jd_t_load "$JD_T_TMP/new.json"
_jd_t_run jd new id --dry-run 21 Still nested
_jd_t_contains 'nested: still the category folder' \
  "note    $_jd_t_j21/21.36 Still nested.md" "$JD_T_ERR"

# A note in the root of a nested JDex does not make it flat. Category 13
# has no folder in the JDex, and that is still the answer.
_jd_fx_note "$JD_FX_JDEX/00.00 Index.md"
_jd_t_run jd new id --json 13 Nested with a note in the root
_jd_t_eq 'nested: a note in the root, the code is still no_category_jdex' \
  'no_category_jdex' "$(_jd_t_json '.code')"
_jd_t_run jd new id --dry-run 21 Nested with a note in the root
_jd_t_contains 'nested: a note in the root, still the category folder' \
  "note    $_jd_t_j21/21.36 Nested with a note in the root.md" "$JD_T_ERR"
rm -f "$JD_FX_JDEX/00.00 Index.md"

_jd_t_summary
