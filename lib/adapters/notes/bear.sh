# SPDX-License-Identifier: MIT
# notes/bear.sh - Bear
#
# The JDex is in Bear, so jd writes the work package's note there, and
# this adapter returns the links to it. lib/bear.sh contains the code
# that reads and writes Bear.
#
# The link to the work package's note opens it by its title. The note
# does not exist yet when jd creates the link, so it has no id to link
# to:
#
#   bear://x-callback-url/open-note?title=W0216~21.41%20The%20title
#
# The link to the ID's own note is a wiki-link, [[21.41 Videos]]. Bear
# lists the work package in that note's backlinks.

jd_notes_check() {
  _jd_bear_check
}

jd_notes_url() {
  printf 'bear://x-callback-url/open-note?title=%s' "$(_jd_new_uri "$_JD_NEW_NAME")"
}

jd_notes_parent_link() {
  printf '[[%s]]' "$_JD_NEW_PARENT_NOTE"
}
