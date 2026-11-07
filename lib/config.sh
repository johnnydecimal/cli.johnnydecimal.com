# SPDX-License-Identifier: MIT
# config.sh - the version of the config, and the change from version 1
# to version 2
# Part of the Johnny.Decimal command line. Sourced by bin/jd, after
# paths.sh and nav.sh.
#
# jd reads version 2 of the config. In version 2, a system's JDex is one
# object, and a work package's apps are named by "app":
#
#   "jdex": { "app": "obsidian", "path": "/path/to/D25 JDex", "vault": "D25 JDex" }
#   "jdex": { "app": "bear" }
#   "jdex": { "path": "/path/to/a folder of notes" }
#   "workPackages": { "tasks": { "app": "things", "source": "..." } }
#
# Version 1 had "jdex" as a path, and named the note app in
# "workPackages.notes". A config with no "version" is version 1.
#
# The first command that reads a version 1 config changes the file to
# version 2, writes the old file next to it as config.json.v1, and
# prints one line. A config with a version that is greater than 2 is an
# error, because a later jd wrote it.
#
# Requires jq. Works in bash 3.2+ and zsh.

_JD_CONFIG_VERSION=2

# The version 1 to version 2 change, as a jq program. For each system:
#
#   "jdex": path, "workPackages.notes": { "adapter": A, "vault": V }
#       -> "jdex": { "app": A, "path": path, "vault": V }
#   "jdex": path, and no note app
#       -> "jdex": { "app": "obsidian", "path": path }, if the folder
#          contains .obsidian, else "jdex": { "path": path }
#   "workPackages.tasks.adapter" -> "workPackages.tasks.app"
#
# $obsidian is the list of JDex paths that contain .obsidian. The shell
# tests the folders, because jq cannot.
_JD_CONFIG_V1_TO_V2='
  def notes_app: (.workPackages.notes.adapter // "") | if . == "none" then "" else . end;
  .version = 2
  | .systems |= map(
      (if (.jdex | type) == "string" then
         .jdex as $p
         | (notes_app) as $a
         | (.workPackages.notes.vault // "") as $v
         | .jdex = ({}
             + (if $a != "" then {app: $a}
                elif ($obsidian | index($p)) then {app: "obsidian"}
                else {} end)
             + {path: $p}
             + (if $v != "" then {vault: $v} else {} end))
       else . end)
      | if (.workPackages | type) == "object" then
          .workPackages |= (
            del(.notes)
            | if (.tasks | type) == "object" and (.tasks | has("adapter")) then
                .tasks |= ({app: .adapter} + del(.adapter))
              else . end)
          | if .workPackages == {} then del(.workPackages) else . end
        else . end
    )
'

# The version of the config $1. A config with no "version" is version 1.
# Prints nothing for a file that is not a JSON object.
_jd_config_version() {
  jq -r 'if type == "object" then (.version // 1 | tostring) else empty end' "$1" 2>/dev/null
}

# The JDex paths in config $1 that contain a .obsidian folder, as a JSON
# list.
_jd_config_obsidian_paths() {
  local p list='[]'
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -d "$p/.obsidian" ] || continue
    list=$(printf '%s' "$list" | jq -c --arg p "$p" '. + [$p]')
  done <<EOF
$(jq -r '.systems[]? | .jdex | select(type == "string")' "$1" 2>/dev/null)
EOF
  printf '%s' "$list"
}

# Print config $1 as version 2. $1 is a version 1 config.
_jd_config_v2_of() {
  jq --indent 2 --argjson obsidian "$(_jd_config_obsidian_paths "$1")" \
    "$_JD_CONFIG_V1_TO_V2" "$1"
}

# Change config $1 to version 2, and write the old file as $1.v1, whose
# path is then in $_JD_CONFIG_OLD. The
# symlink is resolved first, and the mode is copied, as 'jd beta' does,
# so that a config that is a link into a dotfiles repo stays a link.
_jd_config_migrate() {
  local cfg=$1 link dir tmp mode
  while [ -L "$cfg" ]; do
    link=$(readlink "$cfg") || return 1
    case $link in
      /*) cfg=$link ;;
      *) cfg=$(dirname -- "$cfg")/$link ;;
    esac
  done
  dir=$(dirname -- "$cfg")
  [ -w "$dir" ] || return 1
  mode=$(stat -c '%a' "$cfg" 2>/dev/null || stat -f '%Lp' "$cfg" 2>/dev/null) || mode=''
  case $mode in '' | *[!0-7]*) mode='' ;; esac
  tmp=$(mktemp "$dir/.jd-config.XXXXXX") || return 1
  if _jd_config_v2_of "$cfg" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    [ -n "$mode" ] && chmod "$mode" "$tmp"
    # An earlier copy of the old file is never replaced.
    [ -e "$cfg.v1" ] || cp -p -- "$cfg" "$cfg.v1" || { rm -f "$tmp"; return 1; }
    _JD_CONFIG_OLD=$cfg.v1
    mv -f "$tmp" "$cfg"
  else
    rm -f "$tmp"
    return 1
  fi
}

# Make sure the config is version 2. Every command that reads the config
# calls this first. A version 1 config is changed to version 2. Returns
# 1, and prints why, when jd cannot read the config.
_jd_config_ready() {
  local cfg v
  cfg=$(_jd_paths_config)
  [ -f "$cfg" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  v=$(_jd_config_version "$cfg")
  case $v in
    "$_JD_CONFIG_VERSION" | '') return 0 ;;
    1)
      if ! _jd_config_migrate "$cfg"; then
        _jd_nav_err "the config is version 1, and jd could not change it to version 2: $cfg"
        return 1
      fi
      printf 'jd: changed the config to version 2. The old file is %s\n' "$_JD_CONFIG_OLD" >&2
      return 0
      ;;
    *[!0-9]*)
      _jd_nav_err "the config has a version that is not a number, '$v': $cfg"
      return 1
      ;;
    *)
      if [ "$v" -gt "$_JD_CONFIG_VERSION" ]; then
        _jd_nav_err "the config is version $v, and this jd reads version $_JD_CONFIG_VERSION - run 'jd update'"
      else
        _jd_nav_err "the config is version $v, and this jd reads version $_JD_CONFIG_VERSION: $cfg"
      fi
      return 1
      ;;
  esac
}
