# SPDX-License-Identifier: MIT
# nav-fs.sh - navigation in the filesystem, the default mode
#
# Every target the usage text lists: the system root, an area, a category
# both ways round, an ID, a work package, a word search, a search scoped
# to a category or an area, and the case where more than one thing
# matches and jd lists instead of entering.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

# ------------------------------------------------------------- the roots

_jd_t_run jd
_jd_t_status 'jd: exit status at the system root' 0
_jd_t_at 'jd: goes to the system root' "$JD_FX_ROOT"
_jd_t_eq 'jd: prints the system root' "$JD_FX_ROOT" "$JD_T_OUT"

_jd_t_run p76
_jd_t_at 'p76: goes to the second system root' "$JD_FX_ROOT2"

# ------------------------------------------------------------ area 20-29

_jd_t_run jd 20-29
_jd_t_status 'area: exit status' 0
_jd_t_at 'area: 20-29' "$JD_FX_ROOT/20-29 Area two"

# ------------------------------------------- category 22, and category 22.

_jd_t_run jd 22
_jd_t_at 'category: bare 22' "$JD_FX_ROOT/20-29 Area two/22 Category twentytwo"

_jd_t_run jd 22.
_jd_t_at 'category: dotted 22.' "$JD_FX_ROOT/20-29 Area two/22 Category twentytwo"

# --------------------------------------------------------------- ID 11.11

_jd_t_run jd 11.11
_jd_t_status 'id: exit status' 0
_jd_t_at 'id: 11.11' "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"
_jd_t_eq 'id: says nothing on stderr' '' "$JD_T_ERR"

# A folder named 11.11 that sits below an ID is too deep to be an ID.
_jd_t_run jd 11.12
_jd_t_at 'id: 11.12, not the 11.11 decoy inside it' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.12 Second ID"

_jd_t_run jd 11.11 extra
_jd_t_status 'id: words after an ID are an error' 1
_jd_t_contains 'id: says which ID the words followed' \
  "unexpected words after '11.11'" "$JD_T_ERR"

# --------------------------------------------------- work package W0189

_jd_t_run jd W0189
_jd_t_status 'work package: exit status' 0
_jd_t_at 'work package: W0189' "$JD_FX_ROOT/10-19 Area one/W0189 Work package one"

_jd_t_run jd w0189
_jd_t_at 'work package: lower case w0189' \
  "$JD_FX_ROOT/10-19 Area one/W0189 Work package one"

_jd_t_run jd W0189 extra
_jd_t_status 'work package: words after one are an error' 1

# ----------------------------------------------------------- word search

_jd_t_run jd travel
_jd_t_status 'word search: exit status for one match' 0
_jd_t_at 'word search: one match is entered' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.13 Tripsy travel"

_jd_t_run jd TRAVEL
_jd_t_at 'word search: ignores case' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.13 Tripsy travel"

_jd_t_run jd tripsy travel
_jd_t_at 'word search: two words must both match' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.13 Tripsy travel"

_jd_t_run jd zzznotathing
_jd_t_status 'word search: no match is an error' 1
_jd_t_contains 'word search: says what it looked for' \
  "no match for 'zzznotathing'" "$JD_T_ERR"

_jd_t_run jd 99.99
_jd_t_status 'id: no match is an error' 1
_jd_t_contains 'id: says which ID had no match' 'no match for 99.99' "$JD_T_ERR"

# --------------------------------------------------------- scoped search

_jd_t_run jd 21. tripsy
_jd_t_at 'scoped search: inside category 21.' \
  "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.11 Tripsy notes"

_jd_t_run jd 21 tripsy
_jd_t_at 'scoped search: inside bare category 21' \
  "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.11 Tripsy notes"

_jd_t_run jd 20-29 tripsy
_jd_t_at 'scoped search: inside area 20-29' \
  "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.11 Tripsy notes"

_jd_t_run jd 11 tripsy
_jd_t_at 'scoped search: the same word in another category' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.13 Tripsy travel"

_jd_t_run jd 22 tripsy
_jd_t_status 'scoped search: no match in that category is an error' 1
_jd_t_contains 'scoped search: names the category it searched' \
  "no match for 'tripsy' in category 22" "$JD_T_ERR"

# --------------------------------------------------------- awkward names

# '13 Odds & ends' holds the characters a shell minds. If any of them
# reached a shell unquoted, these would not just fail, they would run.
_jd_t_run jd 13
_jd_t_at 'awkward names: a category with an ampersand' \
  "$JD_FX_ROOT/10-19 Area one/13 Odds & ends"

_jd_t_run jd 13.11
_jd_t_at 'awkward names: an ID with a comma and an ampersand' \
  "$JD_FX_ROOT/10-19 Area one/13 Odds & ends/13.11 Bits, bobs & things"

_jd_t_run jd bobs
_jd_t_at 'awkward names: a word search inside one' \
  "$JD_FX_ROOT/10-19 Area one/13 Odds & ends/13.11 Bits, bobs & things"

# ---------------------------------------------------------- many matches

_jd_t_run jd tripsy
_jd_t_status 'many matches: exit status is 1' 1
_jd_t_at 'many matches: we do not move' "$JD_T_TMP"
_jd_t_eq 'many matches: nothing on stdout' '' "$JD_T_OUT"
_jd_t_contains 'many matches: counts them' "jd: 2 matches for 'tripsy':" "$JD_T_ERR"
_jd_t_contains 'many matches: lists the first, relative to the root' \
  '10-19 Area one/11 Category eleven/11.13 Tripsy travel' "$JD_T_ERR"
_jd_t_contains 'many matches: lists the second' \
  '20-29 Area two/21 Category twentyone/21.11 Tripsy notes' "$JD_T_ERR"
_jd_t_lacks 'many matches: the list is relative, not absolute' \
  "$JD_FX_ROOT/10-19" "$JD_T_ERR"

_jd_t_run jd widget
_jd_t_status 'many matches: widget too' 1
_jd_t_contains 'many matches: two widgets' "jd: 2 matches for 'widget':" "$JD_T_ERR"

# ------------------------------------------------------------- under set -u

# _jd_nav read $1 before it had checked there was one, so a bare jd died
# on an unbound variable instead of going to the system root. Every jd
# with an argument was fine, which is how the fault was found.
# Fixed in 2.0.5.
#
# A subshell, so the option does not escape into the harness. The cd stays
# in the subshell too, so these read the path jd prints, not $JD_T_PWD.
_jd_t_nounset_jd() ( set -u; jd "$@" )

_jd_t_run _jd_t_nounset_jd
_jd_t_eq 'bare jd works under set -u' "$JD_FX_ROOT" "$JD_T_OUT"
_jd_t_eq 'bare jd under set -u says nothing on stderr' '' "$JD_T_ERR"

_jd_t_run _jd_t_nounset_jd 11.11
_jd_t_eq 'jd with an argument works under set -u' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" "$JD_T_OUT"

_jd_t_run _jd_t_nounset_jd version
_jd_t_status 'jd version works under set -u' 0

_jd_t_run _jd_t_nounset_jd jdex 11.11
_jd_t_status 'jd jdex works under set -u' 0

_jd_t_summary
