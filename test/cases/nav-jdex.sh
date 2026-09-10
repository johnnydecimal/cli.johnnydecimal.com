# SPDX-License-Identifier: MIT
# nav-jdex.sh - the same targets, in the JDex instead of the filesystem
#
# In the JDex an ID is usually a note file, not a folder. jd cannot cd to
# a file, so it goes to the folder that holds it. Every test here checks
# that, because it is the one real difference between the two modes.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_fx_config_default_second "$JD_T_TMP/default-second.json"
_jd_fx_config_single_nosys "$JD_T_TMP/single-nosys.json"
_jd_fx_config_second_only "$JD_T_TMP/second-only.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd jdex
_jd_t_status 'jdex: exit status at the JDex root' 0
_jd_t_at 'jdex: goes to the JDex root' "$JD_FX_JDEX"

_jd_t_run jd jdex 20-29
_jd_t_at 'jdex: area 20-29' "$JD_FX_JDEX/20-29 Area two"

_jd_t_run jd jdex 22
_jd_t_at 'jdex: category 22' "$JD_FX_JDEX/20-29 Area two/22 Category twentytwo"

_jd_t_run jd jdex 22.
_jd_t_at 'jdex: category 22.' "$JD_FX_JDEX/20-29 Area two/22 Category twentytwo"

# The note is 11.11 First ID.md, so we land in its category folder.
_jd_t_run jd jdex 11.11
_jd_t_status 'jdex: exit status for an ID' 0
_jd_t_at 'jdex: an ID note lands in the folder that holds it' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven"

_jd_t_run jd jdex W0212
_jd_t_at 'jdex: a work package note lands in the folder that holds it' \
  "$JD_FX_JDEX/20-29 Area two"

_jd_t_run jd jdex travel
_jd_t_at 'jdex: word search' "$JD_FX_JDEX/10-19 Area one/11 Category eleven"

_jd_t_run jd jdex kettle
_jd_t_at 'jdex: word search finds a work package note' "$JD_FX_JDEX/20-29 Area two"

_jd_t_run jd jdex 21. tripsy
_jd_t_at 'jdex: search scoped to category 21' \
  "$JD_FX_JDEX/20-29 Area two/21 Category twentyone"

_jd_t_run jd jdex 20-29 tripsy
_jd_t_at 'jdex: search scoped to area 20-29' \
  "$JD_FX_JDEX/20-29 Area two/21 Category twentyone"

_jd_t_run jd jdex tripsy
_jd_t_status 'jdex: many matches exit 1' 1
_jd_t_at 'jdex: many matches, we do not move' "$JD_T_TMP"
_jd_t_contains 'jdex: many matches are counted' \
  "jd: 2 matches for 'tripsy':" "$JD_T_ERR"
_jd_t_contains 'jdex: many matches list the note file' \
  '11.13 Tripsy travel.md' "$JD_T_ERR"

_jd_t_run jd jdex zzznotathing
_jd_t_status 'jdex: no match is an error' 1
_jd_t_contains 'jdex: says what it looked for' \
  "no match for 'zzznotathing'" "$JD_T_ERR"

# P76 has no jdex path in the config.
_jd_t_run p76 jdex
_jd_t_status 'jdex: a system with no jdex path is an error' 1
_jd_t_contains 'jdex: says which system has no jdex path' \
  'no jdex path for P76' "$JD_T_ERR"
_jd_t_at 'jdex: a system with no jdex path does not move us' "$JD_T_TMP"

# ---------------------------------------------------- the jdex command
#
# jdex is a command of its own, next to jd. It is the JDex of the same
# system jd acts on, so every target above must answer the same way with
# the leading 'jd' dropped.

_jd_t_run jdex
_jd_t_status 'jdex command: exit status at the JDex root' 0
_jd_t_at 'jdex command: goes to the JDex root' "$JD_FX_JDEX"

_jd_t_run jdex 20-29
_jd_t_at 'jdex command: area 20-29' "$JD_FX_JDEX/20-29 Area two"

_jd_t_run jdex 22
_jd_t_at 'jdex command: category 22' \
  "$JD_FX_JDEX/20-29 Area two/22 Category twentytwo"

_jd_t_run jdex 11.11
_jd_t_at 'jdex command: an ID note lands in the folder that holds it' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven"

_jd_t_run jdex W0212
_jd_t_at 'jdex command: a work package' "$JD_FX_JDEX/20-29 Area two"

_jd_t_run jdex travel
_jd_t_at 'jdex command: word search' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven"

_jd_t_run jdex 20-29 tripsy
_jd_t_at 'jdex command: search scoped to area 20-29' \
  "$JD_FX_JDEX/20-29 Area two/21 Category twentyone"

_jd_t_run jdex tripsy
_jd_t_status 'jdex command: many matches exit 1' 1
_jd_t_at 'jdex command: many matches, we do not move' "$JD_T_TMP"

_jd_t_run jdex zzznotathing
_jd_t_status 'jdex command: no match is an error' 1
_jd_t_contains 'jdex command: says what it looked for' \
  "no match for 'zzznotathing'" "$JD_T_ERR"

# jd never enters the JDex twice. 'jdex jdex' is a word search for the
# word 'jdex', which nothing in the fixtures matches.
_jd_t_run jdex jdex
_jd_t_status 'jdex command: jdex jdex is a word search, not a second hop' 1
_jd_t_contains 'jdex command: jdex jdex says what it looked for' \
  "no match for 'jdex'" "$JD_T_ERR"

# The default system, not the first entry. D25 is the default here and
# it is second in the file.
_jd_t_load "$JD_T_TMP/default-second.json"
_jd_t_run jdex
_jd_t_at 'jdex command: follows default: true' "$JD_FX_JDEX"

# One system needs no default, and no sys.
_jd_t_load "$JD_T_TMP/single-nosys.json"
_jd_t_run jdex 11.11
_jd_t_at 'jdex command: one system with no sys' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven"

# P76 is the only system here, and it has no jdex path.
_jd_t_load "$JD_T_TMP/second-only.json"
_jd_t_run jdex
_jd_t_status 'jdex command: no jdex path is an error' 1
_jd_t_contains 'jdex command: says which system has no jdex path' \
  'no jdex path for P76' "$JD_T_ERR"
_jd_t_at 'jdex command: no jdex path does not move us' "$JD_T_TMP"

_jd_t_summary
