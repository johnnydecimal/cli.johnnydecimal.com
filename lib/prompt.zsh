# SPDX-License-Identifier: MIT
# prompt.zsh - Johnny.Decimal prompt path for zsh
# Part of the Johnny.Decimal command line. Loaded by jd.sh under zsh only.
#
# Use $(_jd_pwd) in your PROMPT in place of %~. Outside a Johnny.Decimal
# system it prints the normal path. Inside one it anchors at the deepest
# numbered folder and prints, for example:
#   D25:…/11.11 Structure & registrations
# A system with no sys in the config (fine when it is the only one) has
# no label to print, so the anchor shows with no prefix: …/11.11 ...
#
# It reads the systems from ~/.jd/config.json (override with $JD_CONFIG).
# Needs jq. The config is read once, when this file is sourced.

_jd_prompt_sys=()
_jd_prompt_root=()
_jd_prompt_cfg="${JD_CONFIG:-$HOME/.jd/config.json}"
if [[ -f "$_jd_prompt_cfg" ]] && command -v jq >/dev/null; then
  # A tab is IFS whitespace, so `read -r a b` silently drops a leading
  # empty field (no sys) instead of splitting it off. Read the whole
  # line and slice it by hand instead, like nav.sh does.
  _jd_tab=$'\t'
  while IFS= read -r _jd_row; do
    [[ -n "$_jd_row" ]] || continue
    _jd_s="${_jd_row%%$_jd_tab*}"
    _jd_r="${_jd_row#*$_jd_tab}"
    if [[ -n "$_jd_r" ]]; then
      _jd_prompt_sys+=("$_jd_s")
      _jd_prompt_root+=("$_jd_r")
    fi
  done < <(jq -r '.systems[] | [(.sys // ""), .root] | @tsv' "$_jd_prompt_cfg" 2>/dev/null)
fi
unset _jd_prompt_cfg _jd_tab _jd_row _jd_s _jd_r

_jd_pwd() {
  local i system root rel part anchor found=0 prefix
  for (( i = 1; i <= $#_jd_prompt_root; i++ )); do
    root="${_jd_prompt_root[$i]}"
    if [[ "$PWD" == "$root" || "$PWD" == "$root"/* ]]; then
      system="${_jd_prompt_sys[$i]}"
      found=1
      break
    fi
  done
  if (( ! found )); then
    echo "${PWD/#$HOME/~}"
    return
  fi
  prefix=""
  [[ -n "$system" ]] && prefix="$system:"
  if [[ "$PWD" == "$root" ]]; then
    echo "${prefix}~"
    return
  fi

  rel="${PWD#$root/}"
  local -a parts=("${(@s:/:)rel}")
  anchor=0
  i=1
  for part in $parts; do
    [[ "$part" == [0-9]* ]] && anchor=$i
    ((i++))
  done

  if (( anchor == 0 )); then
    echo "${prefix}…/$rel"
  else
    echo "${prefix}…/${(j:/:)parts[$anchor,-1]}"
  fi
}
