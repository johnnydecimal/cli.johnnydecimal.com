# SPDX-License-Identifier: MIT
# known-bugs.sh - bugs the tests found, which nothing has fixed yet
#
# These say what the right answer is. They do not turn the suite red,
# because red is for work that has gone backwards, and none of this ever
# worked. Use _jd_t_eq_known. When one is fixed, promote it: move it into
# the case file it belongs in and change it to _jd_t_eq.
#
# Empty as of 2.0.5. The two bugs that lived here are fixed, and their
# tests are now in config.sh ($idx leaking into the shell) and nav-fs.sh
# (a bare jd under set -u).

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"

_jd_t_summary
