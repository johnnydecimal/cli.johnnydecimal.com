# SPDX-License-Identifier: MIT
# new.sh - jd new wp, which creates a work package, and what every
# 'jd new' command has: the noun and help
#
# jd never calls the task app. Every config here leaves the tasks
# adapter out, so it is 'none', and the suite calls no other program.
# The Things adapter is tested by hand, because it requires Things.
#
# 'jd new id' has its own file, new-id.sh.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# 'jd new' is not a beta feature. A JD_BETA from the shell that started
# the suite must not reach a test, so every test runs with beta off.
unset JD_BETA

_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_jw="$JD_FX_JDEX/W0000-9999 Work packages"
_jd_t_fw="$JD_FX_ROOT/W0000-9999 Work packages"
_jd_t_w3="$_jd_t_fw/W0003 Templates"
# The name of the W0003 that jd creates, when the system has none.
_jd_t_w3_made='W0003 Templates for area W0000-9999'

# ------------------------------------------------------------------ help

_jd_t_run jd new --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' \
  'usage: <system> new <noun>' "$JD_T_OUT"
_jd_t_contains 'help: names the id noun' 'jd new id 21 ' "$JD_T_OUT"
_jd_t_contains 'help: names the wp noun' 'jd new wp 21.34 ' "$JD_T_OUT"

_jd_t_run jd new wp --help
_jd_t_status 'help wp: exit status' 0
_jd_t_contains 'help wp: prints the usage line' \
  'usage: <system> new wp <ID> <title>' "$JD_T_OUT"
_jd_t_contains 'help wp: prints that the title requires no quotes' \
  'The title requires no quotes.' "$JD_T_OUT"
_jd_t_contains 'help wp: prints where the templates are' 'W0003' "$JD_T_OUT"

_jd_t_run jd help
_jd_t_contains 'help: the main usage lists new wp' '<system> new wp 21.41' "$JD_T_OUT"
_jd_t_contains 'help: the main usage lists new id' '<system> new id 21' "$JD_T_OUT"

# ------------------------------------------------------------- the noun

_jd_t_run jd new --json
_jd_t_status 'noun: none, exit status' 1
_jd_t_eq 'noun: none, the code is no_noun' 'no_noun' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'noun: none, names the nouns' "'jd new id' or 'jd new wp'" "$JD_T_ERR"

# The 2.5 form, with no noun, is rejected. It must not create a work
# package.
_jd_t_run jd new --json 21.35 The old form
_jd_t_status 'noun: the 2.5 form, exit status' 1
_jd_t_eq 'noun: the 2.5 form, the code is unknown_noun' 'unknown_noun' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'noun: the 2.5 form, names the nouns' "'jd new id' or 'jd new wp'" "$JD_T_ERR"
if [ -e "$_jd_t_fw/W0301~21.35 The old form" ]; then
  _jd_t_bad 'noun: the 2.5 form creates nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'noun: the 2.5 form creates nothing'
fi

_jd_t_run jd new banana 21.35 A title
_jd_t_status 'noun: an unknown word' 1
_jd_t_contains 'noun: prints that jd cannot create it' "cannot create 'banana'" "$JD_T_ERR"

# --------------------------------------------------------------- dry run
#
# The JDex fixture contains W0300, and the filesystem fixture W0212, so
# the next free number is W0301.

_jd_t_run jd new wp --dry-run 21.35 A dry run
_jd_t_status 'dry run: exit status' 0
_jd_t_contains 'dry run: names the next free number' \
  'W0301~21.35 A dry run' "$JD_T_ERR"
_jd_t_contains 'dry run: names the note template' \
  "$_jd_t_w3/Work package template.md" "$JD_T_ERR"
_jd_t_contains 'dry run: names the folder template' \
  "$_jd_t_w3/Work package template" "$JD_T_ERR"
_jd_t_contains 'dry run: prints that it created nothing' 'nothing was created' "$JD_T_ERR"
_jd_t_contains 'dry run: names the link to the ID' \
  'parent  [[21.35 Some title]]' "$JD_T_ERR"
_jd_t_at 'dry run: does not change folder' "$JD_T_TMP"

# A flag before the noun works too.
_jd_t_run jd new --dry-run wp 21.35 A dry run
_jd_t_status 'dry run: a flag before the noun, exit status' 0
_jd_t_contains 'dry run: a flag before the noun still creates nothing' \
  'nothing was created' "$JD_T_ERR"

if [ -e "$_jd_t_fw/W0301~21.35 A dry run" ]; then
  _jd_t_bad 'dry run: creates no folder' 'no folder' 'a folder'
else
  _jd_t_ok 'dry run: creates no folder'
fi
if [ -e "$_jd_t_jw/W0301~21.35 A dry run.md" ]; then
  _jd_t_bad 'dry run: creates no note' 'no note' 'a note'
else
  _jd_t_ok 'dry run: creates no note'
fi

# ----------------------------------------------------------- creating one

_jd_t_run jd new wp 21.35 A real one, with '&' and a comma
_jd_t_status 'create: exit status' 0
_jd_t_name='W0301~21.35 A real one, with & and a comma'
_jd_t_at 'create: cds to the new folder' "$_jd_t_fw/$_jd_t_name"
_jd_t_eq 'create: prints the new folder' "$_jd_t_fw/$_jd_t_name" "$JD_T_OUT"
_jd_t_lacks 'create: prints nothing about a missing template' 'no template' "$JD_T_ERR"

if [ -d "$_jd_t_fw/$_jd_t_name" ]; then
  _jd_t_ok 'create: the folder is there'
else
  _jd_t_bad 'create: the folder is there' "$_jd_t_fw/$_jd_t_name" 'nothing'
fi
if [ -d "$_jd_t_fw/$_jd_t_name/05 Planning" ]; then
  _jd_t_ok 'create: the template folders are copied in'
else
  _jd_t_bad 'create: the template folders are copied in' '05 Planning' 'nothing'
fi
if [ -f "$_jd_t_fw/$_jd_t_name/05 Planning/a file.txt" ]; then
  _jd_t_ok 'create: a file in a template folder is copied too'
else
  _jd_t_bad 'create: a file in a template folder is copied too' 'a file.txt' 'nothing'
fi
if [ -e "$_jd_t_fw/$_jd_t_name/.DS_Store" ]; then
  _jd_t_bad 'create: .DS_Store is not copied' 'no .DS_Store' 'a .DS_Store'
else
  _jd_t_ok 'create: .DS_Store is not copied'
fi
if [ -e "$_jd_t_fw/$_jd_t_name/Work package template" ]; then
  _jd_t_bad 'create: the template folder itself is not copied in' \
    'its contents only' 'the folder'
else
  _jd_t_ok 'create: the template folder itself is not copied in'
fi

_jd_t_note=$(cat "$_jd_t_jw/$_jd_t_name.md" 2>/dev/null)
_jd_t_contains 'create: the note has the permalink' '- ^w0301' "$_jd_t_note"
_jd_t_contains 'create: the note has the Obsidian link' \
  '[Obsidian](obsidian://adv-uri?vault=D25%20JDex&block=w0301)' "$_jd_t_note"
# No task app is set, so there is no task link. The line that contains
# {{TASKS_URL}} is left out: the note never contains a link to nothing.
_jd_t_lacks 'create: the note has no empty task link' '[Things]' "$_jd_t_note"
_jd_t_contains 'create: the note has the whole name in it' \
  "## Scope for $_jd_t_name" "$_jd_t_note"
_jd_t_lacks 'create: no placeholder is left in the note' '{{' "$_jd_t_note"

# The link to the ID's own note is the first thing in the note, above
# the permalink. jd reads the ID's note for its name, and does not
# write to it.
_jd_t_eq 'create: the note starts with the link to the ID' \
  "$(printf -- '- Parent:\n\t- [[21.35 Some title]]\n- Permalink:')" \
  "$(printf '%s\n' "$_jd_t_note" | head -3)"
_jd_t_eq 'create: the ID note is not written to' 'fixture note' \
  "$(cat "$JD_FX_JDEX/20-29 Area two/21 Category twentyone/21.35 Some title.md")"

# The work package is now in both trees, so the next one is W0302.
_jd_t_run jd new wp --dry-run 21.35 The one after
_jd_t_contains 'create: the next number counts the one just created' \
  'W0302~21.35 The one after' "$JD_T_ERR"

# A number in the JDex archive, W0009, is still used.
mkdir -p "$_jd_t_jw/W0009 Archive"
printf 'note\n' >"$_jd_t_jw/W0009 Archive/W0400~21.35 Archived.md"
_jd_t_run jd new wp --dry-run 21.35 After the archive
_jd_t_contains 'create: a number in the archive is counted' \
  'W0401~21.35 After the archive' "$JD_T_ERR"
rm -rf "$_jd_t_jw/W0009 Archive"

# Only the JDex counts, and only the area and its archive. A folder in
# the filesystem, or a name deep inside a work package, is not counted.
mkdir -p "$_jd_t_fw/W0500 Only in the filesystem" \
  "$_jd_t_jw/W0100 A folder note/Sample system" \
  "$_jd_t_jw/W0009 Archive/Old"
printf 'note\n' >"$_jd_t_jw/W0100 A folder note/Sample system/W0600 Deep decoy.md"
printf 'note\n' >"$_jd_t_jw/W0009 Archive/Old/W0700 Deeper in the archive.md"
_jd_t_run jd new wp --dry-run 21.35 Past the decoys
_jd_t_contains 'create: the filesystem and deep names are not counted' \
  'W0302~21.35 Past the decoys' "$JD_T_ERR"
rm -rf "$_jd_t_fw/W0500 Only in the filesystem" "$_jd_t_jw/W0100 A folder note" \
  "$_jd_t_jw/W0009 Archive"

# A folder with the next number, and no JDex entry: jd creates no second
# one.
mkdir -p "$_jd_t_fw/W0302 An old folder"
_jd_t_run jd new wp --json 21.35 Onto a folder
_jd_t_eq 'create: a folder with the next number, the code is folder_exists' \
  'folder_exists' "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
rm -rf "$_jd_t_fw/W0302 An old folder"

# Flags after the title.
_jd_t_run jd new wp 21.35 Flags at the end --dry-run
_jd_t_contains 'create: --dry-run after the title creates nothing' 'nothing was created' "$JD_T_ERR"
_jd_t_contains 'create: the title ends before --dry-run' 'W0302~21.35 Flags at the end' "$JD_T_ERR"

_jd_t_run jd new wp --json 21.35 --refresh
_jd_t_eq 'create: --refresh with an ID is rejected' 'unknown_option' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# ---------------------------------------------------- a system function

_jd_t_run d25 new wp --dry-run 21.35 By system name
_jd_t_status 'system function: exit status' 0
_jd_t_contains 'system function: d25 new wp works too' \
  '~21.35 By system name' "$JD_T_ERR"

# --------------------------------------------------------- what it rejects

_jd_t_run jd new wp banana A title
_jd_t_status 'reject: a word that is not an ID' 1
_jd_t_contains 'reject: prints that the first word must be an ID' \
  'the first word must be one' "$JD_T_ERR"

_jd_t_run jd new wp 21
_jd_t_status 'reject: a category is not enough for a work package' 1

_jd_t_run jd new wp 21.35
_jd_t_status 'reject: no title' 1
_jd_t_contains 'reject: prints that a title is required' 'requires a title' "$JD_T_ERR"

_jd_t_run jd new wp 21.35 a/b
_jd_t_status 'reject: a title with a slash' 1
_jd_t_contains 'reject: prints why' "cannot contain '/'" "$JD_T_ERR"

_jd_t_run jd new wp --nonsense 21.35 A title
_jd_t_status 'reject: an unknown option' 1
_jd_t_contains 'reject: names the option' "unknown option '--nonsense'" "$JD_T_ERR"

_jd_t_run p76 new wp 31.11 No JDex here
_jd_t_status 'reject: a system with no JDex' 1
_jd_t_contains 'reject: prints that it requires a JDex' 'requires a jdex path' "$JD_T_ERR"

# The same title twice is not rejected. Nothing about a work package is
# unique but its number, and the second one is assigned the next free
# number.
_jd_t_run jd new wp 21.35 A real one, with '&' and a comma
_jd_t_status 'twice: the same title again is allowed' 0
_jd_t_at 'twice: it is assigned the next free number' \
  "$_jd_t_fw/W0302~21.35 A real one, with & and a comma"

# ------------------------------------------------------- no templates
#
# No W0003 folder, and no workPackages block. jd creates W0003, and
# copies its own template note into it. The work package's note comes
# from that template. No app is set, so the lines that contain a link
# are left out.

_jd_fx_reset
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd new wp --dry-run --json 21.35 No templates for this
_jd_t_status 'no W0003: dry run, exit status' 0
_jd_t_eq 'no W0003: dry run reads the template in the repo' \
  "$JD_T_REPO/templates/Work package template.md" \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.template')"
_jd_t_eq 'no W0003: dry run lists the token to fill' '--scope' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.toFill | map(.flag) | join(",")')"
if [ -e "$_jd_t_fw/$_jd_t_w3_made" ]; then
  _jd_t_bad 'no W0003: dry run creates nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'no W0003: dry run creates nothing'
fi

_jd_t_run jd new wp --json 21.35 No templates for this --scope 'What we do'
_jd_t_status 'no W0003: exit status' 0
_jd_t_eq 'no W0003: W0003 contains the template note' \
  "$(cat "$JD_T_REPO/templates/Work package template.md")" \
  "$(cat "$_jd_t_fw/$_jd_t_w3_made/Work package template.md" 2>/dev/null)"
_jd_t_eq 'no W0003: no warning' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_note=$(cat "$_jd_t_jw/W0301~21.35 No templates for this.md" 2>/dev/null)
_jd_t_contains 'no W0003: the note has the permalink' '^w0301' "$_jd_t_note"
_jd_t_contains 'no W0003: the note has the scope' '- What we do' "$_jd_t_note"
_jd_t_lacks 'no W0003: the note has no empty note link' '[Obsidian]' "$_jd_t_note"
_jd_t_lacks 'no W0003: the note has no empty task link' '[Things]' "$_jd_t_note"
_jd_t_lacks 'no W0003: the note has no link to the ID' '[[' "$_jd_t_note"
# No link is left under either heading, so the headings are left out
# too.
_jd_t_lacks 'no W0003: the note has no empty Parent heading' '- Parent:' "$_jd_t_note"
_jd_t_lacks 'no W0003: the note has no empty Related heading' '- Related:' "$_jd_t_note"
_jd_t_eq 'no W0003: the note starts with the permalink' '- Permalink:' \
  "$(printf '%s\n' "$_jd_t_note" | head -1)"
_jd_t_lacks 'no W0003: the note contains no double brace' '{{' "$_jd_t_note"
_jd_t_eq 'no W0003: no W0009 is created in an area that exists' 'no' \
  "$([ -e "$_jd_t_fw/W0009 Archive" ] && printf yes || printf no)"
_jd_t_eq 'no W0003: the folder is empty' '' \
  "$(find "$_jd_t_fw/W0301~21.35 No templates for this" -mindepth 1 2>/dev/null)"

# A W0003 with nothing in it. jd copies nothing into a W0003 that it
# did not create. A work package is still created: a blank note, an
# empty folder. jd prints that it found no template.
_jd_fx_reset
mkdir -p "$_jd_t_w3"
_jd_t_run jd new wp --json 21.35 No templates for this
_jd_t_status 'no templates: exit status' 0
_jd_t_note_path="$_jd_t_jw/W0301~21.35 No templates for this.md"
if [ -f "$_jd_t_note_path" ]; then
  _jd_t_ok 'no templates: the note is created'
else
  _jd_t_bad 'no templates: the note is created' "$_jd_t_note_path" 'nothing'
fi
_jd_t_eq 'no templates: the note is blank' '' "$(cat "$_jd_t_note_path" 2>/dev/null)"
_jd_t_contains 'no templates: prints that it found no template' \
  'no work package template' "$JD_T_ERR"
_jd_t_contains 'no templates: prints that the note is blank' 'blank' "$JD_T_ERR"
_jd_t_eq 'no templates: the warning is no_template' 'no_template' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_eq 'no templates: ok is still true' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
_jd_t_eq 'no templates: W0003 is left empty' '' \
  "$(find "$_jd_t_w3" -mindepth 1 2>/dev/null)"
_jd_t_eq 'no templates: the folder is empty' '' \
  "$(find "$_jd_t_fw/W0301~21.35 No templates for this" -mindepth 1 2>/dev/null)"

# A W0003 with a note template and no folder template: the note is
# filled in, the folder is empty, and there is no warning.
_jd_fx_reset
_jd_fx_build_templates_tokens
_jd_t_run jd new wp --json 21.35 A note template only
_jd_t_status 'note template only: exit status' 0
_jd_t_eq 'note template only: no warning' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_eq 'note template only: the folder is empty' '' \
  "$(find "$_jd_t_fw/W0301~21.35 A note template only" -mindepth 1 2>/dev/null)"

# The area has a W0003, so jd creates no second one.
if [ -e "$_jd_t_fw/$_jd_t_w3_made" ]; then
  _jd_t_bad 'note template only: no second W0003 is created' 'no folder' 'a folder'
else
  _jd_t_ok 'note template only: no second W0003 is created'
fi

# ------------------------------------------- no work package area
#
# The system has no W0000-9999 folder, and nor does the JDex. jd
# creates both, and W0003 and W0009 in the filesystem one. The names
# have no emoji. The JDex has no work package, so the first number is
# W0001.

_jd_fx_reset
rm -rf "$_jd_t_fw" "$_jd_t_jw"
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd new wp --dry-run 21.35 No area
_jd_t_status 'no area: dry run, exit status' 0
_jd_t_contains 'no area: dry run names the area' "folder  $_jd_t_fw" "$JD_T_ERR"
_jd_t_contains 'no area: dry run names W0003' \
  "folder  $_jd_t_fw/$_jd_t_w3_made" "$JD_T_ERR"
_jd_t_contains 'no area: dry run names W0009' \
  "folder  $_jd_t_fw/W0009 Archive" "$JD_T_ERR"
_jd_t_contains 'no area: dry run names the JDex area' "folder  $_jd_t_jw" "$JD_T_ERR"
if [ -e "$_jd_t_fw" ] || [ -e "$_jd_t_jw" ]; then
  _jd_t_bad 'no area: dry run creates nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'no area: dry run creates nothing'
fi

_jd_t_run jd new wp --json 21.35 No area
_jd_t_status 'no area: exit status' 0
_jd_t_eq 'no area: the first number is W0001' 'W0001' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.num')"
if [ -f "$_jd_t_fw/$_jd_t_w3_made/Work package template.md" ] && [ -d "$_jd_t_fw/W0009 Archive" ]; then
  _jd_t_ok 'no area: W0003 and W0009 are created'
else
  _jd_t_bad 'no area: W0003 and W0009 are created' 'two folders' "$(ls "$_jd_t_fw" 2>&1)"
fi
if [ -f "$_jd_t_jw/W0001~21.35 No area.md" ] && [ -d "$_jd_t_fw/W0001~21.35 No area" ]; then
  _jd_t_ok 'no area: the note and the folder are created'
else
  _jd_t_bad 'no area: the note and the folder are created' 'a note and a folder' 'not both'
fi
_jd_t_eq 'no area: the JDex area contains the note and nothing else' \
  'W0001~21.35 No area.md' "$(ls "$_jd_t_jw" 2>/dev/null)"

# The second one finds the folders, and creates none.
_jd_t_run jd new wp 21.35 No area again
_jd_t_status 'no area: the second one, exit status' 0
_jd_t_lacks 'no area: the second one creates no area' "folder  $_jd_t_fw/W0003" "$JD_T_ERR"
_jd_t_at 'no area: the second one is W0002' "$_jd_t_fw/W0002~21.35 No area again"

# Two W0000 folders: jd cannot determine which one is the area, so it
# exits with an error.
_jd_fx_reset
mkdir -p "$JD_FX_ROOT/W0000 A second area"
_jd_t_run jd new wp --json 21.35 Two areas
_jd_t_status 'two areas: exit status' 1
_jd_t_eq 'two areas: the code is no_wp_area_root' 'no_wp_area_root' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'two areas: prints that there is more than one' 'more than one folder' "$JD_T_ERR"

# A flat JDex has no area folders, and its notes are in its root. jd
# creates no folder in it: jd writes the note to the root. Its root
# contains one work package, W0150, so the next is W0151.
_jd_fx_reset
_jd_t_keep_jdex=$JD_FX_JDEX
_jd_t_flat="$JD_T_TMP/flat jdex"
mkdir -p "$_jd_t_flat"
_jd_fx_note "$_jd_t_flat/21.35 Some title.md"
_jd_fx_note "$_jd_t_flat/W0150~21.35 An old one.md"
JD_FX_JDEX=$_jd_t_flat
_jd_fx_config_two "$JD_T_TMP/two-flat.json"
JD_FX_JDEX=$_jd_t_keep_jdex
_jd_t_load "$JD_T_TMP/two-flat.json"

_jd_t_run jd new wp --json 21.35 Flat
_jd_t_status 'flat: exit status' 0
if [ -f "$_jd_t_flat/W0151~21.35 Flat.md" ]; then
  _jd_t_ok 'flat: the note is in the JDex root, with the next number'
else
  _jd_t_bad 'flat: the note is in the JDex root, with the next number' \
    "$_jd_t_flat/W0151~21.35 Flat.md" "$(ls "$_jd_t_flat" 2>&1)"
fi
_jd_t_eq 'flat: no folder is created in the JDex' '' \
  "$(find "$_jd_t_flat" -mindepth 1 -type d 2>/dev/null)"
rm -rf "$_jd_t_flat"

# ------------------------------------------------- the link to the ID
#
# jd finds the ID's JDex note by its number, and links to it by its
# name. With no note for the ID, or more than one, the line is left
# out, and jd prints a warning.

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_run jd new wp --dry-run --json 21.35 Linked
_jd_t_eq 'parent: --json has the link' '[[21.35 Some title]]' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"
_jd_t_eq 'parent: with a note for the ID, no warning' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"

# The JDex has no 21.36.
_jd_t_run jd new wp --json 21.36 No ID note
_jd_t_status 'parent: no note for the ID, exit status' 0
_jd_t_eq 'parent: no note for the ID, the warning' 'no_parent_note' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_contains 'parent: no note for the ID, prints a warning' \
  'the JDex has no one note for 21.36' "$JD_T_ERR"
_jd_t_eq 'parent: no note for the ID, --json has no link' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"
_jd_t_note=$(cat "$_jd_t_jw/W0301~21.36 No ID note.md" 2>/dev/null)
_jd_t_lacks 'parent: no note for the ID, the note has no link' '[[' "$_jd_t_note"
_jd_t_lacks 'parent: no note for the ID, no empty Parent heading' '- Parent:' "$_jd_t_note"
_jd_t_contains 'parent: no note for the ID, Related still contains its link' \
  "$(printf -- '- Related:\n\t- [Obsidian]')" "$_jd_t_note"
_jd_t_lacks 'parent: no note for the ID, no placeholder is left' '{{' "$_jd_t_note"

# Two notes for 21.35. jd cannot determine which one to link to.
_jd_fx_note "$JD_FX_JDEX/20-29 Area two/21 Category twentyone/21.35 A second note.md"
_jd_t_run jd new wp --dry-run --json 21.35 Two notes
_jd_t_eq 'parent: two notes for the ID, the warning' 'no_parent_note' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_eq 'parent: two notes for the ID, --json has no link' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"
rm -f "$JD_FX_JDEX/20-29 Area two/21 Category twentyone/21.35 A second note.md"

# The ID is a folder that contains its note, with the same name.
_jd_t_cat="$JD_FX_JDEX/20-29 Area two/21 Category twentyone"
mkdir -p "$_jd_t_cat/21.37 A folder ID"
_jd_fx_note "$_jd_t_cat/21.37 A folder ID/21.37 A folder ID.md"
_jd_fx_note "$_jd_t_cat/21.37 A folder ID/21.37+ An extension.md"
_jd_t_run jd new wp --dry-run --json 21.37 Folder note
_jd_t_eq 'parent: an ID folder with its note, the link' '[[21.37 A folder ID]]' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"

# A folder with no note of its own name is no note for the ID.
mkdir -p "$_jd_t_cat/21.38 No note of its name"
_jd_fx_note "$_jd_t_cat/21.38 No note of its name/21.38) A typo.md"
_jd_t_run jd new wp --dry-run --json 21.38 Folder, no note
_jd_t_eq 'parent: an ID folder with no note of its name, the warning' 'no_parent_note' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
rm -rf "$_jd_t_cat/21.37 A folder ID" "$_jd_t_cat/21.38 No note of its name"

# A template with no {{PARENT_LINK}} does not require the link, so jd
# prints no warning.
_jd_fx_build_templates_tokens
_jd_t_run jd new wp --dry-run --json 21.36 No link wanted
_jd_t_eq 'parent: a template with no link, no warning' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"

# A flat JDex has the ID's note in its root.
_jd_fx_reset
_jd_fx_build_templates
_jd_t_keep_jdex=$JD_FX_JDEX
_jd_t_flat="$JD_T_TMP/flat jdex"
mkdir -p "$_jd_t_flat"
_jd_fx_note "$_jd_t_flat/21.35 Some title.md"
JD_FX_JDEX=$_jd_t_flat
_jd_fx_config_new "$JD_T_TMP/new-flat.json"
JD_FX_JDEX=$_jd_t_keep_jdex
_jd_t_load "$JD_T_TMP/new-flat.json"
_jd_t_run jd new wp --dry-run --json 21.35 Flat and linked
_jd_t_eq 'parent: a flat JDex, the link' '[[21.35 Some title]]' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"

# A flat JDex whose IDs are all folder notes is still flat: the note
# is in its root, and the link is to the folder note.
rm -f "$_jd_t_flat/21.35 Some title.md"
mkdir -p "$_jd_t_flat/21.35 Some title"
_jd_fx_note "$_jd_t_flat/21.35 Some title/21.35 Some title.md"
_jd_t_run jd new wp --dry-run --json 21.35 Flat folder note
_jd_t_eq 'parent: a flat JDex of folder notes, the note is in the root' \
  "$_jd_t_flat/W0001~21.35 Flat folder note.md" \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.note')"
_jd_t_eq 'parent: a flat JDex of folder notes, the link' '[[21.35 Some title]]' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.parentLink')"
rm -rf "$_jd_t_flat"

# jd's own template has the link, first, above the permalink.
_jd_t_eq 'parent: the shipped template starts with the link' \
  "$(printf -- '- Parent:\n\t- {{PARENT_LINK}}\n- Permalink:')" \
  "$(head -3 "$JD_T_REPO/templates/Work package template.md")"

# ------------------------------------------- the task app's template
#
# jd has its own Things template, in the templates folder of the repo.
# The things adapter copies it into W0003 when the config has no source
# and W0003 has no template. Nothing here communicates with Things: the
# test calls the one function that copies, in this shell.

_jd_t_shipped="$JD_T_REPO/templates/Work package template.things.json"
_jd_t_eq 'shipped template: it is JSON, and one project' 'project' \
  "$(jq -r '.[0].type' "$_jd_t_shipped" 2>/dev/null)"
_jd_t_eq 'shipped template: the title is {{NAME}}' '{{NAME}}' \
  "$(jq -r '.[0].attributes.title' "$_jd_t_shipped" 2>/dev/null)"
_jd_t_contains 'shipped template: the notes contain {{NOTES_URL}}' '{{NOTES_URL}}' \
  "$(jq -r '.[0].attributes.notes' "$_jd_t_shipped" 2>/dev/null)"
_jd_t_contains 'shipped template: the notes contain {{TASKS_URL}}' '{{TASKS_URL}}' \
  "$(jq -r '.[0].attributes.notes' "$_jd_t_shipped" 2>/dev/null)"
# An area is a name in one person's Things, so the template has none.
_jd_t_eq 'shipped template: it sets no Things area' 'null' \
  "$(jq -r '.[0].attributes.area' "$_jd_t_shipped" 2>/dev/null)"

_jd_fx_reset
_jd_t_libs
. "$JD_T_REPO/lib/adapters/tasks/things.sh"
mkdir -p "$_jd_t_fw/$_jd_t_w3_made"
_JD_NEW_WARNINGS_JSON='[]'
_JD_NEW_TASKS_SOURCE=''
_JD_NEW_TASKS_DEFAULT=$_jd_t_shipped
_JD_NEW_TASKS_TPL="$_jd_t_fw/$_jd_t_w3_made/Work package template.things.json"

_jd_t_run jd_tasks_prepare
_jd_t_status 'shipped template: prepare, exit status' 0
_jd_t_eq 'shipped template: W0003 receives a copy' "$(cat "$_jd_t_shipped")" \
  "$(cat "$_JD_NEW_TASKS_TPL" 2>/dev/null)"
_jd_t_contains 'shipped template: prints that it copied' 'template copied to' "$JD_T_ERR"

# The copy is the user's file now. jd does not write to it again.
printf '[{"type":"project","attributes":{"title":"{{NAME}}"}}]\n' >"$_JD_NEW_TASKS_TPL"
_jd_t_run jd_tasks_prepare
_jd_t_status 'shipped template: a file that exists, exit status' 0
_jd_t_eq 'shipped template: a file that exists is not changed' \
  '[{"type":"project","attributes":{"title":"{{NAME}}"}}]' "$(cat "$_JD_NEW_TASKS_TPL")"
_jd_t_lacks 'shipped template: a file that exists, nothing is copied' \
  'template copied to' "$JD_T_ERR"

# Filled in, the copy is still JSON, whatever the title contains.
cp "$_jd_t_shipped" "$_JD_NEW_TASKS_TPL"
_JD_NEW_NUM=W0301
_JD_NEW_ID=21.35
_JD_NEW_TITLE='A "quoted" title \ with a backslash'
_JD_NEW_NAME="W0301~21.35 $_JD_NEW_TITLE"
_JD_NEW_NOTES_URL='obsidian://adv-uri?vault=D25%20JDex&block=w0301'
_JD_NEW_TASKS_URL=''
_jd_t_eq 'shipped template: filled in, the title is the name' "$_JD_NEW_NAME" \
  "$(_jd_things_payload 2>/dev/null | jq -r '.[0].attributes.title')"

# The task link is empty until Things has created the project, so the
# line that contains it is left out. The note link is there.
_jd_t_eq 'shipped template: an empty link, the line is left out' \
  "$(printf -- '- Related:\n\t- [Obsidian](%s)' "$_JD_NEW_NOTES_URL")" \
  "$(_jd_things_payload 2>/dev/null | jq -r '.[0].attributes.notes')"
_JD_NEW_TASKS_URL='things:///show?id=abc'
_jd_t_contains 'shipped template: with both links, both lines are there' \
  '[Things](things:///show?id=abc)' \
  "$(_jd_things_payload 2>/dev/null | jq -r '.[0].attributes.notes')"

# With no link at all, '- Related:' has nothing under it, so it is left
# out.
_JD_NEW_NOTES_URL=''
_JD_NEW_TASKS_URL=''
_jd_t_eq 'shipped template: no links, no Related heading' '' \
  "$(_jd_things_payload 2>/dev/null | jq -r '.[0].attributes.notes')"

# A heading is left out only when every line under it is left out. jd
# reads from the bottom up, so a heading over an empty heading is left
# out too. A line indented no further, or a blank line, ends what is
# under a heading.
_JD_NEW_PARENT_LINK=''
_jd_t_eq 'links: a heading over an empty heading is left out too' \
  "$(printf -- '- Kept')" \
  "$(_jd_new_links_json '"- A:\n\t- B:\n\t\t- [x]({{TASKS_URL}})\n- Kept"' | jq -r .)"
_jd_t_eq 'links: a heading with a line left under it stays' \
  "$(printf -- '- A:\n\t- B:\n\t\t- kept')" \
  "$(_jd_new_links_json '"- A:\n\t- B:\n\t\t- [x]({{TASKS_URL}})\n\t\t- kept"' | jq -r .)"
_jd_t_eq 'links: a line with nothing indented under it stays' \
  "$(printf -- '- A:\n- B')" \
  "$(_jd_new_links_json '"- A:\n- [x]({{TASKS_URL}})\n- B"' | jq -r .)"
_jd_t_eq 'links: a blank line ends what is under a heading' \
  "$(printf -- '\n\t\t- kept')" \
  "$(_jd_new_links_json '"\t- A:\n\t\t- [x]({{TASKS_URL}})\n\n\t\t- kept"' | jq -r .)"

# ------------------------------------------- the Advanced URI plugin
#
# The Obsidian link requires the plugin. If the JDex is a vault with no
# such plugin, jd prints a warning, and still creates the work package.

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_run jd new wp --dry-run --json 21.35 Not a vault
_jd_t_eq 'plugin: a JDex with no .obsidian folder, no warning' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"

mkdir -p "$JD_FX_JDEX/.obsidian/plugins"
_jd_t_run jd new wp --dry-run --json 21.35 No plugin
_jd_t_status 'plugin: a vault without it, exit status' 0
_jd_t_eq 'plugin: a vault without it, the warning' 'notes_plugin_missing' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_contains 'plugin: a vault without it, names the plugin' \
  'Advanced URI plugin' "$JD_T_ERR"

mkdir -p "$JD_FX_JDEX/.obsidian/plugins/obsidian-advanced-uri"
_jd_t_run jd new wp --dry-run --json 21.35 With the plugin
_jd_t_eq 'plugin: a vault with it, no warning' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"

# ------------------------------------------------ the 2.5 template keys

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new_oldkeys "$JD_T_TMP/oldkeys.json"
_jd_t_load "$JD_T_TMP/oldkeys.json"

_jd_t_run jd new wp --json 21.35 Old keys
_jd_t_status 'old keys: still creates the work package' 0
_jd_t_contains 'old keys: names noteTemplate' 'workPackages.noteTemplate' "$JD_T_ERR"
_jd_t_contains 'old keys: names folderTemplate' 'workPackages.folderTemplate' "$JD_T_ERR"
_jd_t_contains 'old keys: names tasks.template' 'workPackages.tasks.template' "$JD_T_ERR"
_jd_t_eq 'old keys: the warning is config_key_ignored' 'config_key_ignored' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_note=$(cat "$_jd_t_jw/W0301~21.35 Old keys.md" 2>/dev/null)
_jd_t_contains 'old keys: the W0003 template is used, not the old path' \
  '## Scope for W0301~21.35 Old keys' "$_jd_t_note"

# ------------------------------------------------------ a wrong adapter

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new_badadapter "$JD_T_TMP/bad.json"
_jd_t_load "$JD_T_TMP/bad.json"

_jd_t_run jd new wp 21.35 Bad adapter
_jd_t_status 'adapter: an adapter name with no file' 1
_jd_t_contains 'adapter: names the one it cannot find' \
  "no notes adapter named 'nosuchapp'" "$JD_T_ERR"
if [ -e "$_jd_t_fw/W0301~21.35 Bad adapter" ]; then
  _jd_t_bad 'adapter: creates nothing when the adapter does not load' 'no folder' 'a folder'
else
  _jd_t_ok 'adapter: creates nothing when the adapter does not load'
fi

# ------------------------------------------------------------- --json

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/json.json"
_jd_t_load "$JD_T_TMP/json.json"

# --peek, -n and -h were removed. Only the long flags are left.
_jd_t_run jd new --json -n wp 21.35 Short flag
_jd_t_eq 'short flags: -n is an unknown option' 'unknown_option' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'short flags: -n is named' "unknown option '-n'" "$JD_T_ERR"
_jd_t_run jd new -h
_jd_t_status 'short flags: -h is not help' 1

_jd_t_run jd new wp --json --peek
_jd_t_eq 'peek: is an unknown option' 'unknown_option' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# W0301, not a dry run. Every path the object names must exist.
_jd_t_run jd new wp --json 21.35 A JSON title
_jd_t_status 'json create: exit status' 0
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json create: parses'
else
  _jd_t_bad 'json create: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json create: ok is true' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
_jd_t_eq 'json create: the noun is wp' 'wp' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.noun')"
_jd_t_eq 'json create: dryRun is false' 'false' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.dryRun')"
_jd_t_eq 'json create: toFill is empty, the template has no tokens' '[]' \
  "$(printf '%s' "$JD_T_OUT" | jq -c '.toFill')"
_jd_t_eq 'json create: names the note template' \
  "$_jd_t_w3/Work package template.md" \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.template')"
_jd_t_note_path=$(printf '%s' "$JD_T_OUT" | jq -r '.note')
_jd_t_folder_path=$(printf '%s' "$JD_T_OUT" | jq -r '.folder')
if [ -f "$_jd_t_note_path" ]; then
  _jd_t_ok 'json create: the note path exists'
else
  _jd_t_bad 'json create: the note path exists' "$_jd_t_note_path" 'nothing'
fi
if [ -d "$_jd_t_folder_path" ]; then
  _jd_t_ok 'json create: the folder path exists'
else
  _jd_t_bad 'json create: the folder path exists' "$_jd_t_folder_path" 'nothing'
fi

# W0302 is next. --dry-run creates nothing, in JSON or not.
_jd_t_run jd new wp --dry-run --json 21.35 A dry run in JSON
_jd_t_status 'json dry run: exit status' 0
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json dry run: parses'
else
  _jd_t_bad 'json dry run: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json dry run: dryRun is true' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.dryRun')"
_jd_t_eq 'json dry run: still names the right num' 'W0302' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.num')"
if [ -e "$_jd_t_fw/W0302~21.35 A dry run in JSON" ]; then
  _jd_t_bad 'json dry run: creates nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'json dry run: creates nothing'
fi

_jd_t_run jd new wp --json banana A title
_jd_t_status 'json reject: a bad ID, exit status' 1
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json reject: parses'
else
  _jd_t_bad 'json reject: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json reject: ok is false' 'false' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
_jd_t_eq 'json reject: the code is not_an_id' 'not_an_id' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# A title with a literal double quote and a literal backslash in it. It
# is still W0302, since the dry run above created nothing and the bad ID
# above used no number.
_jd_t_title='A title with a " quote and a \ backslash'
_jd_t_run jd new wp --json 21.35 A title with a '"' quote and a '\' backslash
_jd_t_status 'json quoting: exit status' 0
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json quoting: parses'
else
  _jd_t_bad 'json quoting: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json quoting: the title contains the quote and the backslash' \
  "$_jd_t_title" "$(printf '%s' "$JD_T_OUT" | jq -r '.title')"

# ------------------------------------------------ two W0003 folders
#
# jd cannot determine which one contains the templates, so it exits
# with an error.

_jd_fx_reset
_jd_fx_build_templates
mkdir -p "$_jd_t_fw/W0003 A second one"

_jd_t_run jd new wp --json 21.35 Two template folders
_jd_t_status 'two W0003: exit status' 1
_jd_t_eq 'two W0003: the code is template_ambiguous' 'template_ambiguous' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
if [ -e "$_jd_t_fw/W0301~21.35 Two template folders" ]; then
  _jd_t_bad 'two W0003: creates nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'two W0003: creates nothing'
fi

# ---------------------------------------------------------- already exists
#
# The real scan always numbers past whatever is already on disk, so a
# normal call never reaches this guard - the same title twice is
# assigned the next free number, as 'twice' above shows. Only a race
# between the scan and the write reaches the guard. This test forces
# that race by fixing the number that _jd_new_next_number returns.
#
# A fixed function reaches _jd_new only in the shell it is defined in,
# and the program is another process. So this one test sources lib and
# calls _jd_nav here, the way bin/jd does.

_jd_fx_reset
_jd_fx_config_new "$JD_T_TMP/exists.json"
_jd_t_load "$JD_T_TMP/exists.json"
_jd_t_libs

printf 'note\n' >"$_jd_t_jw/W0301~21.35 Already there.md"
_jd_new_next_number() { printf 'W0301'; }

_jd_t_run _jd_nav D25 new wp --json 21.35 Already there
_jd_t_status 'exists: exit status' 1
_jd_t_eq 'exists: the code is exists' 'exists' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

unset -f _jd_new_next_number

# ------------------------------------------------------------- {{?TOKEN}}

_jd_fx_reset
_jd_fx_build_templates_tokens
_jd_fx_config_new "$JD_T_TMP/tokens.json"
_jd_t_load "$JD_T_TMP/tokens.json"

_jd_t_run jd new wp --json 21.35 A work package with tokens
_jd_t_status 'tokens: exit status' 0
_jd_t_note=$(cat "$_jd_t_jw/W0301~21.35 A work package with tokens.md" 2>/dev/null)
_jd_t_lacks 'tokens: no double braces are left in the note' '{{' "$_jd_t_note"
_jd_t_contains 'tokens: DELIVERABLE, with no value, becomes its brief' \
  'What we hand over' "$_jd_t_note"
_jd_t_eq 'tokens: the flags' '--scope,--deliverable' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.toFill | map(.flag) | join(",")')"
_jd_t_eq 'tokens: toFill names both, in order' 'SCOPE,DELIVERABLE' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.toFill | map(.token) | join(",")')"
_jd_t_eq 'tokens: the brief on SCOPE is empty' '' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.toFill[0].brief')"
_jd_t_eq 'tokens: the brief on DELIVERABLE is stored' 'What we hand over' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.toFill[1].brief')"

# Plain output, no --json: one 'to fill' line on stderr, naming both.
_jd_fx_reset
_jd_fx_build_templates_tokens
_jd_t_load "$JD_T_TMP/tokens.json"

_jd_t_run jd new wp 21.35 A second one with tokens --scope 'The whole thing'
_jd_t_status 'tokens plain: exit status' 0
_jd_t_contains 'tokens plain: names the flag that was not set' \
  'not set --deliverable, so the note has the brief' "$JD_T_ERR"
_jd_t_contains 'tokens plain: the value is in the note' 'The whole thing' \
  "$(cat "$_jd_t_jw/W0301~21.35 A second one with tokens.md" 2>/dev/null)"

# ------------------------------------------- a code on every failure
#
# An agent branches on 'code', so 'code' is never empty, even when the
# failure came from an adapter that has no code of its own.

_jd_fx_reset
_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_run jd new wp --json
_jd_t_status 'no id: exit status' 1
_jd_t_eq 'no id: the code is no_id' 'no_id' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# The 'none' task adapter passes its check and exits with an error on
# the refresh, so this is refresh_failed. The adapter printed the
# message, not new.sh, so the message field has a default value, not an
# empty one.
_jd_t_run jd new wp --json --refresh
_jd_t_status 'refresh with no task app: exit status' 1
_jd_t_eq 'refresh with no task app: the code is refresh_failed' \
  'refresh_failed' "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_eq 'refresh with no task app: the message is not empty' 'yes' \
  "$(printf '%s' "$JD_T_OUT" | jq -r 'if .message == "" then "no" else "yes" end')"
_jd_t_contains 'refresh with no task app: the adapter printed why on stderr' \
  'no task app is set for this system' "$JD_T_ERR"

# ------------------------------------------------------------------ beta
#
# 'jd new' was a beta feature up to 4.0.1. It is not one now: it creates
# a work package with beta off, and prints nothing about beta.

_jd_fx_reset
_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_eq 'beta off: the config has no beta key' 'null' "$(jq -r '.beta' "$JD_T_TMP/new.json")"
_jd_t_run jd new wp --json 21.35 Beta is off
_jd_t_status 'beta off: exit status' 0
_jd_t_eq 'beta off: the work package is created' 'W0301' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.num')"
_jd_t_lacks 'beta off: prints nothing about beta' 'beta' "$JD_T_ERR"

_jd_t_run jd new --help
_jd_t_lacks 'help: prints nothing about beta' 'beta' "$JD_T_OUT"
_jd_t_run jd new wp --help
_jd_t_lacks 'help wp: prints nothing about beta' 'beta' "$JD_T_OUT"
_jd_t_run jd new id --help
_jd_t_lacks 'help id: prints nothing about beta' 'beta' "$JD_T_OUT"

_jd_t_summary
