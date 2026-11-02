# SPDX-License-Identifier: MIT
# prompt.bash - Johnny.Decimal prompt path for bash
# Part of the Johnny.Decimal command line. Loaded by jd.sh under bash only.
# The zsh version is lib/prompt.zsh, and the two print the same path.
#
# Use $(_jd_pwd) in your PS1 in place of \w. Outside a Johnny.Decimal
# system it prints the normal path. Inside one it anchors at the deepest
# numbered folder and prints, for example:
#   D25:…/11.11 Structure & registrations
# A system with no sys in the config (fine when it is the only one) has
# no label to print, so the anchor is printed with no prefix:
# …/11.11 ...
#
# It reads the systems from the config. jd.sh has run 'jd paths config',
# and $_jd_hook_cfg contains the path while this file is sourced.
# Sourced on its own, with no jd.sh, this file runs the program itself:
# BASH_SOURCE is this file, and the program is two folders up.
# Requires jq. The config is read once, when this file is sourced.
# Works in bash 3.2+.

if [ -z "${BASH_VERSION-}" ]; then
  printf 'jd: lib/prompt.bash is for bash. In zsh, jd.sh loads lib/prompt.zsh\n' >&2
  return 0
fi

_jd_prompt_sys=()
_jd_prompt_root=()
_jd_prompt_cfg="${_jd_hook_cfg-}"
if [[ -z "$_jd_prompt_cfg" ]]; then
  _jd_prompt_cfg="$("$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/bin/jd" paths config 2>/dev/null)"
fi
if [[ -f "$_jd_prompt_cfg" ]] && command -v jq >/dev/null; then
  # A tab is IFS whitespace, so `read -r a b` silently discards a leading
  # empty field (no sys) instead of splitting it off. Read the whole
  # line and slice it by hand instead, like nav.sh does.
  _jd_tab=$'\t'
  while IFS= read -r _jd_row; do
    [[ -n "$_jd_row" ]] || continue
    _jd_s="${_jd_row%%$_jd_tab*}"
    _jd_r="${_jd_row#*$_jd_tab}"
    if [[ -n "$_jd_r" ]]; then
      _jd_prompt_sys[${#_jd_prompt_sys[@]}]="$_jd_s"
      _jd_prompt_root[${#_jd_prompt_root[@]}]="$_jd_r"
    fi
  done < <(jq -r '.systems[] | [(.sys // ""), .root] | @tsv' "$_jd_prompt_cfg" 2>/dev/null)
fi
unset _jd_prompt_cfg _jd_tab _jd_row _jd_s _jd_r

_jd_pwd() {
  local i system root rel part anchor found=0 prefix tilde='~'
  local -a parts
  # Arrays are indexed from 0 in bash, and from 1 in zsh.
  i=0
  while [[ $i -lt ${#_jd_prompt_root[@]} ]]; do
    root="${_jd_prompt_root[$i]}"
    if [[ "$PWD" == "$root" || "$PWD" == "$root"/* ]]; then
      system="${_jd_prompt_sys[$i]}"
      found=1
      break
    fi
    i=$((i + 1))
  done
  # The ~ is in a variable because bash versions differ on whether a
  # bare ~ in a replacement is expanded to $HOME.
  if [[ $found -eq 0 ]]; then
    printf '%s\n' "${PWD/#"$HOME"/$tilde}"
    return
  fi
  prefix=""
  [[ -n "$system" ]] && prefix="$system:"
  if [[ "$PWD" == "$root" ]]; then
    printf '%s\n' "${prefix}~"
    return
  fi

  rel="${PWD#"$root"/}"
  IFS=/ read -r -a parts <<<"$rel"
  anchor=-1
  i=0
  while [[ $i -lt ${#parts[@]} ]]; do
    part="${parts[$i]}"
    [[ "$part" == [0-9]* ]] && anchor=$i
    i=$((i + 1))
  done

  if [[ $anchor -lt 0 ]]; then
    printf '%s\n' "${prefix}…/$rel"
  else
    printf '%s\n' "${prefix}…/$(IFS=/; printf '%s' "${parts[*]:$anchor}")"
  fi
}
