# SPDX-License-Identifier: MIT
# tree.sh - the match list, when a search finds more than one thing
#
# jd draws the list as a tree. Each match sits under the folder that
# holds it, and that folder is named once however many matches are in
# it. The area is not shown: the ID number already says which area it
# is in.
#
# _jd_nav_tree reads paths on stdin, relative to the system root, so
# most of this drives it directly. The tests through jd prove the two
# are wired together.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

# ------------------------------------------------------------- through jd

# Two matches in two categories. One branch each, and the last one closes.
_jd_t_run jd tripsy
_jd_t_expect=$(printf '%s\n' \
  "jd: 2 matches for 'tripsy':" \
  '  ├─ 11 Category eleven' \
  '  │  └─ 11.13 Tripsy travel' \
  '  └─ 21 Category twentyone' \
  '     └─ 21.11 Tripsy notes')
_jd_t_eq 'tree: two matches, two categories' "$_jd_t_expect" "$JD_T_ERR"
_jd_t_status 'tree: many matches still exit 1' 1
_jd_t_at 'tree: many matches still do not move us' "$JD_T_TMP"
_jd_t_eq 'tree: nothing on stdout' '' "$JD_T_OUT"

# Two matches in one category. The category is named once.
_jd_t_run jd widget
_jd_t_expect=$(printf '%s\n' \
  "jd: 2 matches for 'widget':" \
  '  └─ 22 Category twentytwo' \
  '     ├─ 22.11 Widget one' \
  '     └─ 22.12 Widget two')
_jd_t_eq 'tree: two matches, one category' "$_jd_t_expect" "$JD_T_ERR"

# The JDex holds notes, so the list holds note names.
_jd_t_run jd jdex tripsy
_jd_t_expect=$(printf '%s\n' \
  "jd: 2 matches for 'tripsy':" \
  '  ├─ 11 Category eleven' \
  '  │  └─ 11.13 Tripsy travel.md' \
  '  └─ 21 Category twentyone' \
  '     └─ 21.11 Tripsy notes.md')
_jd_t_eq 'tree: the JDex lists notes' "$_jd_t_expect" "$JD_T_ERR"

# The area is gone from the list, and so is the absolute path.
_jd_t_run jd tripsy
_jd_t_lacks 'tree: the area is not in the list' '10-19 Area one' "$JD_T_ERR"
_jd_t_lacks 'tree: the list is relative, not absolute' \
  "$JD_FX_ROOT/10-19" "$JD_T_ERR"

# ------------------------------------------------- _jd_nav_tree by itself

# A work package sits in an area, not a category, so its path is one
# part shorter. It gets the same two levels: holder, then match.
_jd_t_out=$(printf '%s\n' \
  '10-19 Area one/11 Category eleven/11.11 First ID' \
  '20-29 Area two/W0212~21.35 Kettle rebuild' | _jd_nav_tree)
_jd_t_expect=$(printf '%s\n' \
  '  ├─ 11 Category eleven' \
  '  │  └─ 11.11 First ID' \
  '  └─ 20-29 Area two' \
  '     └─ W0212~21.35 Kettle rebuild')
_jd_t_eq 'tree: a work package shows its area' "$_jd_t_expect" "$_jd_t_out"

# Three in one holder: two branches, then the close.
_jd_t_out=$(printf '%s\n' \
  '10-19 Area one/11 Category eleven/11.11 First ID' \
  '10-19 Area one/11 Category eleven/11.12 Second ID' \
  '10-19 Area one/11 Category eleven/11.13 Tripsy travel' | _jd_nav_tree)
_jd_t_expect=$(printf '%s\n' \
  '  └─ 11 Category eleven' \
  '     ├─ 11.11 First ID' \
  '     ├─ 11.12 Second ID' \
  '     └─ 11.13 Tripsy travel')
_jd_t_eq 'tree: three in one holder' "$_jd_t_expect" "$_jd_t_out"

# An upright bar runs down every holder that still has one to come.
_jd_t_out=$(printf '%s\n' \
  '10-19 Area one/11 Category eleven/11.11 First ID' \
  '10-19 Area one/11 Category eleven/11.12 Second ID' \
  '20-29 Area two/21 Category twentyone/21.11 Tripsy notes' | _jd_nav_tree)
_jd_t_expect=$(printf '%s\n' \
  '  ├─ 11 Category eleven' \
  '  │  ├─ 11.11 First ID' \
  '  │  └─ 11.12 Second ID' \
  '  └─ 21 Category twentyone' \
  '     └─ 21.11 Tripsy notes')
_jd_t_eq 'tree: the bar runs past the ones still to come' \
  "$_jd_t_expect" "$_jd_t_out"

# A path with nothing above the match, which an area search gives.
_jd_t_out=$(printf '%s\n' '10-19 Area one' '20-29 Area two' | _jd_nav_tree)
_jd_t_expect=$(printf '%s\n' \
  '  ├─ 10-19 Area one' \
  '  └─ 20-29 Area two')
_jd_t_eq 'tree: a match with no holder stands on its own' \
  "$_jd_t_expect" "$_jd_t_out"

# The names hold the characters a shell minds. Nothing is eaten.
_jd_t_out=$(printf '%s\n' \
  '10-19 Area one/13 Odds & ends/13.11 Bits, bobs & things' \
  "20-29 Area two/21 Category twentyone/21.35 Johnny's title" | _jd_nav_tree)
_jd_t_expect=$(printf '%s\n' \
  '  ├─ 13 Odds & ends' \
  '  │  └─ 13.11 Bits, bobs & things' \
  '  └─ 21 Category twentyone' \
  "     └─ 21.35 Johnny's title")
_jd_t_eq 'tree: awkward names come through whole' \
  "$_jd_t_expect" "$_jd_t_out"

# ------------------------------------------------------------ without awk

# awk draws the tree. On a machine with no awk the list still prints,
# plain, the way it did before 2.1.0.
_jd_t_noawk="$JD_T_TMP/noawk-bin"
mkdir -p "$_jd_t_noawk"
for _jd_t_cmd in cat sed grep sort find; do
  _jd_t_src=$(command -v "$_jd_t_cmd" 2>/dev/null) || continue
  [ -n "$_jd_t_src" ] && ln -sf "$_jd_t_src" "$_jd_t_noawk/$_jd_t_cmd"
done

_jd_t_path=$PATH
PATH=$_jd_t_noawk
export PATH
_jd_t_out=$(printf '%s\n' \
  '10-19 Area one/11 Category eleven/11.11 First ID' \
  '20-29 Area two/21 Category twentyone/21.11 Tripsy notes' | _jd_nav_tree)
PATH=$_jd_t_path
export PATH

_jd_t_expect=$(printf '%s\n' \
  '  10-19 Area one/11 Category eleven/11.11 First ID' \
  '  20-29 Area two/21 Category twentyone/21.11 Tripsy notes')
_jd_t_eq 'tree: with no awk the list still prints' \
  "$_jd_t_expect" "$_jd_t_out"

_jd_t_summary
