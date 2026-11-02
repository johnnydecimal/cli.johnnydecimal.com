# SPDX-License-Identifier: MIT
# theme-bash.sh - the whole-prompt theme for bash, lib/theme.bash
#
# The bash version of cases/theme.sh. jd.sh does not load the theme. The
# user sources it. So these tests source it by hand, the way a .bashrc
# does, and read PS1 and PROMPT_COMMAND afterwards. The last group runs
# an interactive bash, which prints its expanded prompt on stderr.
#
# The requirement is the same as in zsh: sourcing it sets PS1, whatever
# PS1 was there.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# Source the theme and record what it printed. It changes this shell on
# purpose, so there is no _jd_t_run here.
_jd_tb_source() {
  . "$JD_T_REPO/lib/theme.bash" >"$JD_T_TMP/.out" 2>"$JD_T_TMP/.err"
  JD_T_STATUS=$?
  JD_T_OUT=$(cat "$JD_T_TMP/.out")
  JD_T_ERR=$(cat "$JD_T_TMP/.err")
}

# Back to a shell that has never sourced the theme.
_jd_tb_forget() {
  unset -f gitprompt __git_ps1 2>/dev/null || true
  PS1='\h\$ '
  PROMPT_COMMAND=''
}

# ---------------------------------------------------------------- in zsh

if [ -n "${ZSH_VERSION-}" ]; then
  PS1='%m%# '
  _jd_tb_source
  _jd_t_contains 'bash theme: in zsh it names the zsh theme' 'lib/theme.zsh' "$JD_T_ERR"
  _jd_t_eq 'bash theme: in zsh PS1 does not change' '%m%# ' "$PS1"
  _jd_t_summary
fi

# ------------------------------------------------------------ the prompt

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_tb_forget
_jd_tb_source

_jd_t_eq 'bash theme: it prints nothing when it is sourced' '' "$JD_T_ERR"
_jd_t_eq 'bash theme: it prints nothing on stdout either' '' "$JD_T_OUT"
_jd_t_contains 'bash theme: the prompt has the JD path in it' '$(_jd_pwd)' "$PS1"
_jd_t_contains 'bash theme: the prompt has the top corner' '┏╸' "$PS1"
_jd_t_contains 'bash theme: the prompt has the bottom corner' '┗╸' "$PS1"
_jd_t_contains 'bash theme: the prompt has the host name' '\h' "$PS1"
_jd_t_contains 'bash theme: the prompt has both chevrons' \
  '$(_jd_theme_fg "$JD_CHEVRON1")❯$(_jd_theme_fg "$JD_CHEVRON2")❯' "$PS1"
_jd_t_contains 'bash theme: the prompt has the git call' '$(gitprompt)' "$PS1"

if shopt -q promptvars; then
  _jd_t_ok 'bash theme: promptvars is set, so $(_jd_pwd) runs'
else
  _jd_t_bad 'bash theme: promptvars is set, so $(_jd_pwd) runs' 'set' 'unset'
fi

# ---------------------------------------------- it replaces the prompt

_jd_tb_first=$PS1

_jd_tb_forget
PS1='\w \$ '
_jd_tb_source
_jd_t_eq 'bash theme: a prompt of your own is replaced' "$_jd_tb_first" "$PS1"
_jd_t_eq 'bash theme: replacing it prints nothing' '' "$JD_T_ERR"

_jd_tb_source
_jd_t_eq 'bash theme: sourcing it again prints nothing' '' "$JD_T_ERR"
_jd_t_eq 'bash theme: sourcing it again does not change the prompt' "$_jd_tb_first" "$PS1"

# ------------------------------------------------------ PROMPT_COMMAND

_jd_tb_forget
_jd_tb_source
_jd_t_eq 'bash theme: with no PROMPT_COMMAND it stores $? and nothing else' \
  '_jd_theme_rc=$?' "$PROMPT_COMMAND"

_jd_tb_forget
PROMPT_COMMAND='update_terminal_cwd'
_jd_tb_source
_jd_t_eq 'bash theme: it stores $? before your PROMPT_COMMAND runs' \
  '_jd_theme_rc=$?; update_terminal_cwd' "$PROMPT_COMMAND"

_jd_tb_source
_jd_t_eq 'bash theme: sourcing it again does not add it twice' \
  '_jd_theme_rc=$?; update_terminal_cwd' "$PROMPT_COMMAND"

# -------------------------------------------------------- exit status

_jd_theme_rc=0
_jd_t_eq 'bash theme: a status of 0 prints nothing' '' "$(_jd_theme_status)"
_jd_theme_rc=127
_jd_t_eq 'bash theme: a failed status prints in red' \
  $'\001\033[31m\002127\001\033[39m\002 · ' "$(_jd_theme_status)"

# ------------------------------------------------------------- colours

_jd_t_eq 'bash theme: a colour name' $'\001\033[35m\002' "$(_jd_theme_fg magenta)"
_jd_t_eq 'bash theme: default' $'\001\033[39m\002' "$(_jd_theme_fg default)"
_jd_t_eq 'bash theme: a number from 0 to 7' $'\001\033[33m\002' "$(_jd_theme_fg 3)"
_jd_t_eq 'bash theme: a number from 8 to 255' $'\001\033[38;5;200m\002' "$(_jd_theme_fg 200)"
_jd_t_eq 'bash theme: a number above 255 prints no colour' '' "$(_jd_theme_fg 256)"
_jd_t_eq 'bash theme: an unknown name prints no colour' '' "$(_jd_theme_fg chartreuse)"

_jd_tb_forget
unset JD_CHEVRON1 JD_CHEVRON2
_jd_tb_source
_jd_t_eq 'bash theme: the first chevron has a colour' 'yellow' "$JD_CHEVRON1"
_jd_t_eq 'bash theme: the second chevron has a colour' 'red' "$JD_CHEVRON2"

_jd_tb_forget
JD_CHEVRON1=blue
JD_CHEVRON2=green
_jd_tb_source
_jd_t_eq 'bash theme: your first chevron colour does not change' 'blue' "$JD_CHEVRON1"
_jd_t_eq 'bash theme: your second chevron colour does not change' 'green' "$JD_CHEVRON2"
unset JD_CHEVRON1 JD_CHEVRON2

# ------------------------------------------------------------- gitprompt

_jd_tb_forget
_jd_tb_source
if declare -F gitprompt >/dev/null 2>&1; then
  _jd_t_ok 'bash theme: gitprompt is stubbed when you have none'
else
  _jd_t_bad 'bash theme: gitprompt is stubbed when you have none' \
    'a gitprompt function' 'no gitprompt function'
fi
_jd_t_eq 'bash theme: with no __git_ps1 the stub prints nothing' '' "$(gitprompt)"

# git-prompt.sh can be loaded after the theme. The stub tests for
# __git_ps1 at each prompt, not when it is sourced.
__git_ps1() { printf ' (main)'; }
_jd_t_eq 'bash theme: the stub calls __git_ps1 when it is defined' ' (main)' "$(gitprompt)"

_jd_tb_forget
gitprompt() { printf ' on a branch'; }
_jd_tb_source
_jd_t_eq 'bash theme: your gitprompt is not replaced' ' on a branch' "$(gitprompt)"
_jd_tb_forget

# ------------------------------------------------------- without jd.sh

_jd_tb_forget
unset -f _jd_pwd 2>/dev/null || true
_jd_tb_unloaded=${_JD_CLI_VERSION-}
unset _JD_CLI_VERSION
_jd_tb_source
_jd_t_contains 'bash theme: it prints a message to load jd.sh first' 'source jd.sh' "$JD_T_ERR"
_jd_tb_back=$PWD
cd -- "$JD_FX_ROOT/10-19 Area one" || exit 2
_jd_t_eq 'bash theme: the stub path has no system in it' \
  "$JD_FX_ROOT/10-19 Area one" "$(_jd_pwd)"
cd -- "$_jd_tb_back" || exit 2
[ -z "$_jd_tb_unloaded" ] || _JD_CLI_VERSION=$_jd_tb_unloaded

# ------------------------------------------------- in an interactive bash

# bash 3.2 has no ${PS1@P}, so expand the prompt the way a person sees
# it: an interactive bash prints its prompt on stderr. The rc file sets a
# PROMPT_COMMAND that resets $?, as macOS Terminal does, before the
# theme is sourced.
_jd_tb_rc=$JD_T_TMP/bashrc
{
  printf 'PROMPT_COMMAND=true\n'
  printf 'export JD_CONFIG=%q\n' "$JD_T_TMP/two.json"
  printf '. %q\n' "$JD_T_REPO/jd.sh"
  printf '. %q\n' "$JD_T_REPO/lib/theme.bash"
} >"$_jd_tb_rc"
_jd_tb_id="$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"
printf 'cd %q\nfalse\n' "$_jd_tb_id" |
  TERM=dumb BASH_SILENCE_DEPRECATION_WARNING=1 \
    "$BASH" --rcfile "$_jd_tb_rc" -i >/dev/null 2>"$JD_T_TMP/.prompt"
_jd_tb_shown=$(cat "$JD_T_TMP/.prompt")
_jd_t_contains 'bash theme: the expanded prompt shows the ID' \
  'D25:…/11.11 First ID' "$_jd_tb_shown"
_jd_t_contains 'bash theme: the expanded prompt shows a failed status' \
  $'\033[31m1\033[39m · ' "$_jd_tb_shown"
_jd_t_lacks 'bash theme: readline receives no \001 or \002 as text' \
  $'\001' "$_jd_tb_shown"

_jd_t_summary
