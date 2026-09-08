# SPDX-License-Identifier: MIT
# nav.sh - Johnny.Decimal shell navigation
# Part of the Johnny.Decimal command line. Loaded by jd.sh, which sets
# $_JD_CLI_VERSION and $_JD_CLI_HELP_URL.
#
# It reads ~/.jd/config.json (override with $JD_CONFIG) and defines:
#   - one function per system, named by its lowercase sys id: d25, p76
#   - jd, which acts on the default system (or the only system)
#
# Needs jq. Works in bash 3.2+ and zsh.

_jd_nav_config() { printf '%s' "${JD_CONFIG:-$HOME/.jd/config.json}"; }

_jd_nav_err() { printf 'jd: %s\n' "$*" >&2; return 1; }

# Print the version if $1 asks for it. Returns 0 if it did.
_jd_nav_is_version() {
  case $1 in
    -v|--version|version) printf 'jd %s\n' "$_JD_CLI_VERSION"; return 0 ;;
  esac
  return 1
}

_jd_nav_usage() {
  cat <<'EOF'
usage: <system> [jdex] [target]

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

Two or more matches are listed, not entered. Word search ignores case.
An ID with a JDex entry but no folder gets its folder made for it.
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

# Act on a match list: cd if one, report if several, error if none.
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
    cd -- "$m" && pwd
  else
    {
      printf 'jd: %s matches for %s:\n' "$n" "$label"
      printf '%s\n' "$m" | while IFS= read -r p; do
        printf '  %s\n' "${p#"$tree"/}"
      done
    } >&2
    return 1
  fi
}

# An ID is in the JDex but has no folder: make the folder from the JDex
# entry's name. $1 root, $2 jdex, $3 ID. Prints the new path on stdout.
# Returns 1 if it does not apply, 2 if it applies but failed.
_jd_nav_make_id() {
  local root=$1 jdex=$2 id=$3 jm name cnum cm
  [ -n "$jdex" ] && [ -d "$jdex" ] || return 1
  jm=$(_jd_nav_find "$jdex" 3 a -name "$id" -o -name "$id *" -o -name "$id.md")
  [ "$(printf '%s' "$jm" | grep -c '^')" -eq 1 ] || return 1
  name=$(basename -- "$jm")
  case $name in
    *.md) name=${name%.md} ;;
    *.txt) name=${name%.txt} ;;
  esac
  cnum=${id%%.*}
  cm=$(_jd_nav_find "$root" 2 d -name "$cnum" -o -name "$cnum *")
  if [ "$(printf '%s' "$cm" | grep -c '^')" -ne 1 ]; then
    _jd_nav_err "the JDex has $id but there is no folder for category $cnum"
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
  _jd_nav_is_version "$1" && return 0
  cfg=$(_jd_nav_config)
  command -v jq >/dev/null 2>&1 || { _jd_nav_err "jq is not installed"; return 1; }
  [ -f "$cfg" ] || { _jd_nav_err "no config at $cfg - see $_JD_CLI_HELP_URL"; return 1; }
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

  mode=fs
  tree=$root
  if [ "$1" = jdex ]; then
    shift
    [ -n "$jdex" ] || { _jd_nav_err "no jdex path for $sys in $cfg"; return 1; }
    mode=jdex
    tree=$jdex
  fi
  [ -d "$tree" ] || { _jd_nav_err "folder does not exist: $tree"; return 1; }

  if [ $# -eq 0 ]; then
    cd -- "$tree" && pwd
    return
  fi
  case $1 in
    -h|--help|help) _jd_nav_usage; return 0 ;;
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
      m=$(_jd_nav_find "$tree" 2 "$type" -iname "$id" -o -iname "$id *")
      _jd_nav_go "$tree" "$mode" "$id" "$m"
      ;;
    *)
      # Word search across the whole system: IDs, then work packages.
      local -a tests
      tests=(-name '[0-9][0-9].[0-9][0-9]*')
      for t in "$@"; do tests=("${tests[@]}" -iname "*$t*"); done
      m=$(_jd_nav_find "$tree" 3 "$type" "${tests[@]}")
      tests=(-iname 'w[0-9][0-9][0-9][0-9] *')
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

_jd_nav_setup() {
  local cfg n sys fn
  cfg=$(_jd_nav_config)
  if [ ! -f "$cfg" ]; then
    jd() {
      _jd_nav_is_version "$1" && return 0
      _jd_nav_err "no config at $(_jd_nav_config) - see $_JD_CLI_HELP_URL"
    }
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    jd() {
      _jd_nav_is_version "$1" && return 0
      _jd_nav_err "jq is not installed"
    }
    return 0
  fi
  n=$(jq -r '.systems | length' "$cfg" 2>/dev/null)
  if [ -z "$n" ] || [ "$n" = 0 ] || [ "$n" = null ]; then
    jd() {
      _jd_nav_is_version "$1" && return 0
      _jd_nav_err "no systems in $(_jd_nav_config)"
    }
    return 0
  fi

  # One function per system, named by its lowercase sys id. More than one
  # system means every entry needs a sys, so a missing one is an error,
  # not a skip.
  if [ "$n" -gt 1 ]; then
    while IFS= read -r sys; do
      if [ -z "$sys" ] || [ "$sys" = null ]; then
        _jd_nav_err "a system in $cfg has no 'sys' - every entry needs one when there is more than one system"
        continue
      fi
      fn=$(printf '%s' "$sys" | tr 'A-Z' 'a-z')
      case $fn in
        *[!a-z0-9_]*|[0-9]*) _jd_nav_err "cannot make a function for sys id '$sys'"; continue ;;
      esac
      eval "$fn() { _jd_nav '$sys' \"\$@\"; }"
    done <<EOF
$(jq -r '.systems[].sys' "$cfg")
EOF
  fi

  # jd acts on the default system, or the only one. Fall back to its
  # array index when it has no sys - a single system does not need one.
  sys=$(jq -r '(.systems | (map(select(.default == true))[0] // .[0])).sys // empty' "$cfg")
  if [ -n "$sys" ]; then
    eval "jd() { _jd_nav '$sys' \"\$@\"; }"
  else
    idx=$(jq -r '(.systems | to_entries | (map(select(.value.default == true))[0] // .[0])).key' "$cfg")
    eval "jd() { _jd_nav '#$idx' \"\$@\"; }"
  fi
}

_jd_nav_setup
