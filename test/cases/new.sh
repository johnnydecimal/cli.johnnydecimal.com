# SPDX-License-Identifier: MIT
# new.sh - jd new, which makes a work package
#
# The task app is never touched. Every config here leaves the tasks
# adapter out, so it is 'none', and the suite talks to no other program.
# The Things adapter is tested by hand, because it needs Things.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_build_templates
_jd_fx_config_new "$JD_T_TMP/new.json"
_jd_t_load "$JD_T_TMP/new.json"

_jd_t_jw="$JD_FX_JDEX/W0000-9999 Work packages"
_jd_t_fw="$JD_FX_ROOT/W0000-9999 Work packages"

# ------------------------------------------------------------------ help

_jd_t_run jd new --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' \
  'usage: <system> new <ID> <title>' "$JD_T_OUT"
_jd_t_contains 'help: says the title needs no quotes' \
  'The title needs no quotes.' "$JD_T_OUT"

_jd_t_run jd help
_jd_t_contains 'help: the main usage lists new' '<system> new 21.41' "$JD_T_OUT"

# --------------------------------------------------------------- dry run
#
# The JDex fixture holds W0300, and the filesystem fixture W0212, so the
# next free number is W0301.

_jd_t_run jd new -n 21.35 A dry run
_jd_t_status 'dry run: exit status' 0
_jd_t_contains 'dry run: names the next free number' \
  'W0301~21.35 A dry run' "$JD_T_ERR"
_jd_t_contains 'dry run: says it made nothing' 'nothing was made' "$JD_T_ERR"
_jd_t_at 'dry run: does not move us' "$JD_T_TMP"

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

_jd_t_run jd new 21.35 A real one, with '&' and a comma
_jd_t_status 'make: exit status' 0
_jd_t_name='W0301~21.35 A real one, with & and a comma'
_jd_t_at 'make: leaves us in the new folder' "$_jd_t_fw/$_jd_t_name"
_jd_t_eq 'make: prints the new folder' "$_jd_t_fw/$_jd_t_name" "$JD_T_OUT"

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
_jd_t_run jd new -n 21.35 The one after
_jd_t_contains 'make: the next number counts the one just made' \
  'W0302~21.35 The one after' "$JD_T_ERR"

# A number in an archive folder deeper in the tree is still used.
mkdir -p "$_jd_t_jw/W0009 Archive"
printf 'note\n' >"$_jd_t_jw/W0009 Archive/W0400~21.35 Archived.md"
_jd_t_run jd new -n 21.35 After the archive
_jd_t_contains 'make: a number in an archive folder is counted' \
  'W0401~21.35 After the archive' "$JD_T_ERR"
rm -rf "$_jd_t_jw/W0009 Archive"

# ---------------------------------------------------- a system function

_jd_t_run d25 new -n 21.35 By system name
_jd_t_status 'system function: exit status' 0
_jd_t_contains 'system function: d25 new works too' \
  '~21.35 By system name' "$JD_T_ERR"

# --------------------------------------------------------- what it refuses

_jd_t_run jd new banana A title
_jd_t_status 'refuse: a word that is not an ID' 1
_jd_t_contains 'refuse: says the first word must be an ID' \
  'the first word must be one' "$JD_T_ERR"

_jd_t_run jd new 21.35
_jd_t_status 'refuse: no title' 1
_jd_t_contains 'refuse: says a title is needed' 'needs a title' "$JD_T_ERR"

_jd_t_run jd new 21.35 a/b
_jd_t_status 'refuse: a title with a slash' 1
_jd_t_contains 'refuse: says why' "cannot hold '/'" "$JD_T_ERR"

_jd_t_run jd new --nonsense 21.35 A title
_jd_t_status 'refuse: an unknown option' 1
_jd_t_contains 'refuse: names the option' "unknown option '--nonsense'" "$JD_T_ERR"

_jd_t_run p76 new 31.11 No JDex here
_jd_t_status 'refuse: a system with no JDex' 1
_jd_t_contains 'refuse: says it needs a JDex' 'needs a jdex path' "$JD_T_ERR"

# The same title twice is not refused. Nothing about a work package is
# unique but its number, and the second one gets the next free number.
_jd_t_run jd new 21.35 A real one, with '&' and a comma
_jd_t_status 'twice: the same title again is allowed' 0
_jd_t_at 'twice: it gets the next free number' \
  "$_jd_t_fw/W0302~21.35 A real one, with & and a comma"

# ------------------------------------------------- no workPackages block
#
# A config that says nothing about work packages still makes one. The
# note is the built-in one, and no app is asked for a link.

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd new 21.35 No config for this
_jd_t_status 'no block: exit status' 0
_jd_t_note=$(cat "$_jd_t_jw/W0301~21.35 No config for this.md" 2>/dev/null)
_jd_t_contains 'no block: the built-in note is used' '## Work log' "$_jd_t_note"
_jd_t_contains 'no block: the permalink is still filled in' \
  '- ^w0301' "$_jd_t_note"
_jd_t_contains 'no block: the note app link is empty' '[Notes]()' "$_jd_t_note"
if [ -d "$_jd_t_fw/W0301~21.35 No config for this" ]; then
  _jd_t_ok 'no block: the folder is made, with nothing in it'
else
  _jd_t_bad 'no block: the folder is made, with nothing in it' 'a folder' 'nothing'
fi

# ------------------------------------------------------ a wrong adapter

_jd_fx_reset
_jd_fx_build_templates
_jd_fx_config_new_badadapter "$JD_T_TMP/bad.json"
_jd_t_load "$JD_T_TMP/bad.json"

_jd_t_run jd new 21.35 Bad adapter
_jd_t_status 'adapter: an adapter name with no file' 1
_jd_t_contains 'adapter: names the one it cannot find' \
  "no notes adapter named 'nosuchapp'" "$JD_T_ERR"
if [ -e "$_jd_t_fw/W0301~21.35 Bad adapter" ]; then
  _jd_t_bad 'adapter: makes nothing when it cannot start' 'no folder' 'a folder'
else
  _jd_t_ok 'adapter: makes nothing when it cannot start'
fi

_jd_t_summary
