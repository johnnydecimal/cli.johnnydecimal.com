# SPDX-License-Identifier: MIT
# tasks/none.sh - no task app
#
# The work package gets no project and no task app link.
# {{TASKS_URL}} is empty.

jd_tasks_check() { return 0; }
jd_tasks_create() { printf ''; }
jd_tasks_link() { return 0; }
jd_tasks_refresh() {
  _jd_nav_err "no task app is set for this system, so there is no template to read"
  return 1
}
