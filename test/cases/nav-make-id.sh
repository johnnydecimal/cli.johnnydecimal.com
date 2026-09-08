# SPDX-License-Identifier: MIT
# nav-make-id.sh - an ID in the JDex but not in the filesystem
#
# 1.1.0 added this: ask for an ID that has a JDex entry but no folder and
# jd makes the folder, named from the JDex entry, then goes to it.
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

_jd_t_summary
