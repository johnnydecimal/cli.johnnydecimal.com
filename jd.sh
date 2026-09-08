# SPDX-License-Identifier: MIT
# jd.sh - the Johnny.Decimal command line
# Version 2.0.1.
#
# Source this file from .zshrc or .bashrc:
#   source ~/.jd/cli/jd.sh
#
# It loads lib/nav.sh in any shell, and lib/prompt.zsh under zsh only.
#
# Needs jq. Works in bash 3.2+ and zsh.

# The version of this repo, shared by every tool in it. Semver.
_JD_CLI_VERSION="2.0.1"
_JD_CLI_HELP_URL="https://jdcm.al/jdhq/jd-cli"

# The folder this file is in, however it was sourced. The zsh form is
# hidden behind eval so that bash never has to parse it.
if [ -n "${ZSH_VERSION-}" ]; then
  eval '_jd_cli_self=${(%):-%x}'
else
  _jd_cli_self=${BASH_SOURCE[0]}
fi
_jd_cli_dir=$(cd -- "$(dirname -- "$_jd_cli_self")" && pwd)

. "$_jd_cli_dir/lib/nav.sh"
if [ -n "${ZSH_VERSION-}" ]; then
  . "$_jd_cli_dir/lib/prompt.zsh"
fi

unset _jd_cli_self _jd_cli_dir
