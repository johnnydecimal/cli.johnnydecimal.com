# SPDX-License-Identifier: MIT
# nav-make-id.sh - an ID in the JDex but not in the filesystem
#
# 1.1.0 added this: ask for an ID that has a JDex entry but no folder and
# jd makes the folder, named from the JDex entry, then goes to it. 2.4.0
# does the same for a work package.
#
# These tests write to the fixture tree, so this case file is on its own
# and calls _jd_fx_reset when it is done making things.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

# 19.99 is in the JDex. Category 19 has no folder, so there is nowhere to
# put it and jd must say so rather than guess.
_jd_t_run jd 19.99
_jd_t_status 'make id: no category folder is an error' 1
_jd_t_contains 'make id: says the category is missing' \
  'the JDex has 19.99 but there is no folder for category 19' "$JD_T_ERR"
_jd_t_at 'make id: no category folder, so we do not move' "$JD_T_TMP"

# P76 has no jdex path, so there is nothing to make a name from.
_jd_t_run p76 39.99
_jd_t_status 'make id: no jdex path, so no match' 1
_jd_t_contains 'make id: falls back to the normal no-match error' \
  'no match for 39.99' "$JD_T_ERR"

# 12.99 is in the JDex, and category 12 has a folder.
_jd_t_run jd 12.99
_jd_t_status 'make id: exit status' 0
_jd_t_at 'make id: goes to the folder it made' \
  "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.99 Made by jd"
_jd_t_contains 'make id: says what it made' \
  'jd: created 12.99 Made by jd from the JDex' "$JD_T_ERR"
if [ -d "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.99 Made by jd" ]; then
  _jd_t_ok 'make id: the folder is really there'
else
  _jd_t_bad 'make id: the folder is really there' 'a directory' 'nothing'
fi

# The second time round the folder exists, so it is a plain match and
# nothing is made or said.
_jd_t_run jd 12.99
_jd_t_at 'make id: the second time it is just a match' \
  "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.99 Made by jd"
_jd_t_eq 'make id: the second time it says nothing' '' "$JD_T_ERR"

_jd_fx_reset

# ------------------------------------------------------- work packages
#
# 2.4.0 added this. A work package number does not say which area it is
# in, so the area comes from the JDex entry's parent folder.

# W0399 is in the JDex, in area 30-39. The filesystem has no 30-39.
_jd_t_run jd W0399
_jd_t_status 'make wp: no area folder is an error' 1
_jd_t_contains 'make wp: says the area is missing' \
  'the JDex has W0399 but there is no folder for area 30-39' "$JD_T_ERR"
_jd_t_at 'make wp: no area folder, so we do not move' "$JD_T_TMP"

# P76 has no jdex path, so there is nothing to make a name from.
_jd_t_run p76 W0399
_jd_t_status 'make wp: no jdex path, so no match' 1
_jd_t_contains 'make wp: falls back to the normal no-match error' \
  'no match for W0399' "$JD_T_ERR"

# W0300 is in the JDex, in area 20-29, and that area has a folder. The
# name carries a '~', which the JDex entry keeps and the folder does too.
_jd_t_run jd W0300
_jd_t_status 'make wp: exit status' 0
_jd_t_at 'make wp: goes to the folder it made' \
  "$JD_FX_ROOT/20-29 Area two/W0300~21.35 Made by jd"
_jd_t_contains 'make wp: says what it made' \
  'jd: created W0300~21.35 Made by jd from the JDex' "$JD_T_ERR"
if [ -d "$JD_FX_ROOT/20-29 Area two/W0300~21.35 Made by jd" ]; then
  _jd_t_ok 'make wp: the folder is really there'
else
  _jd_t_bad 'make wp: the folder is really there' 'a directory' 'nothing'
fi

# The second time round the folder exists, so it is a plain match and
# nothing is made or said.
_jd_t_run jd W0300
_jd_t_at 'make wp: the second time it is just a match' \
  "$JD_FX_ROOT/20-29 Area two/W0300~21.35 Made by jd"
_jd_t_eq 'make wp: the second time it says nothing' '' "$JD_T_ERR"

# A lowercase number finds the same JDex entry, and the folder keeps the
# name the JDex gave it.
_jd_fx_reset
_jd_t_run jd w0300
_jd_t_at 'make wp: a lowercase number makes the same folder' \
  "$JD_FX_ROOT/20-29 Area two/W0300~21.35 Made by jd"

# The JDex already holds the entry, so 'jdex W0300' is a plain match. It
# makes no folder in the filesystem.
_jd_fx_reset
_jd_t_run jdex W0300
_jd_t_status 'make wp: jdex mode exit status' 0
_jd_t_at 'make wp: jdex mode goes to the note folder' \
  "$JD_FX_JDEX/20-29 Area two"
if [ -d "$JD_FX_ROOT/20-29 Area two/W0300~21.35 Made by jd" ]; then
  _jd_t_bad 'make wp: jdex mode makes no folder' 'nothing' 'a directory'
else
  _jd_t_ok 'make wp: jdex mode makes no folder'
fi

_jd_fx_reset

_jd_t_summary
