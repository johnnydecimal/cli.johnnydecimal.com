# SPDX-License-Identifier: MIT
# beta.sh - the beta flag, and 'jd beta', which turns it on and off
# Part of the Johnny.Decimal command line. Sourced by bin/jd, before the
# files that hold beta features.
#
# Beta is one flag for every beta feature: "beta": true at the top level
# of the config, straight after "version". JD_BETA=1 turns it on for one
# shell and writes nothing. The flag is read each time a feature asks,
# never cached, so 'jd beta on' works in the shell you are in.
#
# A beta feature calls _jd_beta_on and stops with a one-line error when
# it returns 1. 'jd beta' is the only thing that writes the flag.
#
# Needs jq. Works in bash 3.2+ and zsh.

_jd_beta_usage() {
  cat <<'EOF2'
usage: <system> beta [status|on|off]

  jd beta             say whether beta is on
  jd beta on          turn beta on: write "beta": true to the config
                      BETA FEATURES ARE UNSTABLE AND MODIFY YOUR DATA
                      YOU PROBABLY SHOULDN'T USE THEM :-)
  jd beta off         turn beta off: write "beta": false to the config

Beta features may change, or go, without notice. There is one flag for
all of them. JD_BETA=1 turns beta on for one shell, and writes nothing.
EOF2
}

# Return 0 if beta is on, by JD_BETA or by the config.
_jd_beta_on() {
  case ${JD_BETA-} in 1 | true | yes) return 0 ;; esac
  _jd_beta_in_config
}

# Return 0 if the config holds "beta": true. JD_BETA plays no part.
_jd_beta_in_config() {
  local cfg
  cfg=$(_jd_nav_config)
  [ -f "$cfg" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [ "$(jq -r '.beta // false' "$cfg" 2>/dev/null)" = true ]
}

# Write "beta": $1 into the config. $1 is true or false.
#
# A temp file in the config's own folder, then a rename, so a failed
# write can never truncate the config. The symlink is resolved first and
# the mode is carried over, or a config that is a link into a dotfiles
# repo would be replaced by a private-mode regular file.
_jd_beta_write() {
  local value=$1 cfg dir tmp link mode
  cfg=$(_jd_nav_config)
  while [ -L "$cfg" ]; do
    link=$(readlink "$cfg") || return 1
    case $link in
      /*) cfg=$link ;;
      *) cfg=$(dirname -- "$cfg")/$link ;;
    esac
  done
  dir=$(dirname -- "$cfg")
  [ -w "$dir" ] || return 1
  # GNU stat first. BSD stat rejects -c and prints nothing on stdout. The
  # other order is not safe: GNU stat reads -f as a different option, and
  # can print before it fails.
  mode=$(stat -c '%a' "$cfg" 2>/dev/null || stat -f '%Lp' "$cfg" 2>/dev/null) || mode=''
  case $mode in '' | *[!0-7]*) mode='' ;; esac
  tmp=$(mktemp "$dir/.jd-config.XXXXXX") || return 1
  # 'if has' rather than '{version}': on a config with no version key,
  # '{version}' writes "version": null into the file. del(...) on the
  # right, or the old "beta" would win and the write would do nothing.
  if jq --indent 2 --argjson v "$value" \
    '(if has("version") then {version} else {} end) + {beta: $v} + del(.version, .beta)' \
    "$cfg" >"$tmp" 2>/dev/null &&
    [ -s "$tmp" ]; then
    [ -n "$mode" ] && chmod "$mode" "$tmp"
    mv -f "$tmp" "$cfg"
  else
    rm -f "$tmp"
    return 1
  fi
}

# The warning, on stderr. Printed when beta is turned on, and when a beta
# feature is used with beta off. The help text holds the same two lines.
_jd_beta_warn() {
  printf '    %s\n' \
    'BETA FEATURES ARE UNSTABLE AND MODIFY YOUR DATA' \
    "YOU PROBABLY SHOULDN'T USE THEM :-)" >&2
}

# Say whether beta is on, and why. On stdout, because it is the answer.
_jd_beta_say() {
  if _jd_beta_in_config; then
    printf 'beta is on\n'
  elif _jd_beta_on; then
    printf 'beta is on in this shell, because JD_BETA is set. The config has it off.\n'
  else
    printf 'beta is off\n'
  fi
}

# 'jd beta'. $@ the words after 'beta'.
_jd_beta() {
  local word=${1-status} cfg
  case $word in
    -h | --help | help) _jd_beta_usage; return 0 ;;
    status | on | off) ;;
    *) _jd_nav_err "'$word' is not a beta command - see 'jd beta --help'"; return 1 ;;
  esac
  if [ $# -gt 1 ]; then
    _jd_nav_err "'jd beta $word' takes nothing after it"
    return 1
  fi
  command -v jq >/dev/null 2>&1 || { _jd_nav_err "jq is not installed"; return 1; }
  cfg=$(_jd_nav_config)
  [ -f "$cfg" ] || { _jd_nav_err "no config at $cfg - see $_JD_CLI_HELP_URL"; return 1; }
  if ! jq -e 'type == "object"' "$cfg" >/dev/null 2>&1; then
    _jd_nav_err "the config is not a JSON object, so beta cannot be read or written: $cfg"
    return 1
  fi

  # Write only when the answer changes, so that a config already in the
  # state asked for keeps its own layout. Off is the default: a config
  # with no "beta" is already off.
  case $word in
    on)
      if ! _jd_beta_in_config; then
        _jd_beta_write true || { _jd_nav_err "could not write $cfg"; return 1; }
      fi
      _jd_beta_warn
      ;;
    off)
      if _jd_beta_in_config; then
        _jd_beta_write false || { _jd_nav_err "could not write $cfg"; return 1; }
      fi
      ;;
  esac
  _jd_beta_say
}
