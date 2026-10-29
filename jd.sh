# SPDX-License-Identifier: MIT
# jd.sh - the shell hook for the Johnny.Decimal command line
#
# Source this file from .zshrc or .bashrc:
#   source ~/.local/share/johnnydecimal/cli/jd.sh
#
# The tool itself is bin/jd, a program. Anything can run it: a script,
# cron, an agent, another program. This file does only the two things a
# separate process cannot do for you: change the directory of the shell
# you are typing in, and draw the zsh prompt.
#
# It defines jd, jdex, and one command per system in your config, named
# by its lowercase sys id: d25, p76. Each one runs bin/jd and changes to
# the folder that the program prints. This file also adds bin to $PATH,
# so that a script started from this shell finds jd too.
#
# It loads nothing else from lib, except lib/prompt.zsh under zsh. It
# does not resolve where the config is: it runs 'jd paths config'.
#
# Requires jq. Works in bash 3.2+ and zsh.

# The folder this file is in, however it was sourced. The zsh form is
# hidden behind eval so that bash never has to parse it.
if [ -n "${ZSH_VERSION-}" ]; then
  eval '_jd_hook_self=${(%):-%x}'
else
  _jd_hook_self=${BASH_SOURCE[0]}
fi
_jd_hook_dir=$(cd -- "$(dirname -- "$_jd_hook_self")" && pwd)
_jd_hook_bin=$_jd_hook_dir/bin/jd

# bin on $PATH, so that a subprocess of this shell can run jd by name.
# Inside the shell the functions below take precedence, as functions do.
case ":${PATH-}:" in
  *":$_jd_hook_dir/bin:"*) ;;
  *)
    PATH="$_jd_hook_dir/bin${PATH:+:$PATH}"
    export PATH
    ;;
esac

# Define one command. $1 the name, $2 words the program always receives
# before the user's own, already quoted for the shell.
#
# The body is self-contained on purpose. It names the program by its
# path, contains the cd inline, and calls no other shell function. An
# agent that copies its user's shell functions copies jd and omits every
# name that starts with an underscore, so a jd that called a helper
# would fail in the copy. This one does not.
#
# Status 3 from the program means a move, and its stdout is the folder
# to cd to. Any other status is the program's own, and its stdout, if
# there is any, is the answer. stderr is never captured, so match lists
# and errors stream while the command runs.
_jd_hook_def() {
  eval "$1() {
  local jd_out jd_status
  jd_out=\$(JD_HOOK=1 '$_jd_hook_bin' $2 \"\$@\")
  jd_status=\$?
  if [ \"\$jd_status\" -eq 3 ]; then
    cd -- \"\$jd_out\" && pwd
    return
  fi
  [ -n \"\$jd_out\" ] && printf '%s\\n' \"\$jd_out\"
  return \"\$jd_status\"
}"
}

# One command per system, read from the config now, because a shell
# cannot be given a new function name later. More than one system means
# every entry requires a sys, so a missing one is an error, not a skip.
#
# With no config, no jq, or no systems there is nothing to name, and
# nothing is printed: jd and jdex are still defined, and the program
# prints the error when you call one.
#
# The program determines where the config is: $JD_CONFIG, then the XDG
# place, then ~/.jd for now. 'jd paths config' prints the one it reads
# and nothing else, so this file contains no copy of that rule. It
# costs one more process at shell start.
_jd_hook_cfg=$("$_jd_hook_bin" paths config 2>/dev/null)
_jd_hook_n=0
if [ -f "$_jd_hook_cfg" ] && command -v jq >/dev/null 2>&1; then
  _jd_hook_n=$(jq -r '.systems | length' "$_jd_hook_cfg" 2>/dev/null)
  case $_jd_hook_n in
    '' | *[!0-9]*) _jd_hook_n=0 ;;
  esac
fi

if [ "$_jd_hook_n" -gt 1 ]; then
  while IFS= read -r _jd_hook_sys; do
    if [ -z "$_jd_hook_sys" ] || [ "$_jd_hook_sys" = null ]; then
      printf 'jd: a system in %s has no %s - every entry requires one when there is more than one system\n' \
        "$_jd_hook_cfg" "'sys'" >&2
      continue
    fi
    _jd_hook_fn=$(printf '%s' "$_jd_hook_sys" | tr 'A-Z' 'a-z')
    case $_jd_hook_fn in
      *[!a-z0-9_]* | [0-9]*)
        printf "jd: cannot define a function for sys id '%s'\n" "$_jd_hook_sys" >&2
        continue
        ;;
    esac
    _jd_hook_def "$_jd_hook_fn" "--system '$_jd_hook_sys'"
  done <<EOF
$(jq -r '.systems[].sys' "$_jd_hook_cfg")
EOF
fi

# jd is the default system, or the only one. jdex is the same system, in
# its JDex. Neither names a system: the program resolves the default
# each time it runs, so a config you edit takes effect at once.
#
# Both are defined after the loop above, so a system whose sys id is
# 'jd' or 'jdex' does not replace the root command.
_jd_hook_def jd ''
_jd_hook_def jdex jdex

# The prompt redraws on every command, so it stays a shell function. It
# reads $_jd_hook_cfg as it loads, which is why the unset comes after.
if [ -n "${ZSH_VERSION-}" ]; then
  . "$_jd_hook_dir/lib/prompt.zsh"
fi

unset _jd_hook_self _jd_hook_dir _jd_hook_bin _jd_hook_cfg _jd_hook_n \
  _jd_hook_sys _jd_hook_fn
unset -f _jd_hook_def
