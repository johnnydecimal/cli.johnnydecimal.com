# SPDX-License-Identifier: MIT
# bear.sh - read and write a JDex in Bear
# Part of the Johnny.Decimal command line. Sourced by bin/jd, before
# jdex.sh, which calls it.
#
# Bear includes a command line tool, bearcli, which reads and writes
# notes through Bear's own code. jd runs it, and never reads Bear's
# database. $JD_BEARCLI is the path of the tool, if it is not in the
# place where Bear installs it.
#
# A Bear JDex is in tags. jd matches each one by the number at its
# start, the same way it matches a folder:
#
#   #10-19 Life admin#                       an area
#   #10-19 Life admin/11 Me#                 a category
#   #W0000-9999 Work packages#               the work package area
#
# An ID is a note that has its category's tag, and whose title starts
# with the ID: '11.53 Correspondence'. A work package is a note that has
# the work package area's tag: 'W0015~11.24 Get a checkup'. A tag nested
# below a category, such as '#10-19 Life admin/11 Me/11.53#', counts as
# the category.
#
# One Bear library can contain more than one system. If the library has
# a top-level tag that is the system's sys, or that starts with it and a
# space, such as '#P76 Personal#', jd reads that system's tags below it:
# '#P76 Personal/10-19 Life admin/11 Me#'.
#
# A note in the trash is not in the JDex. An archived note is.
#
# Requires jq. Works in bash 3.2+ and zsh.

_JD_BEAR_CLI_DEFAULT=/Applications/Bear.app/Contents/MacOS/bearcli
_JD_BEAR_APP=net.shinyfrog.bear

_jd_bear_cli() { printf '%s' "${JD_BEARCLI:-$_JD_BEAR_CLI_DEFAULT}"; }
_jd_bear() { "$(_jd_bear_cli)" "$@"; }

# Return 0 if bearcli can be run. Print why not, and return 1, if not.
_jd_bear_check() {
  local b
  b=$(_jd_bear_cli)
  [ -x "$b" ] && return 0
  _jd_nav_err "the JDex is in Bear, but there is no bearcli at $b - set JD_BEARCLI to its path"
  return 1
}

# The index, as a jq program. Its input is the tag list and the note
# list from bearcli. It prints one line for each tag and note in this
# system's JDex, five fields separated by a tab:
#
#   B                    the base: the system's top-level tag and '/',
#                        or nothing
#   A  -  -  area        an area tag
#   W  -  -  area        the work package area tag
#   C  -  -  area  cat   a category tag
#   N  id title area cat  a note. cat is empty for a work package
#
# Each tag is the whole tag, with the base, and with no '#'.
_JD_BEAR_INDEX_JQ='
  def strip: ltrimstr("#") | rtrimstr("#");
  def tags_of: [.[] | .tag | strip];
  ($tags | tags_of) as $all
  | (if $sys == "" then ""
     else ([$all[] | select(contains("/") | not)
              | select(. == $sys or startswith($sys + " "))] | first // "")
     end) as $top
  | (if $top == "" then "" else $top + "/" end) as $base
  | [$all[] | select(startswith($base)) | {full: ., rel: ltrimstr($base)}] as $mine
  | [$mine[] | select(.rel | test("^[0-9][0-9]-[0-9][0-9]( [^/]*)?$"))] as $areas
  | [$mine[] | select(.rel | test("^[Ww]0000[^/]*$"))] as $wareas
  | [$mine[] | select(.rel | test("^[0-9][0-9]-[0-9][0-9]( [^/]*)?/[0-9][0-9]( [^/]*)?$"))] as $cats
  | def parent: split("/") | .[:-1] | join("/");
    def under($t): . == $t or startswith($t + "/");
    "B\t\t\t\($base)\t",
    ($areas[] | "A\t\t\t\(.full)\t"),
    ($wareas[] | "W\t\t\t\(.full)\t"),
    ($cats[] | "C\t\t\t\(.full | parent)\t\(.full)"),
    ($notes[] | select(.location != "trash")
      | . as $n
      | ($n.tags | map(strip)) as $nt
      | ([$cats[] | select(.full as $c | any($nt[]; under($c)))] | first) as $cat
      | if $cat != null then
          "N\t\($n.id)\t\($n.title)\t\($cat.full | parent)\t\($cat.full)"
        else
          ([$wareas[] | select(.full as $w | any($nt[]; under($w)))] | first) as $w
          | if $w != null then "N\t\($n.id)\t\($n.title)\t\($w.full)\t" else empty end
        end)
'

# Read this system's JDex from Bear into $_JD_BEAR_INDEX and
# $_JD_BEAR_BASE, once in each shell. $_JD_JDEX_SYS is set.
_jd_bear_load() {
  local tags notes
  [ "${_JD_BEAR_LOADED-}" = "sys:$_JD_JDEX_SYS" ] && return 0
  _jd_bear_check || return 1
  tags=$(_jd_bear tags list --format json 2>/dev/null) || {
    _jd_nav_err "bearcli could not list the tags in Bear"
    return 1
  }
  notes=$(_jd_bear list --location all --fields id,title,tags,location --format json 2>/dev/null) || {
    _jd_nav_err "bearcli could not list the notes in Bear"
    return 1
  }
  _JD_BEAR_INDEX=$(jq -rn --argjson tags "${tags:-[]}" --argjson notes "${notes:-[]}" \
    --arg sys "$_JD_JDEX_SYS" "$_JD_BEAR_INDEX_JQ" 2>/dev/null) || {
    _jd_nav_err "bearcli printed a tag list or a note list that jd cannot read"
    return 1
  }
  _JD_BEAR_BASE=$(printf '%s\n' "$_JD_BEAR_INDEX" | awk -F'\t' '$1 == "B" { print $4; exit }')
  _JD_BEAR_LOADED="sys:$_JD_JDEX_SYS"
}

# Find entries in a Bear JDex. The same arguments and output as
# _jd_jdex_find.
_jd_bear_find() {
  local what=$1 arg=${2-} us words
  _jd_bear_load || return 1
  shift
  case $what in search-area | search-category) shift ;; esac
  us=$(printf '\037')
  words=$(
    IFS=$us
    printf '%s' "$*"
  )
  printf '%s\n' "$_JD_BEAR_INDEX" | _JD_BEAR_WORDS=$words awk -F'\t' -v what="$what" -v arg="$arg" -v base="$_JD_BEAR_BASE" '
    function rel(t) { return (base != "" && index(t, base) == 1) ? substr(t, length(base) + 1) : t }
    function last(t,   s, n) { n = split(t, s, "/"); return s[n] }
    function is(seg, num) { return seg == num || index(seg, num " ") == 1 }
    function words(title,   i, lt) {
      lt = tolower(title)
      for (i = 1; i <= nw; i++) if (index(lt, tolower(w[i])) == 0) return 0
      return 1
    }
    function out(group, loc, disp, name) { printf "%s\t%s\t%s\t%s\n", group, disp, loc, name }
    function idlike(t) { return t ~ /^[0-9][0-9]\.[0-9][0-9]/ }
    function wplike(t) { return t ~ /^[Ww][0-9][0-9][0-9][0-9][ ~]/ }
    BEGIN {
      nw = (ENVIRON["_JD_BEAR_WORDS"] == "") ? 0 : split(ENVIRON["_JD_BEAR_WORDS"], w, "\037")
      la = tolower(arg)
    }
    what == "area" && $1 == "A" && is(last($4), arg) { out(1, "bear:tag:" $4, rel($4), last($4)) }
    what == "category" && $1 == "C" && is(last($5), arg) { out(1, "bear:tag:" $5, rel($5), last($5)) }
    $1 != "N" { next }
    what == "id" && $5 != "" && is($3, arg) { out(1, "bear:note:" $2, rel($5) "/" $3, $3) }
    what == "wp" && $5 == "" {
      lt = tolower($3)
      if (lt == la || index(lt, la " ") == 1 || index(lt, la "~") == 1) out(1, "bear:note:" $2, rel($4) "/" $3, $3)
    }
    what == "search-area" && $5 != "" && is(last($4), arg) && idlike($3) && words($3) { out(1, "bear:note:" $2, rel($5) "/" $3, $3) }
    what == "search-category" && $5 != "" && is(last($5), arg) && idlike($3) && words($3) { out(1, "bear:note:" $2, rel($5) "/" $3, $3) }
    what == "search" && $5 != "" && idlike($3) && words($3) { out(1, "bear:note:" $2, rel($5) "/" $3, $3) }
    what == "search" && $5 == "" && wplike($3) && words($3) { out(2, "bear:note:" $2, rel($4) "/" $3, $3) }
  ' | sort -t "$(printf '\t')" -k1,1 -k2,2 | awk -F'\t' 'BEGIN { OFS = "\t" } { print $3, $2, $4 }'
}

# The titles of the notes in category tag $1, one per line. With $2
# 'wp', the titles of the work package notes in area tag $1.
_jd_bear_titles() {
  _jd_bear_load || return 1
  printf '%s\n' "$_JD_BEAR_INDEX" | awk -F'\t' -v t="$1" -v wp="${2-}" '
    $1 != "N" { next }
    wp == "" && $5 == t { print $3 }
    wp != "" && $5 == "" && $4 == t { print $3 }
  '
}

# The work package area tags, one per line.
_jd_bear_wp_areas() {
  _jd_bear_load || return 1
  printf '%s\n' "$_JD_BEAR_INDEX" | awk -F'\t' '$1 == "W" { print $4 }'
}

# Open a match in Bear. $1 its locator, bear:note:<id> or
# bear:tag:<tag>, and $2 its display, for the message.
_jd_bear_open() {
  case $1 in
    bear:note:*)
      _jd_bear app open "${1#bear:note:}" >/dev/null 2>&1 || {
        _jd_nav_err "bearcli could not open $2 in Bear"
        return 1
      }
      ;;
    bear:tag:*)
      _jd_bear_open_url "bear://x-callback-url/open-tag?name=$(_jd_new_uri "${1#bear:tag:}")" || {
        _jd_nav_err "could not open $2 in Bear"
        return 1
      }
      ;;
  esac
  printf 'jd: opened %s in Bear\n' "$2" >&2
}

# Open a bear:// URL, or Bear itself. macOS only, as Bear is.
_jd_bear_open_url() {
  if [ "$1" = "$_JD_BEAR_APP" ]; then
    open -b "$1"
  else
    open "$1"
  fi
}

# Open Bear itself: 'jdex' with no target.
_jd_bear_open_app() {
  if [ -n "$_JD_BEAR_BASE" ]; then
    _jd_bear_open "bear:tag:${_JD_BEAR_BASE%/}" "${_JD_BEAR_BASE%/}"
  else
    _jd_bear_open_url "$_JD_BEAR_APP" || {
      _jd_nav_err "could not open Bear"
      return 1
    }
    printf 'jd: opened Bear\n' >&2
  fi
}

# Create a note. $1 its title, $2 its tag, with no '#'. The rest of the
# note is on stdin. The note starts with the title as a heading, then
# the tag, which is how Bear reads a title and a tag. Prints the new
# note's id.
_jd_bear_create() {
  {
    printf '# %s\n#%s#\n' "$1" "$2"
    cat
  } | _jd_bear create --format json --fields id 2>/dev/null |
    jq -r 'if type == "array" then .[0].id else .id end // empty' 2>/dev/null
}
