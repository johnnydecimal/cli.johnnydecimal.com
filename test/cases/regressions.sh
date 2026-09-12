# SPDX-License-Identifier: MIT
# regressions.sh - one test for every bug the changelog says is fixed
#
# Each block names the release that fixed it. If a block goes red, that
# release has come undone. Read CHANGELOG.md for the story behind each.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_fx_config_single_nosys "$JD_T_TMP/single-nosys.json"
_jd_fx_config_multi_nosys "$JD_T_TMP/multi-nosys.json"

# ============================================================== 2.0.4
# A work package is normally named 'W0212~21.35 Some title'. The direct
# lookup matched only 'W0212' and 'W0212 *', and the word search needed a
# space after the number, so neither found the normal form.

_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd W0212
_jd_t_status '2.0.4: exit status for a tilde work package' 0
_jd_t_at '2.0.4: jd W0212 finds W0212~21.35 Kettle rebuild' \
  "$JD_FX_ROOT/20-29 Area two/W0212~21.35 Kettle rebuild"
_jd_t_eq '2.0.4: jd W0212 says nothing on stderr' '' "$JD_T_ERR"

_jd_t_run jd kettle
_jd_t_status '2.0.4: exit status for the word search' 0
_jd_t_at '2.0.4: the word search finds a tilde work package' \
  "$JD_FX_ROOT/20-29 Area two/W0212~21.35 Kettle rebuild"

_jd_t_run jd rebuild
_jd_t_at '2.0.4: a word from the title after the tilde' \
  "$JD_FX_ROOT/20-29 Area two/W0212~21.35 Kettle rebuild"

_jd_t_run jd jdex W0212
_jd_t_at '2.0.4: the JDex note for a tilde work package' \
  "$JD_FX_JDEX/20-29 Area two"

# Extend-the-ends stay out. 'W0212+ Kettle child' sits beside the real
# one and carries the same word, so both the lookup and the word search
# would find two things if the fix had gone too wide.
_jd_t_run jd W0212
_jd_t_lacks '2.0.4: jd W0212 does not see W0212+ Kettle child' \
  'matches for' "$JD_T_ERR"

_jd_t_run jd kettle
_jd_t_lacks '2.0.4: the word search does not see W0212+ Kettle child' \
  'matches for' "$JD_T_ERR"

# The same rule for IDs: '11.11+ Extension' is not '11.11'.
_jd_t_run jd 11.11
_jd_t_status '2.0.4: exit status for 11.11 beside 11.11+' 0
_jd_t_at '2.0.4: jd 11.11 does not see 11.11+ Extension' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"
_jd_t_eq '2.0.4: 11.11 has exactly one match' '' "$JD_T_ERR"

# ============================================================== 2.0.2
# A single system with no 'sys' silently got no jd command at all.

_jd_t_load "$JD_T_TMP/single-nosys.json"
_jd_t_eq '2.0.2: one system with no sys loads without complaint' \
  '' "$JD_T_LOADERR"

_jd_t_run jd
_jd_t_status '2.0.2: one system with no sys has a working jd' 0
_jd_t_at '2.0.2: jd goes to the root of a system with no sys' "$JD_FX_ROOT"

_jd_t_run jd 11.11
_jd_t_at '2.0.2: jd navigates in a system with no sys' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"

_jd_t_run jd jdex 11.11
_jd_t_at '2.0.2: the JDex works in a system with no sys' \
  "$JD_FX_JDEX/10-19 Area one/11 Category eleven"

# More than one system, and one of them has no sys. That one cannot get a
# command, so jd says so at shell start rather than staying quiet.
_jd_t_load "$JD_T_TMP/multi-nosys.json"
_jd_t_contains '2.0.2: more than one system with a missing sys is an error' \
  "has no 'sys'" "$JD_T_LOADERR"
_jd_t_contains '2.0.2: the error says why' \
  'every entry needs one when there is more than one system' "$JD_T_LOADERR"

_jd_t_run jd
_jd_t_at '2.0.2: the systems that do have a sys still work' "$JD_FX_ROOT"

_jd_t_run d25
_jd_t_at '2.0.2: and by name too' "$JD_FX_ROOT"

# ============================================================== 2.0.3
# _jd_pwd read config rows with `IFS=$'\t' read a b`, which drops a
# leading empty field, so a system with no sys lost its root as well and
# the prompt printed the whole path. zsh only: there is no bash prompt.

if [ -n "${ZSH_VERSION-}" ]; then
  _jd_t_load "$JD_T_TMP/single-nosys.json"

  _jd_t_run_from "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" _jd_pwd
  _jd_t_eq '2.0.3: _jd_pwd shortens for a system with no sys' \
    '…/11.11 First ID' "$JD_T_OUT"

  _jd_t_run_from "$JD_FX_ROOT" _jd_pwd
  _jd_t_eq '2.0.3: and at the root of a system with no sys' '~' "$JD_T_OUT"

  # With a sys, the same places carry the label.
  _jd_fx_config_single "$JD_T_TMP/single.json"
  _jd_t_load "$JD_T_TMP/single.json"

  _jd_t_run_from "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" _jd_pwd
  _jd_t_eq '2.0.3: with a sys the label is printed' \
    'D25:…/11.11 First ID' "$JD_T_OUT"
else
  _jd_t_skipped '2.0.3: _jd_pwd shortens for a system with no sys' 'zsh only'
fi

_jd_t_summary
