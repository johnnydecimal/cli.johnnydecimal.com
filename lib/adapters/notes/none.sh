# SPDX-License-Identifier: MIT
# notes/none.sh - no note app
#
# The work package gets no note app link. {{NOTES_URL}} and
# {{PARENT_LINK}} are empty.

jd_notes_check() { return 0; }
jd_notes_url() { printf ''; }
jd_notes_parent_link() { printf ''; }
