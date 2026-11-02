# SPDX-License-Identifier: MIT
# theme.bash - the whole Johnny.Decimal prompt for bash
# Part of the Johnny.Decimal command line. jd.sh does NOT load this file.
# The zsh version is lib/theme.zsh, and the two draw the same prompt.
# You source it yourself, after jd.sh:
#
#   source ~/.local/share/johnnydecimal/cli/jd.sh
#   source ~/.local/share/johnnydecimal/cli/lib/theme.bash
#
# You get the prompt Johnny uses. Two lines:
#
#   ┏╸D25:…/11.11 First ID
#   ┗╸mymac ❯❯
#
# Line one is the Johnny.Decimal path, from _jd_pwd. In front of it, when
# the last command failed, is its exit status. Line two is the host name
# and the chevrons you type after.
#
# It sets PS1, whatever PS1 you had. Sourcing this file is the request,
# so put the line last, after anything else that sets the prompt.
#
# To keep a prompt of your own, do not source this file. Put $(_jd_pwd)
# in your own PS1 instead, in single quotes, and you have the
# Johnny.Decimal path without the rest of this.
#
# The chevron colours are yours. They are read at every prompt, so set
# them before this line or after it. The values are the ones zsh takes:
# black, red, green, yellow, blue, magenta, cyan, white, default, or a
# number from 0 to 255. Any other value prints no colour.
#
#   JD_CHEVRON1=yellow
#   JD_CHEVRON2=red
#
# Git status is not part of this. The prompt calls gitprompt. If you
# have not defined one, the gitprompt here calls __git_ps1 from git's
# own git-prompt.sh when that is loaded, and prints nothing when it is
# not. Its GIT_PS1_* variables apply as usual. __git_ps1 prints no
# colour from inside PS1: that is how git-prompt.sh works.
#
# This file leaves three things in your shell, because the prompt calls
# them at every prompt: _jd_theme_rc in PROMPT_COMMAND, and the
# functions _jd_theme_status and _jd_theme_fg.
#
# Works in bash 3.2+.

if [ -z "${BASH_VERSION-}" ]; then
  printf 'jd: lib/theme.bash is for bash. In zsh, source lib/theme.zsh\n' >&2
  return 0
fi

# _jd_pwd is the Johnny.Decimal path, from lib/prompt.bash. Without it
# the prompt would fail at every prompt, so stub it with the ordinary
# path.
if ! declare -F _jd_pwd >/dev/null 2>&1; then
  _jd_pwd() {
    local tilde='~'
    printf '%s\n' "${PWD/#"$HOME"/$tilde}"
  }
  if [ -z "${_JD_CLI_VERSION-}" ]; then
    printf 'jd: source jd.sh before the theme, or the prompt has no JD path\n' >&2
  fi
fi

# The prompt calls gitprompt whether you have it or not.
if ! declare -F gitprompt >/dev/null 2>&1; then
  gitprompt() {
    if declare -F __git_ps1 >/dev/null 2>&1; then
      __git_ps1
    fi
  }
fi

# The exit status of the last command. PS1 cannot read it directly: bash
# runs PROMPT_COMMAND before it expands PS1, and that resets $?. macOS
# Terminal sets a PROMPT_COMMAND of its own. So the first command in
# PROMPT_COMMAND stores $? here. If PROMPT_COMMAND is an array (bash
# 5.1+), this is element 0, which runs first.
case ${PROMPT_COMMAND-} in
  '_jd_theme_rc=$?'*) ;;
  *) PROMPT_COMMAND="_jd_theme_rc=\$?${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

# The status and a separator, in red, or nothing when it is 0.
_jd_theme_status() {
  [ "${_jd_theme_rc:-0}" = 0 ] && return 0
  printf '\001\033[31m\002%s\001\033[39m\002 · ' "$_jd_theme_rc"
}

# The escape that sets the foreground to a colour, as zsh's %F{...} does.
# \001 and \002 tell readline that the escape has no width. In PS1 that
# is \[ and \], but bash reads those before it runs $(...), not after.
_jd_theme_fg() {
  local code
  case ${1-} in
    black) code=30 ;;
    red) code=31 ;;
    green) code=32 ;;
    yellow) code=33 ;;
    blue) code=34 ;;
    magenta) code=35 ;;
    cyan) code=36 ;;
    white) code=37 ;;
    default) code=39 ;;
    [0-7]) code=$((30 + $1)) ;;
    [0-9][0-9] | [0-9][0-9][0-9])
      [ "$1" -le 255 ] || return 0
      code="38;5;$1"
      ;;
    *) return 0 ;;
  esac
  printf '\001\033[%sm\002' "$code"
}

# $(...) in PS1 runs at every prompt, which requires promptvars. It is
# on by default.
shopt -s promptvars
: "${JD_CHEVRON1:=yellow}"
: "${JD_CHEVRON2:=red}"
PS1='┏╸$(_jd_theme_status)\[\e[1m\]$(_jd_pwd)\[\e[22m\]$(gitprompt)\n┗╸\h $(_jd_theme_fg "$JD_CHEVRON1")❯$(_jd_theme_fg "$JD_CHEVRON2")❯$(_jd_theme_fg default) '
