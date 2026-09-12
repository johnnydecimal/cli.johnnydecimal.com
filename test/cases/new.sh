# SPDX-License-Identifier: MIT
# new.sh - jd new wp, which makes a work package, and what every
# 'jd new' shares: the noun, help, and the beta flag
#
# The task app is never touched. Every config here leaves the tasks
# adapter out, so it is 'none', and the suite talks to no other program.
# The Things adapter is tested by hand, because it needs Things.
#
# 'jd new id' has its own file, new-id.sh.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# 'jd new' is a beta feature. Every test runs with beta on, except the
# ones at the end that turn it off.
JD_BETA=1
export JD_BETA

_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_jw="$JD_FX_JDEX/W0000-9999 Work packages"
_jd_t_fw="$JD_FX_ROOT/W0000-9999 Work packages"
_jd_t_w3="$_jd_t_fw/W0003 Templates"

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
_jd_t_contains 'help wp: says the title needs no quotes' \
  'The title needs no quotes.' "$JD_T_OUT"
_jd_t_contains 'help wp: says where the templates are' 'W0003' "$JD_T_OUT"

_jd_t_run jd help
_jd_t_contains 'help: the main usage lists new wp' '<system> new wp 21.41' "$JD_T_OUT"
_jd_t_contains 'help: the main usage lists new id' '<system> new id 21' "$JD_T_OUT"

# ------------------------------------------------------------- the noun

_jd_t_run jd new --json
_jd_t_status 'noun: none, exit status' 1
_jd_t_eq 'noun: none, the code is no_noun' 'no_noun' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'noun: none, names the nouns' "'jd new id' or 'jd new wp'" "$JD_T_ERR"

# The 2.5 form, with no noun, is refused. It must not make a work package.
_jd_t_run jd new --json 21.35 The old form
_jd_t_status 'noun: the 2.5 form, exit status' 1
_jd_t_eq 'noun: the 2.5 form, the code is unknown_noun' 'unknown_noun' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'noun: the 2.5 form, names the nouns' "'jd new id' or 'jd new wp'" "$JD_T_ERR"
if [ -e "$_jd_t_fw/W0301~21.35 The old form" ]; then
  _jd_t_bad 'noun: the 2.5 form makes nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'noun: the 2.5 form makes nothing'
fi

_jd_t_run jd new banana 21.35 A title
_jd_t_status 'noun: an unknown word' 1
_jd_t_contains 'noun: says jd cannot make it' "cannot make 'banana'" "$JD_T_ERR"

# --------------------------------------------------------------- dry run
#
# The JDex fixture holds W0300, and the filesystem fixture W0212, so the
# next free number is W0301.

_jd_t_run jd new wp --dry-run 21.35 A dry run
_jd_t_status 'dry run: exit status' 0
_jd_t_contains 'dry run: names the next free number' \
  'W0301~21.35 A dry run' "$JD_T_ERR"
_jd_t_contains 'dry run: names the note template' \
  "$_jd_t_w3/Work package template.md" "$JD_T_ERR"
_jd_t_contains 'dry run: names the folder template' \
  "$_jd_t_w3/Work package template" "$JD_T_ERR"
_jd_t_contains 'dry run: says it made nothing' 'nothing was made' "$JD_T_ERR"
_jd_t_at 'dry run: does not move us' "$JD_T_TMP"

# A flag before the noun works too.
_jd_t_run jd new --dry-run wp 21.35 A dry run
_jd_t_status 'dry run: a flag before the noun, exit status' 0
_jd_t_contains 'dry run: a flag before the noun still makes nothing' \
  'nothing was made' "$JD_T_ERR"

if [ -e "$_jd_t_fw/W0301~21.35 A dry run" ]; then
  _jd_t_bad 'dry run: makes no folder' 'no folder' 'a folder'
else
  _jd_t_ok 'dry run: makes no folder'
fi
if [ -e "$_jd_t_jw/W0301~21.35 A dry run.md" ]; then
  _jd_t_bad 'dry run: makes no note' 'no note' 'a note'
else
  _jd_t_ok 'dry run: makes no note'
fi

# ------------------------------------------------------------- making one

_jd_t_run jd new wp 21.35 A real one, with '&' and a comma
_jd_t_status 'make: exit status' 0
_jd_t_name='W0301~21.35 A real one, with & and a comma'
_jd_t_at 'make: leaves us in the new folder' "$_jd_t_fw/$_jd_t_name"
_jd_t_eq 'make: prints the new folder' "$_jd_t_fw/$_jd_t_name" "$JD_T_OUT"
_jd_t_lacks 'make: says nothing about a missing template' 'no template' "$JD_T_ERR"

if [ -d "$_jd_t_fw/$_jd_t_name" ]; then
  _jd_t_ok 'make: the folder is there'
else
  _jd_t_bad 'make: the folder is there' "$_jd_t_fw/$_jd_t_name" 'nothing'
fi
if [ -d "$_jd_t_fw/$_jd_t_name/05 Planning" ]; then
  _jd_t_ok 'make: the template folders are copied in'
else
  _jd_t_bad 'make: the template folders are copied in' '05 Planning' 'nothing'
fi
if [ -f "$_jd_t_fw/$_jd_t_name/05 Planning/a file.txt" ]; then
  _jd_t_ok 'make: a file in a template folder comes too'
else
  _jd_t_bad 'make: a file in a template folder comes too' 'a file.txt' 'nothing'
fi
if [ -e "$_jd_t_fw/$_jd_t_name/.DS_Store" ]; then
  _jd_t_bad 'make: .DS_Store is left behind' 'no .DS_Store' 'a .DS_Store'
else
  _jd_t_ok 'make: .DS_Store is left behind'
fi
if [ -e "$_jd_t_fw/$_jd_t_name/Work package template" ]; then
  _jd_t_bad 'make: the template folder itself is not copied in' \
    'its contents only' 'the folder'
else
  _jd_t_ok 'make: the template folder itself is not copied in'
fi

_jd_t_note=$(cat "$_jd_t_jw/$_jd_t_name.md" 2>/dev/null)
_jd_t_contains 'make: the note has the permalink' '- ^w0301' "$_jd_t_note"
_jd_t_contains 'make: the note has the Obsidian link' \
  '[Obsidian](obsidian://adv-uri?vault=D25%20JDex&block=w0301)' "$_jd_t_note"
_jd_t_contains 'make: the note has an empty task link' \
  '[Things]()' "$_jd_t_note"
_jd_t_contains 'make: the note has the whole name in it' \
  "## Scope for $_jd_t_name" "$_jd_t_note"
_jd_t_lacks 'make: no placeholder is left in the note' '{{' "$_jd_t_note"

# The work package is now in both trees, so the next one is W0302.
_jd_t_run jd new wp --dry-run 21.35 The one after
_jd_t_contains 'make: the next number counts the one just made' \
  'W0302~21.35 The one after' "$JD_T_ERR"

# A number in the JDex archive, W0009, is still used.
mkdir -p "$_jd_t_jw/W0009 Archive"
printf 'note\n' >"$_jd_t_jw/W0009 Archive/W0400~21.35 Archived.md"
_jd_t_run jd new wp --dry-run 21.35 After the archive
_jd_t_contains 'make: a number in the archive is counted' \
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
_jd_t_contains 'make: the filesystem and deep names are not counted' \
  'W0302~21.35 Past the decoys' "$JD_T_ERR"
rm -rf "$_jd_t_fw/W0500 Only in the filesystem" "$_jd_t_jw/W0100 A folder note" \
  "$_jd_t_jw/W0009 Archive"

# A folder with the next number, and no JDex entry: jd makes no second one.
mkdir -p "$_jd_t_fw/W0302 An old folder"
_jd_t_run jd new wp --json 21.35 Onto a folder
_jd_t_eq 'make: a folder with the next number, the code is folder_exists' \
  'folder_exists' "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
rm -rf "$_jd_t_fw/W0302 An old folder"

# Flags after the title.
_jd_t_run jd new wp 21.35 Flags at the end --dry-run
_jd_t_contains 'make: --dry-run after the title makes nothing' 'nothing was made' "$JD_T_ERR"
_jd_t_contains 'make: the title stops before --dry-run' 'W0302~21.35 Flags at the end' "$JD_T_ERR"

_jd_t_run jd new wp --json 21.35 --refresh
_jd_t_eq 'make: --refresh with an ID is refused' 'unknown_option' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# ---------------------------------------------------- a system function

_jd_t_run d25 new wp --dry-run 21.35 By system name
_jd_t_status 'system function: exit status' 0
_jd_t_contains 'system function: d25 new wp works too' \
  '~21.35 By system name' "$JD_T_ERR"

# --------------------------------------------------------- what it refuses

_jd_t_run jd new wp banana A title
_jd_t_status 'refuse: a word that is not an ID' 1
_jd_t_contains 'refuse: says the first word must be an ID' \
  'the first word must be one' "$JD_T_ERR"

_jd_t_run jd new wp 21
_jd_t_status 'refuse: a category is not enough for a work package' 1

_jd_t_run jd new wp 21.35
_jd_t_status 'refuse: no title' 1
_jd_t_contains 'refuse: says a title is needed' 'needs a title' "$JD_T_ERR"

_jd_t_run jd new wp 21.35 a/b
_jd_t_status 'refuse: a title with a slash' 1
_jd_t_contains 'refuse: says why' "cannot hold '/'" "$JD_T_ERR"

_jd_t_run jd new wp --nonsense 21.35 A title
_jd_t_status 'refuse: an unknown option' 1
_jd_t_contains 'refuse: names the option' "unknown option '--nonsense'" "$JD_T_ERR"

_jd_t_run p76 new wp 31.11 No JDex here
_jd_t_status 'refuse: a system with no JDex' 1
_jd_t_contains 'refuse: says it needs a JDex' 'needs a jdex path' "$JD_T_ERR"

# The same title twice is not refused. Nothing about a work package is
# unique but its number, and the second one gets the next free number.
_jd_t_run jd new wp 21.35 A real one, with '&' and a comma
_jd_t_status 'twice: the same title again is allowed' 0
_jd_t_at 'twice: it gets the next free number' \
  "$_jd_t_fw/W0302~21.35 A real one, with & and a comma"

# ------------------------------------------------------- no templates
#
# No W0003 folder, and no workPackages block. A work package is still
# made: a blank note, an empty folder, and no app is asked for a link.
# jd says it found no template.

_jd_fx_reset
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd new wp --json 21.35 No templates for this
_jd_t_status 'no templates: exit status' 0
_jd_t_note_path="$_jd_t_jw/W0301~21.35 No templates for this.md"
if [ -f "$_jd_t_note_path" ]; then
  _jd_t_ok 'no templates: the note is made'
else
  _jd_t_bad 'no templates: the note is made' "$_jd_t_note_path" 'nothing'
fi
_jd_t_eq 'no templates: the note is blank' '' "$(cat "$_jd_t_note_path" 2>/dev/null)"
_jd_t_contains 'no templates: says it found no template' \
  'no work package template' "$JD_T_ERR"
_jd_t_contains 'no templates: says the note is blank' 'blank' "$JD_T_ERR"
_jd_t_eq 'no templates: the warning is no_template' 'no_template' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.warnings | join(",")')"
_jd_t_eq 'no templates: ok is still true' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
if [ -d "$_jd_t_fw/W0301~21.35 No templates for this" ]; then
  _jd_t_ok 'no templates: the folder is made'
else
  _jd_t_bad 'no templates: the folder is made' 'a folder' 'nothing'
fi
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

# ------------------------------------------------ the 2.5 template keys

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new_oldkeys "$JD_T_TMP/oldkeys.json"
_jd_t_load "$JD_T_TMP/oldkeys.json"

_jd_t_run jd new wp --json 21.35 Old keys
_jd_t_status 'old keys: still makes the work package' 0
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
  _jd_t_bad 'adapter: makes nothing when it cannot start' 'no folder' 'a folder'
else
  _jd_t_ok 'adapter: makes nothing when it cannot start'
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

# W0301, made for real. Every path the object names must exist.
_jd_t_run jd new wp --json 21.35 A JSON title
_jd_t_status 'json make: exit status' 0
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json make: parses'
else
  _jd_t_bad 'json make: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json make: ok is true' 'true' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
_jd_t_eq 'json make: the noun is wp' 'wp' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.noun')"
_jd_t_eq 'json make: dryRun is false' 'false' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.dryRun')"
_jd_t_eq 'json make: toFill is empty, the template has no tokens' '[]' \
  "$(printf '%s' "$JD_T_OUT" | jq -c '.toFill')"
_jd_t_eq 'json make: names the note template' \
  "$_jd_t_w3/Work package template.md" \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.template')"
_jd_t_note_path=$(printf '%s' "$JD_T_OUT" | jq -r '.note')
_jd_t_folder_path=$(printf '%s' "$JD_T_OUT" | jq -r '.folder')
if [ -f "$_jd_t_note_path" ]; then
  _jd_t_ok 'json make: the note path exists'
else
  _jd_t_bad 'json make: the note path exists' "$_jd_t_note_path" 'nothing'
fi
if [ -d "$_jd_t_folder_path" ]; then
  _jd_t_ok 'json make: the folder path exists'
else
  _jd_t_bad 'json make: the folder path exists' "$_jd_t_folder_path" 'nothing'
fi

# W0302 is next. -n makes nothing, in JSON or not.
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
  _jd_t_bad 'json dry run: makes nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'json dry run: makes nothing'
fi

_jd_t_run jd new wp --json banana A title
_jd_t_status 'json refuse: a bad ID, exit status' 1
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json refuse: parses'
else
  _jd_t_bad 'json refuse: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json refuse: ok is false' 'false' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.ok')"
_jd_t_eq 'json refuse: the code is not_an_id' 'not_an_id' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# A title with a literal double quote and a literal backslash in it. It
# is still W0302, since the dry run above made nothing and the bad ID
# above used no number.
_jd_t_title='A title with a " quote and a \ backslash'
_jd_t_run jd new wp --json 21.35 A title with a '"' quote and a '\' backslash
_jd_t_status 'json quoting: exit status' 0
if printf '%s' "$JD_T_OUT" | jq -e . >/dev/null 2>&1; then
  _jd_t_ok 'json quoting: parses'
else
  _jd_t_bad 'json quoting: parses' 'valid JSON' "$JD_T_OUT"
fi
_jd_t_eq 'json quoting: the title survives the quote and the backslash' \
  "$_jd_t_title" "$(printf '%s' "$JD_T_OUT" | jq -r '.title')"

# ------------------------------------------------ two W0003 folders
#
# jd cannot tell which one holds the templates, so it stops.

_jd_fx_reset
_jd_fx_build_templates
mkdir -p "$_jd_t_fw/W0003 A second one"

_jd_t_run jd new wp --json 21.35 Two template folders
_jd_t_status 'two W0003: exit status' 1
_jd_t_eq 'two W0003: the code is template_ambiguous' 'template_ambiguous' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
if [ -e "$_jd_t_fw/W0301~21.35 Two template folders" ]; then
  _jd_t_bad 'two W0003: makes nothing' 'no folder' 'a folder'
else
  _jd_t_ok 'two W0003: makes nothing'
fi

# ---------------------------------------------------------- already exists
#
# The real scan always numbers past whatever is already on disk, so a
# normal call never reaches this guard - the same title twice just gets
# the next free number, as 'twice' above shows. The only way in is a
# race between the scan and the write, which this forces by fixing the
# number that _jd_new_next_number returns.
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
_jd_t_eq 'tokens: the brief on DELIVERABLE is kept' 'What we hand over' \
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
# An agent branches on 'code', so it is never empty, even when the
# failure came from an adapter that knows no code of its own.

_jd_fx_reset
_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_run jd new wp --json
_jd_t_status 'no id: exit status' 1
_jd_t_eq 'no id: the code is no_id' 'no_id' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

# The 'none' task adapter passes its check and refuses the refresh, so
# this is refresh_failed. The adapter printed the message, not new.sh,
# so the message field falls back rather than staying empty.
_jd_t_run jd new wp --json --refresh
_jd_t_status 'refresh with no task app: exit status' 1
_jd_t_eq 'refresh with no task app: the code is refresh_failed' \
  'refresh_failed' "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_eq 'refresh with no task app: the message is not empty' 'yes' \
  "$(printf '%s' "$JD_T_OUT" | jq -r 'if .message == "" then "no" else "yes" end')"
_jd_t_contains 'refresh with no task app: the adapter said why on stderr' \
  'no task app is set for this system' "$JD_T_ERR"

# ------------------------------------------------------------------ beta

_jd_fx_reset
_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"
unset JD_BETA

_jd_t_run jd new wp --json 21.35 Beta is off
_jd_t_status 'beta off: exit status' 1
_jd_t_eq 'beta off: the code is beta_off' 'beta_off' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"
_jd_t_contains 'beta off: says how to turn it on' "jd beta on" "$JD_T_ERR"
_jd_t_contains 'beta off: warns' 'BETA FEATURES ARE UNSTABLE AND MODIFY YOUR DATA' "$JD_T_ERR"
_jd_t_lacks 'beta off: the JSON message stays one line, with no warning' 'UNSTABLE' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.message')"

# Beta comes first. With beta off, a missing noun is still beta_off.
_jd_t_run jd new --json
_jd_t_eq 'beta off: before the noun is read' 'beta_off' \
  "$(printf '%s' "$JD_T_OUT" | jq -r '.code')"

_jd_t_run jd new --help
_jd_t_status 'beta off: help still works' 0
_jd_t_run jd new wp --help
_jd_t_status 'beta off: help for a noun still works' 0

jq '{version} + {beta: true} + del(.version)' "$JD_T_TMP/new.json" \
  >"$JD_T_TMP/beta.json"
_jd_t_load "$JD_T_TMP/beta.json"
_jd_t_run jd new wp --dry-run 21.35 Beta in the config
_jd_t_status 'beta in the config: turns it on' 0

JD_BETA=1
export JD_BETA

_jd_t_summary
