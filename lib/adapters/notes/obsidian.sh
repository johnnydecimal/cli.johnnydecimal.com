# SPDX-License-Identifier: MIT
# notes/obsidian.sh - Obsidian
#
# It makes a link to the work package's block reference in the JDex
# vault. The note itself carries '^w0216' as its permalink, so the link
# holds a reader at that block wherever the note moves to.
#
#   obsidian://adv-uri?vault=D25%20JDex&block=w0216
#
# The link needs the Advanced URI plugin. Nothing here talks to
# Obsidian, so it works whether Obsidian is running or not.
#
# Config:
#   workPackages.notes.vault   the vault name. Defaults to the name of
#                              the JDex folder, which is the vault name
#                              in most systems.

jd_notes_check() {
  [ -n "$_JD_NEW_NOTES_VAULT" ] && return 0
  _JD_NEW_NOTES_VAULT=$(basename -- "$_JD_NEW_JDEX")
  [ -n "$_JD_NEW_NOTES_VAULT" ] && return 0
  _jd_nav_err "the obsidian adapter needs workPackages.notes.vault in the config"
  return 1
}

jd_notes_url() {
  local lo
  lo=$(printf '%s' "$_JD_NEW_NUM" | tr 'A-Z' 'a-z')
  printf 'obsidian://adv-uri?vault=%s&block=%s' \
    "$(_jd_new_uri "$_JD_NEW_NOTES_VAULT")" "$lo"
}
