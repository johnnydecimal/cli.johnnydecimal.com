# SPDX-License-Identifier: MIT
# theme.sh - the whole-prompt theme, lib/theme.zsh
#
# The theme is zsh only, and jd.sh does not load it. The user sources it.
# So these tests source it by hand, the way a .zshrc does, and look at
# PROMPT afterwards.
#
# The rule it must keep: sourcing it sets PROMPT, whatever PROMPT was
# there. 2.1.0 tried to leave a prompt of the user's own alone, and
# could not tell one from a prompt library's default. See the changelog
# for 2.2.0.

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

# ------------------------------------------------------------ the prompt

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_th_forget
_jd_th_source

_jd_t_eq 'theme: it says nothing when it loads' '' "$JD_T_ERR"
_jd_t_eq 'theme: it says nothing on stdout either' '' "$JD_T_OUT"
_jd_t_contains 'theme: the prompt has the JD path in it' '$(_jd_pwd)' "$PROMPT"
_jd_t_contains 'theme: the prompt has the top corner' '┏╸' "$PROMPT"
_jd_t_contains 'theme: the prompt has the bottom corner' '┗╸' "$PROMPT"
_jd_t_contains 'theme: the prompt has both chevrons' '❯%f%F{$JD_CHEVRON2}❯' "$PROMPT"
_jd_t_contains 'theme: the prompt has the git call' '$(gitprompt)' "$PROMPT"

if [[ -o prompt_subst ]]; then
  _jd_t_ok 'theme: prompt_subst is set, so $(_jd_pwd) runs'
else
  _jd_t_bad 'theme: prompt_subst is set, so $(_jd_pwd) runs' 'set' 'unset'
fi

# The prompt is a string until zsh expands it. Expand it here, the way a
# prompt does, and the path must come out of it.
_jd_th_back=$PWD
cd -- "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" || exit 2
_jd_th_shown=${(%%)PROMPT}
cd -- "$_jd_th_back" || exit 2
_jd_t_contains 'theme: the expanded prompt shows the ID' \
  'D25:…/11.11 First ID' "$_jd_th_shown"

# It leaves nothing of its own in the shell.
if typeset -f _jd_theme_is_stock >/dev/null 2>&1; then
  _jd_t_bad 'theme: it leaves no helper behind' \
    'no _jd_theme_is_stock' '_jd_theme_is_stock is defined'
else
  _jd_t_ok 'theme: it leaves no helper behind'
fi
_jd_t_eq 'theme: it leaves no marker variable behind' '' "${_JD_THEME_PROMPT-}"

# ------------------------------------------------- it takes the prompt

# Any prompt is replaced, and nothing is said about it. The user asked
# for this prompt by sourcing the file.
_jd_th_first=$PROMPT

_jd_th_forget
PROMPT='%~ $ '
_jd_th_source
_jd_t_eq 'theme: a prompt of your own is replaced' "$_jd_th_first" "$PROMPT"
_jd_t_eq 'theme: replacing it says nothing' '' "$JD_T_ERR"

# git-prompt.zsh sets a PROMPT of its own unless it finds gitprompt in
# the one you have. That is what 2.1.0 could not tell from a prompt of
# the user's own. It must be replaced like any other.
_jd_th_forget
PROMPT='%B%40<..<%~ %b$(gitprompt)'
_jd_th_source
_jd_t_eq 'theme: a prompt library default is replaced' \
  "$_jd_th_first" "$PROMPT"

# Sourcing it twice is quiet, and lands in the same place.
_jd_th_source
_jd_t_eq 'theme: sourcing it again says nothing' '' "$JD_T_ERR"
_jd_t_eq 'theme: sourcing it again keeps the prompt' "$_jd_th_first" "$PROMPT"

# ------------------------------------------------------------- gitprompt

_jd_th_forget
_jd_th_source
if typeset -f gitprompt >/dev/null 2>&1; then
  _jd_t_ok 'theme: gitprompt is stubbed when you have none'
else
  _jd_t_bad 'theme: gitprompt is stubbed when you have none' \
    'a gitprompt function' 'no gitprompt function'
fi
_jd_t_eq 'theme: the stub prints nothing' '' "$(gitprompt)"

_jd_th_forget
gitprompt() { print -n ' on a branch'; }
_jd_th_source
_jd_t_eq 'theme: your gitprompt is not replaced' ' on a branch' "$(gitprompt)"

# ------------------------------------------------- chevrons of your own

_jd_th_forget
_jd_th_source
_jd_t_eq 'theme: the first chevron has a colour' 'yellow' "$JD_CHEVRON1"
_jd_t_eq 'theme: the second chevron has a colour' 'red' "$JD_CHEVRON2"

_jd_th_forget
JD_CHEVRON1=blue
JD_CHEVRON2=green
_jd_th_source
_jd_t_eq 'theme: your first chevron colour is kept' 'blue' "$JD_CHEVRON1"
_jd_t_eq 'theme: your second chevron colour is kept' 'green' "$JD_CHEVRON2"

# They are read at every prompt, so setting them after the source line
# works too.
JD_CHEVRON1=magenta
_jd_th_shown=${(%%)PROMPT}
_jd_t_contains 'theme: a colour set after the source line still counts' \
  $'\033[35m' "$_jd_th_shown"
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
