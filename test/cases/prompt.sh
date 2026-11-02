# SPDX-License-Identifier: MIT
# prompt.sh - the prompt path, _jd_pwd
#
# jd.sh loads lib/prompt.zsh under zsh and lib/prompt.bash under bash.
# The two must print the same path, so every test here runs in both.
#
# _jd_pwd anchors at the deepest numbered folder. Everything above the
# anchor is printed as an ellipsis. Outside every system it prints the
# ordinary path, with $HOME as ~.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
mkdir -p "$HOME/somewhere"
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

# ------------------------------------------------------- inside a system

_jd_t_run_from "$JD_FX_ROOT" _jd_pwd
_jd_t_eq 'prompt: at the system root' 'D25:~' "$JD_T_OUT"

_jd_t_run_from "$JD_FX_ROOT/10-19 Area one" _jd_pwd
_jd_t_eq 'prompt: in an area' 'D25:…/10-19 Area one' "$JD_T_OUT"

_jd_t_run_from "$JD_FX_ROOT/10-19 Area one/11 Category eleven" _jd_pwd
_jd_t_eq 'prompt: in a category' 'D25:…/11 Category eleven' "$JD_T_OUT"

_jd_t_run_from "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" _jd_pwd
_jd_t_eq 'prompt: in an ID' 'D25:…/11.11 First ID' "$JD_T_OUT"

# Below an ID the anchor is still the ID, and the rest is printed in
# full.
_jd_t_run_from "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID/sub/deeper" _jd_pwd
_jd_t_eq 'prompt: below an ID' 'D25:…/11.11 First ID/sub/deeper' "$JD_T_OUT"

# A folder with no number anywhere above it has no anchor.
_jd_t_run_from "$JD_FX_ROOT/notes" _jd_pwd
_jd_t_eq 'prompt: a folder with no number' 'D25:…/notes' "$JD_T_OUT"

# Each system has its own label.
_jd_t_run_from "$JD_FX_ROOT2/30-39 Area three/31 Category thirtyone/31.11 Pear" _jd_pwd
_jd_t_eq 'prompt: the second system has its own label' \
  'P76:…/31.11 Pear' "$JD_T_OUT"

_jd_t_run_from "$JD_FX_ROOT2" _jd_pwd
_jd_t_eq 'prompt: at the second system root' 'P76:~' "$JD_T_OUT"

# ----------------------------------------------------- outside every system

_jd_t_run_from "$HOME" _jd_pwd
_jd_t_eq 'prompt: at home' '~' "$JD_T_OUT"

_jd_t_run_from "$HOME/somewhere" _jd_pwd
_jd_t_eq 'prompt: below home' '~/somewhere' "$JD_T_OUT"

_jd_t_run_from "$JD_T_TMP" _jd_pwd
_jd_t_eq 'prompt: outside home, the whole path' "$JD_T_TMP" "$JD_T_OUT"

# ------------------------------------------------------ no config at all

_jd_t_load "$JD_T_TMP/nothing-here.json"
_jd_t_run_from "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" _jd_pwd
_jd_t_eq 'prompt: with no config it prints the ordinary path' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" "$JD_T_OUT"

# A folder name with characters that a pattern treats as special. The
# root is compared as a string, not as a pattern.
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"
mkdir -p "$HOME/a*b [c]"
_jd_t_run_from "$HOME/a*b [c]" _jd_pwd
_jd_t_eq 'prompt: a folder name with * and [ ] below home' '~/a*b [c]' "$JD_T_OUT"

_jd_t_summary
