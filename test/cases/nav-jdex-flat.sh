# SPDX-License-Identifier: MIT
# nav-jdex-flat.sh - navigation in a flat JDex, which has no area
# folders: every ID note is in its root (#20)

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build

# The flat JDex:
#   21.11 Tripsy notes.md, 21.12 Tripsy flights.md, 22.11 Widget one.md
#   22.12 Folder note/22.12 Folder note.md   an ID that is a folder note
#   W0212~21.35 Kettle rebuild.md            a work package in the root
#   W0000-9999 Work packages/W0300~21.35 Made by jd.md
_jd_t_flat="$JD_T_TMP/flat jdex"
mkdir -p "$_jd_t_flat/22.12 Folder note" "$_jd_t_flat/W0000-9999 Work packages"
for _jd_t_flatnote in '21.11 Tripsy notes' '21.12 Tripsy flights' '22.11 Widget one' 'W0212~21.35 Kettle rebuild'; do
  _jd_fx_note "$_jd_t_flat/$_jd_t_flatnote.md"
done
_jd_fx_note "$_jd_t_flat/22.12 Folder note/22.12 Folder note.md"
_jd_fx_note "$_jd_t_flat/W0000-9999 Work packages/W0300~21.35 Made by jd.md"

_jd_t_nested=$JD_FX_JDEX
JD_FX_JDEX=$_jd_t_flat
_jd_fx_config_two "$JD_T_TMP/flat.json"
JD_FX_JDEX=$_jd_t_nested
_jd_t_load "$JD_T_TMP/flat.json"

_jd_t_run jdex 21.11
_jd_t_status 'id: exit status' 0
_jd_t_at 'id: goes to the root, which contains the note' "$_jd_t_flat"

_jd_t_run jdex 22.12
_jd_t_at 'id: a folder note goes to its folder' "$_jd_t_flat/22.12 Folder note"

_jd_t_run jdex 21.99
_jd_t_status 'id: a missing ID, exit status' 1
_jd_t_contains 'id: a missing ID is no match' 'no match for 21.99' "$JD_T_ERR"

_jd_t_run jdex 21
_jd_t_at 'category: goes to the root' "$_jd_t_flat"
_jd_t_run jdex 37
_jd_t_contains 'category: a category with no note is no match' 'no match for category 37' "$JD_T_ERR"

_jd_t_run jdex 20-29
_jd_t_at 'area: goes to the root' "$_jd_t_flat"
_jd_t_run jdex 30-39
_jd_t_contains 'area: an area with no note is no match' 'no match for area 30-39' "$JD_T_ERR"

_jd_t_run jdex W0212
_jd_t_at 'wp: a work package in the root' "$_jd_t_flat"
_jd_t_run jdex W0300
_jd_t_at 'wp: a work package in the W0000 folder' "$_jd_t_flat/W0000-9999 Work packages"

_jd_t_run jdex 21 flights
_jd_t_at 'search in a category: one match' "$_jd_t_flat"
_jd_t_run jdex 22 tripsy
_jd_t_contains 'search in a category: only that category' "no match for 'tripsy' in category 22" "$JD_T_ERR"
_jd_t_run jdex 20-29 widget
_jd_t_at 'search in an area: one match' "$_jd_t_flat"

_jd_t_run jdex tripsy
_jd_t_status 'search: two matches, exit status' 1
_jd_t_contains 'search: lists the first' '21.11 Tripsy notes.md' "$JD_T_ERR"
_jd_t_contains 'search: lists the second' '21.12 Tripsy flights.md' "$JD_T_ERR"
_jd_t_run jdex kettle
_jd_t_at 'search: a work package' "$_jd_t_flat"
_jd_t_run jdex made
_jd_t_at 'search: a work package in the W0000 folder' "$_jd_t_flat/W0000-9999 Work packages"
_jd_t_run jdex work
_jd_t_contains 'search: the W0000 folder is not a work package' "no match for 'work'" "$JD_T_ERR"

# An ID in the JDex with no folder: jd creates the folder from the note's
# name, in the filesystem's category.
_jd_t_run jd 21.12
_jd_t_status 'create id: exit status' 0
_jd_t_at 'create id: from a flat JDex' \
  "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.12 Tripsy flights"
_jd_fx_reset

_jd_t_summary
