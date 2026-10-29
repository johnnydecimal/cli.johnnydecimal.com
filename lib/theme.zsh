# SPDX-License-Identifier: MIT
# theme.zsh - the whole Johnny.Decimal prompt for zsh
# Part of the Johnny.Decimal command line. jd.sh does NOT load this file.
# You source it yourself, after jd.sh:
#
#   source ~/.local/share/johnnydecimal/cli/jd.sh
#   source ~/.local/share/johnnydecimal/cli/lib/theme.zsh
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
# It sets PROMPT, whatever PROMPT you had. Sourcing this file is the
# request, so put the line last, after anything else that sets the
# prompt. A prompt library usually sets a prompt of its own, and the
# last file to set PROMPT takes precedence.
#
# To keep a prompt of your own, do not source this file. Put $(_jd_pwd)
# in your own PROMPT instead, with setopt prompt_subst, and you have the
# Johnny.Decimal path without the rest of this.
#
# The chevron colours are yours. They are read at every prompt, so set
# them before this line or after it:
#
#   JD_CHEVRON1=yellow
#   JD_CHEVRON2=red
#
# Git status is not part of this. The prompt calls gitprompt, and there
# is an empty gitprompt here so the prompt works without one. For git
# status, load git-prompt.zsh (https://github.com/woefe/git-prompt.zsh)
# before this file, and the prompt uses it.

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

# $(_jd_pwd) and $(gitprompt) run at every prompt, which requires this.
setopt prompt_subst
: ${JD_CHEVRON1:=yellow}
: ${JD_CHEVRON2:=red}
PROMPT=$'┏╸%(?..%F{red}%?%f · )%B$(_jd_pwd)%b$(gitprompt)\n┗╸%m %F{$JD_CHEVRON1}❯%f%F{$JD_CHEVRON2}❯%f '
