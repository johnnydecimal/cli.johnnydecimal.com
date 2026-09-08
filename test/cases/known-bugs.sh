# SPDX-License-Identifier: MIT
# known-bugs.sh - bugs the tests found, which nothing has fixed yet
#
# These say what the right answer is. They do not turn the suite red,
# because red is for work that has gone backwards, and none of this ever
# worked. When one is fixed its line changes to 'this now passes, so
# promote it'. Move it into the case file it belongs in and use
# _jd_t_eq.
#
# Both bugs below are in lib/nav.sh.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build
_jd_fx_config_single_nosys "$JD_T_TMP/single-nosys.json"
_jd_fx_config_two "$JD_T_TMP/two.json"

# ------------------------------------------------------------------- 1
# _jd_nav_setup declares 'local cfg n sys fn'. It also assigns to idx,
# which is not in that list, so idx becomes a global and is left in the
# user's shell. It happens on the path a single system with no sys takes,
# which is the common one-system config.

unset idx
_jd_t_load "$JD_T_TMP/single-nosys.json"
_jd_t_eq_known 'nav.sh does not leave $idx in the shell' \
  'unset' "${idx-unset}" \
  "idx is missing from the 'local' list in _jd_nav_setup"

# ------------------------------------------------------------------- 2
# _jd_nav reads $1 before it has checked that there is a $1. Under
# 'set -u' (bash) or 'setopt nounset' (zsh), a bare 'jd' therefore dies
# on an unbound variable instead of going to the system root. Every jd
# with an argument is fine, so this is the no-argument case only.

# A subshell, so the option does not escape into the harness. The cd
# stays in the subshell too, so these tests read the path jd prints
# rather than $JD_T_PWD.
_jd_t_nounset_jd() ( set -u; jd "$@" )

_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run _jd_t_nounset_jd
_jd_t_eq_known 'bare jd works under set -u' \
  "$JD_FX_ROOT" "$JD_T_OUT" \
  'nav.sh reads $1 before it checks $#'
_jd_t_eq_known 'bare jd under set -u says nothing on stderr' \
  '' "$JD_T_ERR" \
  'nav.sh reads $1 before it checks $#'

# With an argument it is fine, which is how we know where the fault is.
_jd_t_run _jd_t_nounset_jd 11.11
_jd_t_eq 'jd with an argument works under set -u' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" "$JD_T_OUT"

_jd_t_run _jd_t_nounset_jd version
_jd_t_status 'jd version works under set -u' 0

_jd_t_summary
