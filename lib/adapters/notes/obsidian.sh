# SPDX-License-Identifier: MIT
# notes/obsidian.sh - Obsidian
#
# It makes a link to the work package's block reference in the JDex
# vault. The note itself carries '^w0216' as its permalink, so the link
# holds a reader at that block wherever the note moves to.
#
#   obsidian://adv-uri?vault=D25%20JDex&block=w0216
#
# The link to the ID's own note is a wiki-link, [[21.41 Videos]].
# Obsidian lists the work package in that note's backlinks, which it
# does for a wiki-link and not for an obsidian:// link. If the ID's note
# is renamed in Obsidian, Obsidian changes the link to match.
#
# The link needs the Advanced URI plugin. Nothing here talks to
# Obsidian, so it works whether Obsidian is running or not. If the JDex
# folder is the vault, and the vault does not have the plugin, jd warns,
# and makes the link all the same.
#
# Config:
#   workPackages.notes.vault   the vault name. Defaults to the name of
#                              the JDex folder, which is the vault name
#                              in most systems.

jd_notes_check() {
  [ -n "$_JD_NEW_NOTES_VAULT" ] || _JD_NEW_NOTES_VAULT=$(basename -- "$_JD_NEW_JDEX")
  [ -n "$_JD_NEW_NOTES_VAULT" ] || {
    _jd_nav_err "the obsidian adapter needs workPackages.notes.vault in the config"
    return 1
  }
  if [ -d "$_JD_NEW_JDEX/.obsidian" ] &&
    [ ! -d "$_JD_NEW_JDEX/.obsidian/plugins/obsidian-advanced-uri" ]; then
    _jd_nav_err "the Obsidian link needs the Advanced URI plugin, which this vault does not have: $_JD_NEW_JDEX"
    _jd_new_warn notes_plugin_missing
  fi
  return 0
}

jd_notes_url() {
  local lo
  lo=$(printf '%s' "$_JD_NEW_NUM" | tr 'A-Z' 'a-z')
  printf 'obsidian://adv-uri?vault=%s&block=%s' \
    "$(_jd_new_uri "$_JD_NEW_NOTES_VAULT")" "$lo"
}

jd_notes_parent_link() {
  printf '[[%s]]' "$_JD_NEW_PARENT_NOTE"
}
