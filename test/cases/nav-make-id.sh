# SPDX-License-Identifier: MIT
# nav-make-id.sh - an ID in the JDex but not in the filesystem
#
# 1.1.0 added this: run jd with an ID that has a JDex entry but no
# folder, and jd creates the folder, named from the JDex entry, then cds
# to it. 2.4.0 does the same for a work package, in the W0000-9999 area.
#
# These tests write to the fixture tree, so this case file is on its own
# and calls _jd_fx_reset when it has finished creating folders.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

# 19.99 is in the JDex. Category 19 has no folder, so there is no folder
# to create it in, and jd must exit with an error.
_jd_t_run jd 19.99
_jd_t_status 'create id: no category folder is an error' 1
_jd_t_contains 'create id: prints that the category is missing' \
  'the JDex has 19.99 but there is no folder for category 19' "$JD_T_ERR"
_jd_t_at 'create id: no category folder, so the directory does not change' "$JD_T_TMP"

# P76 has no jdex path, so there is nothing to read a name from.
_jd_t_run p76 39.99
_jd_t_status 'create id: no jdex path, so no match' 1
_jd_t_contains 'create id: falls back to the normal no-match error' \
  'no match for 39.99' "$JD_T_ERR"

# 12.99 is in the JDex, and category 12 has a folder.
_jd_t_run jd 12.99
_jd_t_status 'create id: exit status' 0
_jd_t_at 'create id: cds to the folder it created' \
  "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.99 Made by jd"
_jd_t_contains 'create id: prints what it created' \
  'jd: created 12.99 Made by jd from the JDex' "$JD_T_ERR"
if [ -d "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.99 Made by jd" ]; then
  _jd_t_ok 'create id: the folder is really there'
else
  _jd_t_bad 'create id: the folder is really there' 'a directory' 'nothing'
fi

# The second time round the folder exists, so it is a plain match and
# nothing is created or printed.
_jd_t_run jd 12.99
_jd_t_at 'create id: the second time it is just a match' \
  "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.99 Made by jd"
_jd_t_eq 'create id: the second time it prints nothing' '' "$JD_T_ERR"

_jd_fx_reset

# ------------------------------------------------------- work packages
#
# 2.4.0 added this. A work package is always in the W0000-9999 area, so
# that is where jd creates its folder. 2.4.1 finds that area by the
# start of its number, not by its whole name.

# The filesystem has no W0000-9999 folder, so there is no folder to
# create it in.
rm -rf "$JD_FX_ROOT/W0000-9999 Work packages"
_jd_t_run jd W0300
_jd_t_status 'create wp: no work package area is an error' 1
_jd_t_contains 'create wp: prints that the area is missing' \
  'the JDex has W0300 but there is no folder for the W0000-9999 work package area' \
  "$JD_T_ERR"
_jd_t_at 'create wp: no work package area, so the directory does not change' "$JD_T_TMP"
_jd_fx_reset

# P76 has no jdex path, so there is nothing to read a name from.
_jd_t_run p76 W0300
_jd_t_status 'create wp: no jdex path, so no match' 1
_jd_t_contains 'create wp: falls back to the normal no-match error' \
  'no match for W0300' "$JD_T_ERR"

# W0300 is in the JDex and the W0000-9999 folder is there. The name
# contains a '~', and so does the folder name.
_jd_t_run jd W0300
_jd_t_status 'create wp: exit status' 0
_jd_t_at 'create wp: cds to the folder it created' \
  "$JD_FX_ROOT/W0000-9999 Work packages/W0300~21.35 Made by jd"
_jd_t_contains 'create wp: prints what it created' \
  'jd: created W0300~21.35 Made by jd from the JDex' "$JD_T_ERR"
if [ -d "$JD_FX_ROOT/W0000-9999 Work packages/W0300~21.35 Made by jd" ]; then
  _jd_t_ok 'create wp: the folder is really there'
else
  _jd_t_bad 'create wp: the folder is really there' 'a directory' 'nothing'
fi

# The second time round the folder exists, so it is a plain match and
# nothing is created or printed.
_jd_t_run jd W0300
_jd_t_at 'create wp: the second time it is just a match' \
  "$JD_FX_ROOT/W0000-9999 Work packages/W0300~21.35 Made by jd"
_jd_t_eq 'create wp: the second time it prints nothing' '' "$JD_T_ERR"

# A lowercase number finds the same JDex entry, and the folder has the
# name of the JDex entry.
_jd_fx_reset
_jd_t_run jd w0300
_jd_t_at 'create wp: a lowercase number creates the same folder' \
  "$JD_FX_ROOT/W0000-9999 Work packages/W0300~21.35 Made by jd"

# Only the start of the area number is matched, so a renamed area still
# works. This one has no '-9999' and a different title.
_jd_fx_reset
mv "$JD_FX_ROOT/W0000-9999 Work packages" "$JD_FX_ROOT/W0000 My work"
_jd_t_run jd W0300
_jd_t_at 'create wp: a renamed work package area still works' \
  "$JD_FX_ROOT/W0000 My work/W0300~21.35 Made by jd"
_jd_fx_reset

# The JDex already contains the entry, so 'jdex W0300' is a plain match.
# jd creates no folder in the filesystem.
_jd_t_run jdex W0300
_jd_t_status 'create wp: jdex mode exit status' 0
_jd_t_at 'create wp: jdex mode cds to the note folder' \
  "$JD_FX_JDEX/W0000-9999 Work packages"
if [ -d "$JD_FX_ROOT/W0000-9999 Work packages/W0300~21.35 Made by jd" ]; then
  _jd_t_bad 'create wp: jdex mode creates no folder' 'nothing' 'a directory'
else
  _jd_t_ok 'create wp: jdex mode creates no folder'
fi

_jd_fx_reset

_jd_t_summary
