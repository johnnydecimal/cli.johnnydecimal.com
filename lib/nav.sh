# SPDX-License-Identifier: MIT
# nav.sh - Johnny.Decimal navigation
# Part of the Johnny.Decimal command line. Sourced by bin/jd, which sets
# $_JD_CLI_VERSION, $_JD_CLI_HELP_URL and $_JD_CLI_DIR.
#
# It defines _jd_nav, which bin/jd calls with the system to act on and
# the words the user typed. It reads ~/.jd/config.json (override with
# $JD_CONFIG) to learn that system's root folder and JDex.
#
# An empty system means the default one: the entry marked default: true,
# else the first entry.
#
# Nothing here cd's. A move ends at _jd_nav_arrive, which prints the
# folder. The comment at the top of bin/jd says why.
#
# 'jd new' is a word this file does not act on. It hands the rest of the
# line to _jd_new, in lib/new.sh.
#
# Needs jq. Works in bash 3.2+ and zsh.

_jd_nav_config() { printf '%s' "${JD_CONFIG:-$HOME/.jd/config.json}"; }

_jd_nav_err() { printf 'jd: %s\n' "$*" >&2; return 1; }

# The one 'no config' message, so that every command that needs the
# config says the same thing, and names the way out. $1 the config path.
_jd_nav_no_config_msg() {
  printf "no config at %s - run 'jd setup' for help, or see %s" "$1" "$_JD_CLI_HELP_URL"
}

# Arrive at a folder. $1 the absolute path. This is the one place a move
# ends, and the only thing that writes a path to stdout.
#
# On its own the program cannot move the shell that called it, so it
# says where to go and stops: the path, one line, status 0. That is the
# answer to 'where is 11.11', and it is what a script or an agent reads.
#
# jd.sh sets JD_HOOK, because it can move the shell. It gets the same
# path and status 3, which no other thing here returns. The hook does
# the cd.
_jd_nav_arrive() {
  printf '%s\n' "$1"
  [ -n "${JD_HOOK-}" ] && return 3
  return 0
}

# Print the sys id of the default system: the entry marked default:
# true, else the first entry. An entry with no sys is named by its place
# in the array, '#0', which _jd_nav reads as well as a sys id.
#
# Returns 1 if the config holds no system to name, which is also what a
# config jq cannot read looks like from here.
_jd_nav_default_sys() {
  local cfg sys idx
  cfg=$(_jd_nav_config)
  sys=$(jq -r '(.systems | (map(select(.default == true))[0] // .[0])).sys // empty' \
    "$cfg" 2>/dev/null)
  if [ -z "$sys" ]; then
    idx=$(jq -r '(.systems | to_entries | (map(select(.value.default == true))[0] // .[0])).key' \
      "$cfg" 2>/dev/null)
    case $idx in
      '' | null | *[!0-9]*) return 1 ;;
    esac
    sys="#$idx"
  fi
  printf '%s' "$sys"
}

# Print the version if $1 asks for it. Returns 0 if it did.
_jd_nav_is_version() {
  case ${1-} in
    -v|--version|version) printf 'jd %s\n' "$_JD_CLI_VERSION"; return 0 ;;
  esac
  return 1
}

_jd_nav_usage() {
  printf 'jd %s\n\n' "$_JD_CLI_VERSION"
  cat <<'EOF'
usage: <system> [jdex] [target]
       jdex [target]

  <system>              cd to the system root
  <system> 20-29        cd to an area
  <system> 22           cd to a category
  <system> 11.11        cd to an ID
  <system> W0189        cd to a work package
  <system> tripsy       search all IDs for a word, cd if one match
  <system> 21. tripsy   search inside category 21 (bare '21' also works)
  <system> 20-29 word   search inside area 20-29
  <system> jdex ...     same targets, in the JDex instead of the filesystem
  <system> version      print the version
  <system> setup        print a prompt for your agent, which writes the
                        config file for you. 'jd setup --help' says more
  <system> new id 21 A title
                        make the next free ID in category 21 (beta).
                        'jd new id --help' says more
  <system> new wp 21.41 A title
                        make a new work package (beta). 'jd new wp
                        --help' says more
  <system> beta on|off  turn beta features on or off. 'jd beta' says
                        which

jd is the default system, or the only one. jdex is its JDex, so 'jdex
11.11' and 'jd jdex 11.11' are the same command.

Two or more matches are listed, not entered. Word search ignores case.
An ID or work package in the JDex with no folder gets its folder made.

From a script or an agent, run the program, ~/.jd/cli/bin/jd. Nothing
has to be sourced first.

  ~/.jd/cli/bin/jd 11.11             print the folder for 11.11
  ~/.jd/cli/bin/jd --system P76 22   act on another system. --system
                                     is only read as the first word

A move prints the folder on stdout and exits 0. Set JD_HOOK and it
prints the same folder and exits 3, which is how the shell knows to cd.
EOF
}

# Print sorted matches at one depth. $1 tree, $2 depth, $3 type (d = dirs
# only, a = any), then find tests.
_jd_nav_find() {
  local tree=$1 depth=$2 type=$3
  shift 3
  if [ "$type" = d ]; then
    find "$tree" -mindepth "$depth" -maxdepth "$depth" -type d \( "$@" \) 2>/dev/null | sort
  else
    find "$tree" -mindepth "$depth" -maxdepth "$depth" \( "$@" \) 2>/dev/null | sort
  fi
}

# Draw a sorted match list as a tree. Reads paths on stdin, one per
# line, relative to the tree. Each match is shown under the folder that
# holds it, and a folder is printed once however many matches it holds:
#
#   ├─ 21 Products & services
#   │  ├─ 21.42 CLI tools
#   │  └─ 21.43 Another one
#   └─ W0000-9999 Work packages
#      └─ W0213~31.13 A work package
#
# The area is dropped, because the ID number already says which area it
# is in. A path with no folder above the match, like an area, prints on
# its own.
#
# It needs awk, which is POSIX and on every machine. Without it the list
# prints plain, which is what the tool did before 2.1.0.
_jd_nav_tree() {
  if ! command -v awk >/dev/null 2>&1; then
    while IFS= read -r _jd_p; do printf '  %s\n' "$_jd_p"; done
    return 0
  fi
  awk '
    # Keep the match and the folder that holds it. Nothing above that.
    {
      m = split($0, p, "/")
      from = (m > 2) ? m - 1 : 1
      s = p[from]
      for (k = from + 1; k <= m; k++) s = s "/" p[k]
      line[NR] = s
    }
    END {
      for (i = 1; i <= NR; i++) {
        m = split(line[i], p, "/")
        for (d = 1; d <= m; d++) {
          pre = ""
          for (k = 1; k < d; k++) pre = pre p[k] "/"
          # A folder is printed once, however many matches sit in it.
          if (seen[pre p[d]]++) continue

          # Last of its siblings? Then the branch closes, and the level
          # below it needs no upright bar. The list is sorted, so a name
          # that has changed never comes back.
          last = 1
          for (j = i + 1; j <= NR; j++) {
            mj = split(line[j], q, "/")
            if (mj < d) continue
            qpre = ""
            for (k = 1; k < d; k++) qpre = qpre q[k] "/"
            if (qpre == pre && q[d] != p[d]) { last = 0; break }
          }
          lastat[d] = last

          bar = ""
          for (k = 1; k < d; k++) bar = bar (lastat[k] ? "   " : "│  ")
          printf "  %s%s %s\n", bar, (last ? "└─" : "├─"), p[d]
        }
      }
    }
  '
}

# Act on a match list: arrive if one, report if several, error if none.
# $1 tree, $2 mode fs|jdex, $3 label for messages, $4 matches
_jd_nav_go() {
  local tree=$1 mode=$2 label=$3 m=$4 n p
  n=$(printf '%s' "$m" | grep -c '^')
  if [ "$n" -eq 0 ]; then
    _jd_nav_err "no match for $label"
  elif [ "$n" -eq 1 ]; then
    # A JDex entry is usually a note file: go to its folder.
    if [ "$mode" = jdex ] && [ ! -d "$m" ]; then
      m=$(dirname "$m")
    fi
    _jd_nav_arrive "$m"
  else
    {
      printf 'jd: %s matches for %s:\n' "$n" "$label"
      printf '%s\n' "$m" | while IFS= read -r p; do
        printf '%s\n' "${p#"$tree"/}"
      done | _jd_nav_tree
    } >&2
    return 1
  fi
}

# An ID is in the JDex but has no folder: make the folder from the JDex
# entry's name. $1 root, $2 jdex, $3 ID. Prints the new path on stdout.
# Returns 1 if it does not apply, 2 if it applies but failed.
#
# A normal ID goes in its category, which its own number names. A work
# package always goes in the W0000-9999 area. Its own number does not
# say so, so the area is found by its number, and only the start of that
# number is matched: a system that has renamed the rest of the folder
# still works.
_jd_nav_make_id() {
  local root=$1 jdex=$2 id=$3 jm name num what cm
  [ -n "$jdex" ] && [ -d "$jdex" ] || return 1
  case $id in
    [Ww][0-9][0-9][0-9][0-9])
      jm=$(_jd_nav_find "$jdex" 2 a -iname "$id" -o -iname "$id *" -o -iname "$id~*" -o -iname "$id.md")
      ;;
    *)
      jm=$(_jd_nav_find "$jdex" 3 a -name "$id" -o -name "$id *" -o -name "$id.md")
      ;;
  esac
  [ "$(printf '%s' "$jm" | grep -c '^')" -eq 1 ] || return 1
  name=$(basename -- "$jm")
  case $name in
    *.md) name=${name%.md} ;;
    *.txt) name=${name%.txt} ;;
  esac
  case $id in
    [Ww][0-9][0-9][0-9][0-9])
      cm=$(_jd_nav_find "$root" 1 d -iname 'W0000*')
      what='the W0000-9999 work package area'
      ;;
    *)
      num=${id%%.*}
      cm=$(_jd_nav_find "$root" 2 d -name "$num" -o -name "$num *")
      what="category $num"
      ;;
  esac
  if [ "$(printf '%s' "$cm" | grep -c '^')" -ne 1 ]; then
    _jd_nav_err "the JDex has $id but there is no folder for $what"
    return 2
  fi
  mkdir -- "$cm/$name" || return 2
  printf 'jd: created %s from the JDex\n' "$name" >&2
  printf '%s' "$cm/$name"
}

# Word search for IDs inside one area or category. $1 tree, $2 mode,
# $3 type, $4 container matches, $5 ID depth in container, $6 label, $7+ words
_jd_nav_search_in() {
  local tree=$1 mode=$2 type=$3 container=$4 depth=$5 label=$6 t m
  shift 6
  if [ "$(printf '%s' "$container" | grep -c '^')" -ne 1 ]; then
    _jd_nav_go "$tree" "$mode" "$label" "$container"
    return
  fi
  local -a tests
  tests=(-name '[0-9][0-9].[0-9][0-9]*')
  for t in "$@"; do tests=("${tests[@]}" -iname "*$t*"); done
  m=$(_jd_nav_find "$container" "$depth" "$type" "${tests[@]}")
  _jd_nav_go "$tree" "$mode" "'$*' in $label" "$m"
}

_jd_nav() {
  local sys=$1 cfg row tab root jdex tree mode type a c id m wm t
  shift
  # 'jdex' as the first word is the JDex, whether the user typed it or
  # the jdex command passed it. It is read here so that 'jdex version'
  # and 'jdex --help' answer the same as the jd forms.
  mode=fs
  if [ "${1-}" = jdex ]; then
    mode=jdex
    shift
  fi
  _jd_nav_is_version "${1-}" && return 0
  # Help needs no config and no system. Someone with neither is exactly
  # the person reading it.
  case ${1-} in
    -h|--help|help) _jd_nav_usage; return 0 ;;
  esac
  # 'setup' reads no config either. It is how you get one, so it must
  # work for the person who has none.
  if [ "${1-}" = setup ]; then
    shift
    if command -v _jd_setup >/dev/null 2>&1; then
      _jd_setup "$@"
      return
    fi
    _jd_nav_err "lib/setup.sh is not loaded - run bin/jd, not lib/nav.sh"
    return 1
  fi
  # 'beta' reads and writes one flag in the config, and no system, so it
  # is taken before the system is looked up. A root folder that is not
  # mounted does not stop 'jd beta off'.
  if [ "${1-}" = beta ]; then
    shift
    if command -v _jd_beta >/dev/null 2>&1; then
      _jd_beta "$@"
      return
    fi
    _jd_nav_err "lib/beta.sh is not loaded - run bin/jd, not lib/nav.sh"
    return 1
  fi
  cfg=$(_jd_nav_config)
  command -v jq >/dev/null 2>&1 || { _jd_nav_err "jq is not installed"; return 1; }
  [ -f "$cfg" ] || { _jd_nav_err "$(_jd_nav_no_config_msg "$cfg")"; return 1; }
  # No system named means the default one. It is worked out here, at call
  # time, so a $JD_CONFIG or a config that changed since the shell
  # started is the one that answers.
  if [ -z "$sys" ]; then
    sys=$(_jd_nav_default_sys) || { _jd_nav_err "no systems in $cfg"; return 1; }
  fi
  case $sys in
    '#'*)
      row=$(jq -r --argjson i "${sys#'#'}" \
        '.systems[$i] | [.root, (.jdex // "")] | @tsv' "$cfg" 2>/dev/null)
      ;;
    *)
      row=$(jq -r --arg s "$sys" \
        '.systems[] | select(.sys == $s) | [.root, (.jdex // "")] | @tsv' "$cfg" 2>/dev/null)
      ;;
  esac
  [ -n "$row" ] || { _jd_nav_err "system '$sys' is not in $cfg"; return 1; }
  tab=$(printf '\t')
  root=${row%%"$tab"*}
  jdex=${row#*"$tab"}

  tree=$root
  if [ "$mode" = jdex ]; then
    [ -n "$jdex" ] || { _jd_nav_err "no jdex path for $sys in $cfg"; return 1; }
    tree=$jdex
  fi
  [ -d "$tree" ] || { _jd_nav_err "folder does not exist: $tree"; return 1; }

  if [ $# -eq 0 ]; then
    _jd_nav_arrive "$tree"
    return
  fi
  case $1 in
    new)
      shift
      if command -v _jd_new >/dev/null 2>&1; then
        _jd_new "$sys" "$@"
        return
      fi
      _jd_nav_err "lib/new.sh is not loaded - run bin/jd, not lib/nav.sh"
      return 1
      ;;
  esac

  # In the JDex an ID can be a note file, not a folder.
  type=d
  [ "$mode" = jdex ] && type=a

  # 'NN.NN' or 'NN.NN *' only: '11.11+ Extension' must not match '11.11'.
  case $1 in
    [0-9][0-9]-[0-9][0-9])
      a=$1
      shift
      m=$(_jd_nav_find "$tree" 1 d -name "$a" -o -name "$a *")
      if [ $# -eq 0 ]; then
        _jd_nav_go "$tree" "$mode" "area $a" "$m"
      else
        _jd_nav_search_in "$tree" "$mode" "$type" "$m" 2 "area $a" "$@"
      fi
      ;;
    [0-9][0-9]|[0-9][0-9].)
      c=${1%.}
      shift
      m=$(_jd_nav_find "$tree" 2 d -name "$c" -o -name "$c *")
      if [ $# -eq 0 ]; then
        _jd_nav_go "$tree" "$mode" "category $c" "$m"
      else
        _jd_nav_search_in "$tree" "$mode" "$type" "$m" 1 "category $c" "$@"
      fi
      ;;
    [0-9][0-9].[0-9][0-9])
      id=$1
      shift
      [ $# -eq 0 ] || { _jd_nav_err "unexpected words after '$id'"; return 1; }
      # Depth 3 = area/category/ID. Deeper folders named '11.11' cannot match.
      m=$(_jd_nav_find "$tree" 3 "$type" -name "$id" -o -name "$id *" -o -name "$id.md")
      if [ -z "$m" ] && [ "$mode" = fs ]; then
        m=$(_jd_nav_make_id "$root" "$jdex" "$id")
        case $? in 2) return 1 ;; esac
      fi
      _jd_nav_go "$tree" "$mode" "$id" "$m"
      ;;
    [Ww][0-9][0-9][0-9][0-9])
      id=$1
      shift
      [ $# -eq 0 ] || { _jd_nav_err "unexpected words after '$id'"; return 1; }
      m=$(_jd_nav_find "$tree" 2 "$type" -iname "$id" -o -iname "$id *" -o -iname "$id~*" -o -iname "$id.md")
      if [ -z "$m" ] && [ "$mode" = fs ]; then
        m=$(_jd_nav_make_id "$root" "$jdex" "$id")
        case $? in 2) return 1 ;; esac
      fi
      _jd_nav_go "$tree" "$mode" "$id" "$m"
      ;;
    *)
      # Word search across the whole system: IDs, then work packages.
      local -a tests
      tests=(-name '[0-9][0-9].[0-9][0-9]*')
      for t in "$@"; do tests=("${tests[@]}" -iname "*$t*"); done
      m=$(_jd_nav_find "$tree" 3 "$type" "${tests[@]}")
      tests=(-iname 'w[0-9][0-9][0-9][0-9][ ~]*')
      for t in "$@"; do tests=("${tests[@]}" -iname "*$t*"); done
      wm=$(_jd_nav_find "$tree" 2 "$type" "${tests[@]}")
      if [ -n "$wm" ]; then
        if [ -n "$m" ]; then
          m="$m
$wm"
        else
          m=$wm
        fi
      fi
      _jd_nav_go "$tree" "$mode" "'$*'" "$m"
      ;;
  esac
}
