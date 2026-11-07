# SPDX-License-Identifier: MIT
# jdex.sh - read a system's JDex, in any of its three layouts
# Part of the Johnny.Decimal command line. Sourced by bin/jd, after
# paths.sh, nav.sh and bear.sh.
#
# A JDex has one of three layouts. _jd_jdex_load reads the system's
# "jdex" from the config, and sets $_JD_JDEX_KIND to the layout:
#
#   nested       a folder of area folders, which contain category
#                folders, which contain the notes: 11-19/11/11.11.md
#   flat         a folder with no area folders. The notes are in its
#                root: 11.11.md
#   bear         the notes are in Bear. An area is a tag, a category is
#                a tag nested under it, and a note's title starts with
#                its ID. lib/bear.sh reads it
#   none         the system has no JDex
#   unsupported  the JDex is in an app that jd cannot read
#
# Every lookup is one function, _jd_jdex_find, which prints one line per
# match, three fields separated by a tab:
#
#   locator   the path, for a folder, or bear:note:<id> or
#             bear:tag:<tag>, for Bear
#   display   the match as a path from the top of the JDex, for a list
#             of matches
#   name      the name of the entry: the file name, or the note title
#
# Requires jq. Works in bash 3.2+ and zsh.

# Read the JDex of system $1, the sys id or '#N', from the config. Sets
# $_JD_JDEX_PATH, $_JD_JDEX_APP, $_JD_JDEX_VAULT, $_JD_JDEX_SYS and
# $_JD_JDEX_KIND.
_jd_jdex_load() {
  local sys=$1 cfg sel row us
  _JD_JDEX_PATH=''
  _JD_JDEX_APP=''
  _JD_JDEX_VAULT=''
  _JD_JDEX_SYS=''
  _JD_JDEX_KIND=none
  cfg=$(_jd_paths_config)
  case $sys in
    '#'*) sel=".systems[${sys#'#'}]" ;;
    *) sel='first(.systems[] | select(.sys == $s))' ;;
  esac
  # The unit separator, not a tab, because read joins adjacent tabs, and
  # most of these fields can be empty.
  row=$(jq -r --arg s "$sys" "$sel"' |
    (if (.jdex | type) == "object" then .jdex else {} end) as $j |
    [($j.path // ""), ($j.app // ""), ($j.vault // ""), (.sys // "")] | join("\u001f")' \
    "$cfg" 2>/dev/null) || return 0
  us=$(printf '\037')
  IFS=$us read -r _JD_JDEX_PATH _JD_JDEX_APP _JD_JDEX_VAULT _JD_JDEX_SYS <<EOF
$row
EOF
  if [ "$_JD_JDEX_APP" = bear ]; then
    _JD_JDEX_KIND=bear
  elif [ -n "$_JD_JDEX_PATH" ]; then
    _JD_JDEX_KIND=nested
    if [ -d "$_JD_JDEX_PATH" ] && _jd_jdex_is_flat "$_JD_JDEX_PATH"; then
      _JD_JDEX_KIND=flat
    fi
  elif [ -n "$_JD_JDEX_APP" ]; then
    _JD_JDEX_KIND=unsupported
  fi
  return 0
}

# Is $1 an ID folder that contains its own note? This matches how the
# Obsidian 'Folder notes' plugin works: '21.41 Videos/21.41 Videos.md'.
# The note's name is exactly the folder's name.
_jd_jdex_folder_note() { [ -f "$1/${1##*/}.md" ]; }

# Is the JDex folder $1 flat? A flat JDex has no area folders, and its
# notes are in its root. An ID there can be a note, or a folder that
# contains its own note.
_jd_jdex_is_flat() {
  local d
  [ -z "$(_jd_nav_find "$1" 1 d -name '[0-9][0-9]-[0-9][0-9]' -o -name '[0-9][0-9]-[0-9][0-9] *')" ] ||
    return 1
  [ -n "$(_jd_nav_find "$1" 1 a -name '[0-9][0-9].[0-9][0-9]*.md')" ] && return 0
  _jd_nav_find "$1" 1 d -name '[0-9][0-9].[0-9][0-9]' -o -name '[0-9][0-9].[0-9][0-9] *' |
    while IFS= read -r d; do
      _jd_jdex_folder_note "$d" && { printf 'y'; break; }
    done | grep -q y
}

# Paths on stdin, as lines of locator, display and name. $1 the folder
# that the display is relative to.
_jd_jdex_rel() {
  local t=$1 p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s\t%s\t%s\n' "$p" "${p#"$t"/}" "${p##*/}"
  done
}

# The entries at depth $2 in folder $1 whose name matches find test $3,
# and contains every word after it, ignoring case.
_jd_jdex_words() {
  local dir=$1 depth=$2 t
  local -a tests
  tests=(-name "$3")
  shift 3
  for t in "$@"; do tests=("${tests[@]}" -iname "*$t*"); done
  _jd_nav_find "$dir" "$depth" a "${tests[@]}"
}

# The work package entries at depth $2 in folder $1, as _jd_jdex_words.
_jd_jdex_wp_words() {
  local dir=$1 depth=$2 t
  local -a tests
  tests=(-iname 'w[0-9][0-9][0-9][0-9][ ~]*')
  shift 2
  for t in "$@"; do tests=("${tests[@]}" -iname "*$t*"); done
  _jd_nav_find "$dir" "$depth" a "${tests[@]}"
}

# A nested JDex. The depths are the filesystem's: area 1, category 2,
# ID 3, and a work package 2, in the W0000 area.
_jd_jdex_find_nested() {
  local t=$_JD_JDEX_PATH what=$1 c
  shift
  case $what in
    area) _jd_nav_find "$t" 1 d -name "$1" -o -name "$1 *" ;;
    category) _jd_nav_find "$t" 2 d -name "$1" -o -name "$1 *" ;;
    id) _jd_nav_find "$t" 3 a -name "$1" -o -name "$1 *" -o -name "$1.md" ;;
    wp) _jd_nav_find "$t" 2 a -iname "$1" -o -iname "$1 *" -o -iname "$1~*" -o -iname "$1.md" ;;
    search-area)
      c=$(_jd_nav_find "$t" 1 d -name "$1" -o -name "$1 *")
      shift
      [ "$(printf '%s' "$c" | grep -c '^')" -eq 1 ] &&
        _jd_jdex_words "$c" 2 '[0-9][0-9].[0-9][0-9]*' "$@"
      ;;
    search-category)
      c=$(_jd_nav_find "$t" 2 d -name "$1" -o -name "$1 *")
      shift
      [ "$(printf '%s' "$c" | grep -c '^')" -eq 1 ] &&
        _jd_jdex_words "$c" 1 '[0-9][0-9].[0-9][0-9]*' "$@"
      ;;
    search)
      _jd_jdex_words "$t" 3 '[0-9][0-9].[0-9][0-9]*' "$@"
      _jd_jdex_wp_words "$t" 2 "$@"
      ;;
  esac | _jd_jdex_rel "$t"
}

# A flat JDex. Every ID is in the root. A work package is in the root,
# or in a W0000 folder in the root. An area or a category is the root
# itself, when the root contains a note in it.
_jd_jdex_find_flat() {
  local t=$_JD_JDEX_PATH what=$1 x w
  shift
  case $what in
    area | search-area) x="${1%%?-*}[0-9].[0-9][0-9]*" ;;
    category | search-category) x="$1.[0-9][0-9]*" ;;
  esac
  case $what in
    area | category)
      [ -n "$(_jd_nav_find "$t" 1 a -name "$x")" ] && printf '%s\n' "$t"
      ;;
    id) _jd_nav_find "$t" 1 a -name "$1" -o -name "$1 *" -o -name "$1.md" ;;
    wp)
      _jd_nav_find "$t" 1 a \( -iname "$1" -o -iname "$1 *" -o -iname "$1~*" -o -iname "$1.md" \) ! -iname 'w0000*'
      _jd_nav_find "$t" 1 d -iname 'W0000*' | while IFS= read -r w; do
        _jd_nav_find "$w" 1 a -iname "$1" -o -iname "$1 *" -o -iname "$1~*" -o -iname "$1.md"
      done
      ;;
    search-area | search-category)
      shift
      _jd_jdex_words "$t" 1 "$x" "$@"
      ;;
    search)
      _jd_jdex_words "$t" 1 '[0-9][0-9].[0-9][0-9]*' "$@"
      _jd_jdex_wp_words "$t" 1 "$@" | grep -iv '/w0000[^/]*$'
      _jd_nav_find "$t" 1 d -iname 'W0000*' | while IFS= read -r w; do
        _jd_jdex_wp_words "$w" 1 "$@"
      done
      ;;
  esac | _jd_jdex_rel "$t"
}

# Find entries in the JDex. $1 what to find, then its arguments:
#
#   area 10-19            category 11            id 11.11
#   wp W0012              search word...
#   search-area 10-19 word...                    search-category 11 word...
#
# A search matches an ID entry, or a work package entry, whose name
# contains every word, ignoring case. Prints the matches. Returns 1 if
# the JDex cannot be read.
_jd_jdex_find() {
  case $_JD_JDEX_KIND in
    nested) _jd_jdex_find_nested "$@" ;;
    flat) _jd_jdex_find_flat "$@" ;;
    bear) _jd_bear_find "$@" ;;
    *) return 1 ;;
  esac
}

# Act on the matches $2 from _jd_jdex_find. $1 the label for messages.
# One match: go to it. For a folder, that is the folder that contains
# the note. For Bear, jd opens the note or the tag in Bear. More than
# one: print the list. None: an error.
_jd_jdex_go() {
  local label=$1 m=$2 n loc tab
  tab=$(printf '\t')
  n=$(printf '%s' "$m" | grep -c '^')
  if [ "$n" -eq 0 ]; then
    _jd_nav_err "no match for $label"
  elif [ "$n" -eq 1 ]; then
    loc=${m%%"$tab"*}
    case $loc in
      bear:*)
        m=${m#*"$tab"}
        _jd_bear_open "$loc" "${m%%"$tab"*}"
        return
        ;;
    esac
    [ -d "$loc" ] || loc=$(dirname -- "$loc")
    _jd_nav_arrive "$loc"
  else
    {
      printf 'jd: %s matches for %s:\n' "$n" "$label"
      printf '%s\n' "$m" | cut -f2 | _jd_nav_tree
    } >&2
    return 1
  fi
}

# 'jdex <target>': the same targets as the filesystem, in the JDex.
# $_JD_JDEX_* are set. $@ the user's words.
_jd_nav_jdex() {
  local a c id m
  if [ "$_JD_JDEX_KIND" = bear ]; then
    _jd_bear_load || return 1
  fi
  case $1 in
    [0-9][0-9]-[0-9][0-9])
      a=$1
      shift
      m=$(_jd_jdex_find area "$a")
      if [ $# -gt 0 ] && [ "$(printf '%s' "$m" | grep -c '^')" -eq 1 ]; then
        _jd_jdex_go "'$*' in area $a" "$(_jd_jdex_find search-area "$a" "$@")"
      else
        _jd_jdex_go "area $a" "$m"
      fi
      ;;
    [0-9][0-9] | [0-9][0-9].)
      c=${1%.}
      shift
      m=$(_jd_jdex_find category "$c")
      if [ $# -gt 0 ] && [ "$(printf '%s' "$m" | grep -c '^')" -eq 1 ]; then
        _jd_jdex_go "'$*' in category $c" "$(_jd_jdex_find search-category "$c" "$@")"
      else
        _jd_jdex_go "category $c" "$m"
      fi
      ;;
    [0-9][0-9].[0-9][0-9])
      id=$1
      shift
      [ $# -eq 0 ] || { _jd_nav_err "unexpected words after '$id'"; return 1; }
      _jd_jdex_go "$id" "$(_jd_jdex_find id "$id")"
      ;;
    [Ww][0-9][0-9][0-9][0-9])
      id=$1
      shift
      [ $# -eq 0 ] || { _jd_nav_err "unexpected words after '$id'"; return 1; }
      _jd_jdex_go "$id" "$(_jd_jdex_find wp "$id")"
      ;;
    *)
      _jd_jdex_go "'$*'" "$(_jd_jdex_find search "$@")"
      ;;
  esac
}
