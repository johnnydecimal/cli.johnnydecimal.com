# SPDX-License-Identifier: MIT
# prompt.zsh - Johnny.Decimal prompt path for zsh
# Part of the Johnny.Decimal command line. Loaded by jd.sh under zsh only.
#
# Use $(_jd_pwd) in your PROMPT in place of %~. Outside a Johnny.Decimal
# system it prints the normal path. Inside one it anchors at the deepest
# numbered folder and prints, for example:
#   D25:…/11.11 Structure & registrations
#
# It reads the systems from ~/.jd/config.json (override with $JD_CONFIG).
# Needs jq. The config is read once, when this file is sourced.

_jd_prompt_sys=()
_jd_prompt_root=()
_jd_prompt_cfg="${JD_CONFIG:-$HOME/.jd/config.json}"
if [[ -f "$_jd_prompt_cfg" ]] && command -v jq >/dev/null; then
  while IFS=$'\t' read -r _jd_s _jd_r; do
    if [[ -n "$_jd_s" && -n "$_jd_r" ]]; then
      _jd_prompt_sys+=("$_jd_s")
      _jd_prompt_root+=("$_jd_r")
    fi
  done < <(jq -r '.systems[] | [.sys, .root] | @tsv' "$_jd_prompt_cfg" 2>/dev/null)
fi
unset _jd_prompt_cfg _jd_s _jd_r

_jd_pwd() {
  local i system root rel part anchor
  for (( i = 1; i <= $#_jd_prompt_sys; i++ )); do
    root="${_jd_prompt_root[$i]}"
    if [[ "$PWD" == "$root" || "$PWD" == "$root"/* ]]; then
      system="${_jd_prompt_sys[$i]}"
      break
    fi
  done
  if [[ -z "$system" ]]; then
    echo "${PWD/#$HOME/~}"
    return
  fi
  if [[ "$PWD" == "$root" ]]; then
    echo "$system:~"
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
    echo "$system:…/$rel"
  else
    echo "$system:…/${(j:/:)parts[$anchor,-1]}"
  fi
}
