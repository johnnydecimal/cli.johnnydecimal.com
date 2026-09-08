# SPDX-License-Identifier: MIT
# theme.zsh - the whole Johnny.Decimal prompt for zsh
# Part of the Johnny.Decimal command line. jd.sh does NOT load this file.
# You source it yourself, after jd.sh:
#
#   source ~/.jd/cli/jd.sh
#   source ~/.jd/cli/lib/theme.zsh
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
# It sets PROMPT only when you have not set one. Any PROMPT that is not a
# stock zsh one is yours, so it says one line and leaves it alone.
#
# The chevron colours are yours. Set them before you source this file:
#
#   JD_CHEVRON1=yellow
#   JD_CHEVRON2=red
#
# Git status is not part of this. The prompt calls gitprompt, and there is
# a do-nothing gitprompt here so it works without one. For the real thing,
# load git-prompt.zsh (https://github.com/woefe/git-prompt.zsh) before
# this file and the prompt picks it up.

if [ -z "${ZSH_VERSION-}" ]; then
  printf 'jd: the prompt theme is zsh only, so it did not load\n' >&2
  return 0
fi

# _jd_pwd is the Johnny.Decimal path, from lib/prompt.zsh. Without it the
# prompt would print its name, so stub it with the ordinary path.
if ! typeset -f _jd_pwd >/dev/null 2>&1; then
  _jd_pwd() { print -r -- "${PWD/#$HOME/~}"; }
  if [ -z "${_JD_CLI_VERSION-}" ]; then
    printf 'jd: source jd.sh before the theme, or the prompt has no JD path\n' >&2
  fi
fi

# The prompt calls gitprompt whether you have it or not.
if ! typeset -f gitprompt >/dev/null 2>&1; then
  gitprompt() { :; }
fi

# The prompts zsh and the systems it ships on set for you. Anything else
# in PROMPT is the user's own, and we do not touch it. Our own prompt is
# ours, so sourcing this file twice is quiet.
_jd_theme_is_stock() {
  case ${PROMPT-} in
    ''|'%#'|'%# '|'%m%#'|'%m%# '|'%m# '|'%n@%m %1~ %#'|'%n@%m %1~ %# '|'%n@%m:%~%#'|'%n@%m:%~%# ')
      return 0
      ;;
  esac
  [[ -n "${_JD_THEME_PROMPT-}" && "$PROMPT" == "$_JD_THEME_PROMPT" ]] && return 0
  return 1
}

if _jd_theme_is_stock; then
  # $(_jd_pwd) and $(gitprompt) run at every prompt, which needs this.
  setopt prompt_subst
  : ${JD_CHEVRON1:=yellow}
  : ${JD_CHEVRON2:=red}
  PROMPT=$'┏╸%(?..%F{red}%?%f · )%B$(_jd_pwd)%b$(gitprompt)\n┗╸%m %F{$JD_CHEVRON1}❯%f%F{$JD_CHEVRON2}❯%f '
  _JD_THEME_PROMPT=$PROMPT
else
  printf 'jd: you have your own PROMPT, so the theme did not load. Use $(_jd_pwd) in it.\n' >&2
fi

unset -f _jd_theme_is_stock
