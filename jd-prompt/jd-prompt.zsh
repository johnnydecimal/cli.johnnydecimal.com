# SPDX-License-Identifier: MIT
# Compatibility shim for 1.x. It loads jd.sh and tells you to update.
# It will be deleted at 3.0.0.
#
# 2.0.0 merged jd-nav and jd-prompt into one tool. In .zshrc or .bashrc,
# replace both of your source lines with one:
#
#   source ~/.jd/cli/jd.sh

# The folder this file is in, however it was sourced. The zsh form is
# hidden behind eval so that bash never has to parse it.
if [ -n "${ZSH_VERSION-}" ]; then
  eval '_jd_shim_self=${(%):-%x}'
else
  _jd_shim_self=${BASH_SOURCE[0]}
fi
_jd_shim_dir=$(cd -- "$(dirname -- "$_jd_shim_self")" && cd .. && pwd)

. "$_jd_shim_dir/jd.sh"

# Both shims load jd.sh, so say this once per shell, not twice.
if [ -z "${_JD_CLI_SHIM_SAID-}" ]; then
  _JD_CLI_SHIM_SAID=1
  printf 'jd: you are sourcing a 1.x path. Replace your jd-nav and jd-prompt\n' >&2
  printf '    source lines with one: source %s/jd.sh\n' "$_jd_shim_dir" >&2
fi

unset _jd_shim_self _jd_shim_dir
