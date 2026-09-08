# SPDX-License-Identifier: MIT
# theme.sh - the whole-prompt theme, lib/theme.zsh
#
# The theme is zsh only, and jd.sh does not load it. The user sources it.
# So these tests source it by hand, the way a .zshrc does, and look at
# PROMPT afterwards.
#
# The rule it must keep: set PROMPT when the user has none of their own,
# say one line and stop when they do.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# Source the theme and record what it said. It changes this shell on
# purpose, so there is no _jd_t_run here.
_jd_th_source() {
  . "$JD_T_REPO/lib/theme.zsh" >"$JD_T_TMP/.out" 2>"$JD_T_TMP/.err"
  JD_T_STATUS=$?
  JD_T_OUT=$(cat "$JD_T_TMP/.out")
  JD_T_ERR=$(cat "$JD_T_TMP/.err")
}

# Back to a shell that has never seen the theme.
_jd_th_forget() {
  unset _JD_THEME_PROMPT
  unset -f gitprompt 2>/dev/null || true
  PROMPT='%m%# '
}

# --------------------------------------------------------------- in bash

if [ -z "${ZSH_VERSION-}" ]; then
  PROMPT='%m%# '
  _jd_th_source
  _jd_t_contains 'theme: bash is told it is zsh only' 'zsh only' "$JD_T_ERR"
  _jd_t_eq 'theme: bash keeps its PROMPT' '%m%# ' "$PROMPT"
  _jd_t_summary
fi

# ------------------------------------------------------------ no prompt

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_th_forget
_jd_th_source

_jd_t_eq 'theme: it says nothing when it loads' '' "$JD_T_ERR"
_jd_t_contains 'theme: the prompt has the JD path in it' '$(_jd_pwd)' "$PROMPT"
_jd_t_contains 'theme: the prompt has the top corner' '┏╸' "$PROMPT"
_jd_t_contains 'theme: the prompt has the bottom corner' '┗╸' "$PROMPT"
_jd_t_contains 'theme: the prompt has both chevrons' '❯%f%F{$JD_CHEVRON2}❯' "$PROMPT"

if [[ -o prompt_subst ]]; then
  _jd_t_ok 'theme: prompt_subst is set, so $(_jd_pwd) runs'
else
  _jd_t_bad 'theme: prompt_subst is set, so $(_jd_pwd) runs' 'set' 'unset'
fi

_jd_t_eq 'theme: the first chevron has a colour' 'yellow' "$JD_CHEVRON1"
_jd_t_eq 'theme: the second chevron has a colour' 'red' "$JD_CHEVRON2"

if typeset -f gitprompt >/dev/null 2>&1; then
  _jd_t_ok 'theme: gitprompt is stubbed when you have none'
else
  _jd_t_bad 'theme: gitprompt is stubbed when you have none' \
    'a gitprompt function' 'no gitprompt function'
fi
_jd_t_eq 'theme: the stub prints nothing' '' "$(gitprompt)"

# The prompt is a string until zsh expands it. Expand it here, the way a
# prompt does, and the path must come out of it.
_jd_th_back=$PWD
cd -- "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" || exit 2
_jd_th_shown=${(%%)PROMPT}
cd -- "$_jd_th_back" || exit 2
_jd_t_contains 'theme: the expanded prompt shows the ID' \
  'D25:…/11.11 First ID' "$_jd_th_shown"

# The helper does not stay in the user's shell.
if typeset -f _jd_theme_is_stock >/dev/null 2>&1; then
  _jd_t_bad 'theme: it leaves no helper behind' \
    'no _jd_theme_is_stock' '_jd_theme_is_stock is defined'
else
  _jd_t_ok 'theme: it leaves no helper behind'
fi

# ------------------------------------------------------- sourced twice

_jd_th_first=$PROMPT
_jd_th_source
_jd_t_eq 'theme: sourcing it again says nothing' '' "$JD_T_ERR"
_jd_t_eq 'theme: sourcing it again keeps the prompt' "$_jd_th_first" "$PROMPT"

# ------------------------------------------------------ a prompt of yours

_jd_th_forget
PROMPT='%~ $ '
_jd_th_source
_jd_t_eq 'theme: your own prompt is left alone' '%~ $ ' "$PROMPT"
_jd_t_contains 'theme: it says why it did not load' 'your own PROMPT' "$JD_T_ERR"
_jd_t_contains 'theme: it says what to use instead' '$(_jd_pwd)' "$JD_T_ERR"

# Every stock prompt counts as no prompt of your own.
_jd_th_forget
PROMPT='%n@%m %1~ %# '
_jd_th_source
_jd_t_contains 'theme: the macOS default is not a prompt of your own' \
  '┏╸' "$PROMPT"

_jd_th_forget
PROMPT=''
_jd_th_source
_jd_t_contains 'theme: an empty prompt is not a prompt of your own' \
  '┏╸' "$PROMPT"

# ------------------------------------------------- a gitprompt of yours

_jd_th_forget
gitprompt() { print -n ' on a branch'; }
_jd_th_source
_jd_t_eq 'theme: your gitprompt is not replaced' ' on a branch' "$(gitprompt)"

# ------------------------------------------------- chevrons of your own

_jd_th_forget
JD_CHEVRON1=blue
JD_CHEVRON2=green
_jd_th_source
_jd_t_eq 'theme: your first chevron colour is kept' 'blue' "$JD_CHEVRON1"
_jd_t_eq 'theme: your second chevron colour is kept' 'green' "$JD_CHEVRON2"
unset JD_CHEVRON1 JD_CHEVRON2

# ------------------------------------------------------- without jd.sh

# A shell that has the theme but not jd.sh gets the ordinary path, and is
# told to load jd.sh. _jd_pwd is what tells them apart.
_jd_th_forget
unset -f _jd_pwd 2>/dev/null || true
_jd_th_unloaded=$_JD_CLI_VERSION
unset _JD_CLI_VERSION
_jd_th_source
_jd_t_contains 'theme: it says to load jd.sh first' 'source jd.sh' "$JD_T_ERR"
_jd_th_back=$PWD
cd -- "$JD_FX_ROOT/10-19 Area one" || exit 2
_jd_t_eq 'theme: the stub path has no system in it' \
  "$JD_FX_ROOT/10-19 Area one" "$(_jd_pwd)"
cd -- "$_jd_th_back" || exit 2
_JD_CLI_VERSION=$_jd_th_unloaded

_jd_t_summary
