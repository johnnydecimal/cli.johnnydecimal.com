# SPDX-License-Identifier: MIT
# config.sh - reading ~/.jd/config.json, and what happens when it is wrong
#
# Everything reads one config file. $JD_CONFIG moves it, which is how the
# whole suite keeps away from the real one. These tests cover the shapes
# a config can take, good and bad, and check the message each bad shape
# gives, because a silent failure is the bug 2.0.2 was about.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_fx_config_single "$JD_T_TMP/single.json"
_jd_fx_config_second_only "$JD_T_TMP/second-only.json"
_jd_fx_config_single_nosys "$JD_T_TMP/single-nosys.json"
_jd_fx_config_multi_nosys "$JD_T_TMP/multi-nosys.json"
_jd_fx_config_default_second "$JD_T_TMP/default-second.json"
_jd_fx_config_empty "$JD_T_TMP/empty.json"
_jd_fx_config_malformed "$JD_T_TMP/malformed.json"
_jd_fx_config_missing_root "$JD_T_TMP/missing-root.json"

# --------------------------------------------------- $JD_CONFIG override

_jd_t_load "$JD_T_TMP/single.json"
_jd_t_run jd
_jd_t_at 'override: $JD_CONFIG picks the config' "$JD_FX_ROOT"

_jd_t_load "$JD_T_TMP/second-only.json"
_jd_t_run jd
_jd_t_at 'override: a different $JD_CONFIG picks a different system' \
  "$JD_FX_ROOT2"

# --------------------------------------------------------- no config file

_jd_t_load "$JD_T_TMP/nothing-here.json"
_jd_t_eq 'no config: loading says nothing at shell start' '' "$JD_T_LOADERR"

_jd_t_run jd
_jd_t_status 'no config: jd is an error' 1
_jd_t_contains 'no config: names the file it looked for' \
  "no config at $JD_T_TMP/nothing-here.json" "$JD_T_ERR"
_jd_t_contains 'no config: points at the help page' \
  'https://jdcm.al/jdhq/jd-cli' "$JD_T_ERR"
_jd_t_contains 'no config: names jd agent-setup as the way out' \
  'jd agent-setup' "$JD_T_ERR"

_jd_t_run jd version
_jd_t_status 'no config: jd version still works' 0
_jd_t_contains 'no config: jd version still prints a version' 'jd ' "$JD_T_OUT"

_jd_t_run jdex
_jd_t_status 'no config: jdex is an error' 1
_jd_t_contains 'no config: jdex names the file it looked for' \
  "no config at $JD_T_TMP/nothing-here.json" "$JD_T_ERR"

_jd_t_run jdex version
_jd_t_status 'no config: jdex version still works' 0

# ------------------------------------------------------ config is not JSON

_jd_t_load "$JD_T_TMP/malformed.json"
_jd_t_run jd
_jd_t_status 'malformed config: jd is an error' 1
_jd_t_contains 'malformed config: names the file' \
  "$JD_T_TMP/malformed.json" "$JD_T_ERR"

_jd_t_run jd version
_jd_t_status 'malformed config: jd version still works' 0

# -------------------------------------------------------- no systems in it

_jd_t_load "$JD_T_TMP/empty.json"
_jd_t_run jd
_jd_t_status 'empty config: jd is an error' 1
_jd_t_contains 'empty config: says there are no systems' \
  "no systems in $JD_T_TMP/empty.json" "$JD_T_ERR"

_jd_t_run jdex
_jd_t_status 'empty config: jdex is an error' 1
_jd_t_contains 'empty config: jdex says there are no systems' \
  "no systems in $JD_T_TMP/empty.json" "$JD_T_ERR"

# -------------------------------------------------------------- no sys key

_jd_t_load "$JD_T_TMP/single-nosys.json"
_jd_t_eq 'no sys, one system: nothing is said at shell start' \
  '' "$JD_T_LOADERR"
_jd_t_run jd
_jd_t_status 'no sys, one system: jd works' 0
_jd_t_at 'no sys, one system: jd goes to the root' "$JD_FX_ROOT"

_jd_t_load "$JD_T_TMP/multi-nosys.json"
_jd_t_contains 'no sys, two systems: an error at shell start' \
  "has no 'sys'" "$JD_T_LOADERR"

# -------------------------------------------------------- default: true

_jd_t_load "$JD_T_TMP/default-second.json"
_jd_t_run jd
_jd_t_at 'default: jd follows default: true, not the first entry' \
  "$JD_FX_ROOT"

_jd_t_run p76
_jd_t_at 'default: the non-default system still has its own command' \
  "$JD_FX_ROOT2"

_jd_t_run d25
_jd_t_at 'default: the default system also has its own command' "$JD_FX_ROOT"

_jd_t_load "$JD_T_TMP/two.json"
if command -v d25 >/dev/null 2>&1 && command -v p76 >/dev/null 2>&1; then
  _jd_t_ok 'two systems: one command per system'
else
  _jd_t_bad 'two systems: one command per system' \
    'd25 and p76 are both defined' 'at least one is missing'
fi

# ------------------------------------------------------ a system not there

_jd_t_run "$JD_T_BIN" --system X99
_jd_t_status 'unknown system: an error' 1
_jd_t_contains 'unknown system: says which one and where it looked' \
  "system 'X99' is not in $JD_T_TMP/two.json" "$JD_T_ERR"

_jd_t_load "$JD_T_TMP/missing-root.json"
_jd_t_run jd
_jd_t_status 'missing root: an error' 1
_jd_t_contains 'missing root: names the folder' \
  'folder does not exist:' "$JD_T_ERR"

# ------------------------------------------------------------- no jq

# jq is the one dependency. Without it jd must say so, and jd version
# must still work, because someone with no jq needs to be able to tell
# which version they have. _jd_fx_nojq_bin is a $PATH with every command
# the tools use except jq.
_jd_t_path=$PATH
PATH=$(_jd_fx_nojq_bin)
if command -v jq >/dev/null 2>&1; then
  PATH=$_jd_t_path
  _jd_t_bad 'no jq: jq can be hidden' 'no jq on $PATH' 'jq is still there'
else
  _jd_t_load "$JD_T_TMP/two.json"
  _jd_t_run jd
  _jd_t_status 'no jq: jd is an error' 1
  _jd_t_contains 'no jq: jd says so' 'jq is not installed' "$JD_T_ERR"
  _jd_t_run jd version
  _jd_t_status 'no jq: jd version still works' 0
  _jd_t_contains 'no jq: jd version still prints a version' 'jd ' "$JD_T_OUT"
  _jd_t_run jdex
  _jd_t_status 'no jq: jdex is an error' 1
  _jd_t_contains 'no jq: jdex says so' 'jq is not installed' "$JD_T_ERR"
  _jd_t_run jdex version
  _jd_t_status 'no jq: jdex version still works' 0
  PATH=$_jd_t_path
fi

# ------------------------------------------------- no leaks into the shell

# The setup code used to assign idx without declaring it local, so idx
# was left behind in the user's shell. It only happened on the path a
# single system with no sys takes, which is the common one-system
# config. Fixed in 2.0.5. That code is now _jd_nav_default_sys, in the
# program, where nothing it does can reach the shell at all - so this
# also checks that sourcing jd.sh leaves no variable of its own behind.

unset idx
_jd_t_load "$JD_T_TMP/single-nosys.json"
_jd_t_eq 'jd.sh does not leave $idx in the shell' 'unset' "${idx-unset}"

_jd_t_summary
