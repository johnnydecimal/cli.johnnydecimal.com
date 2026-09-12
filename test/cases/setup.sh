# SPDX-License-Identifier: MIT
# setup.sh - 'jd setup', the prompt for your agent
#
# It is the one command, apart from version and help, that works with no
# config. What is tested is that it works then, that the prompt names
# this install and this config, that only the prompt goes to stdout, and
# that every 'no config' error names it.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

unset JD_BETA

# --------------------------------------------------------------- no config
#
# Before any fixture config exists, so 'no config' is the truth. The
# hook is loaded so that jd, the function, is what runs.

_jd_t_none="$JD_T_TMP/nothing-here.json"
_jd_t_load "$_jd_t_none"

_jd_t_run jd setup
_jd_t_status 'no config: jd setup exit status' 0
_jd_t_contains 'no config: the prompt names the config file' \
  "$_jd_t_none" "$JD_T_OUT"
_jd_t_contains 'no config: the prompt says the file does not exist' \
  'It does not exist yet.' "$JD_T_OUT"
_jd_t_contains 'no config: the prompt names this copy of the program' \
  "$JD_T_REPO/bin/jd" "$JD_T_OUT"
_jd_t_contains 'no config: the prompt names the hook to source' \
  "source $JD_T_REPO/jd.sh" "$JD_T_OUT"
_jd_t_contains 'no config: the prompt names the template' \
  "$JD_T_REPO/config.example.json" "$JD_T_OUT"
_jd_t_contains 'no config: the prompt names the configuration page' \
  'https://johnnydecimal.com/jdhq/configuration' "$JD_T_OUT"
_jd_t_contains 'no config: the prompt names the MCP install tool' \
  'install_cli' "$JD_T_OUT"
_jd_t_contains 'no config: the prompt says what to do with no system' \
  'If you find no system, stop.' "$JD_T_OUT"
_jd_t_lacks 'no config: the prompt is not an error' 'no config' "$JD_T_ERR"
_jd_t_lacks 'no config: nothing for the person is on stdout' 'jd:' "$JD_T_OUT"
_jd_t_contains 'no config: the person is told where the prompt goes' \
  'paste it into your agent' "$JD_T_ERR"
_jd_t_at 'no config: does not move us' "$JD_T_TMP"

# The unquoted heredoc means a backtick or a dollar in the prompt would
# be run by the shell, not printed. None must ever get in.
_jd_t_lacks 'the prompt text has no backtick' '`' \
  "$(sed -n '/<<EOF$/,/^EOF$/p' "$JD_T_REPO/lib/setup.sh")"
_jd_t_lacks 'the prompt text has no dollar but its own variables' \
  '$' \
  "$(sed -n '/<<EOF$/,/^EOF$/p' "$JD_T_REPO/lib/setup.sh" |
    sed 's/\$_JD_CLI_DIR//g; s/\$cfg//g; s/\$state//g')"

_jd_t_run jd jdex setup
_jd_t_status 'no config: jd jdex setup works too' 0

_jd_t_run "$JD_T_BIN" setup
_jd_t_status 'no config: the program prints it without the hook' 0
_jd_t_contains 'no config: the program names the config file' \
  "$_jd_t_none" "$JD_T_OUT"

_jd_t_run jd setup --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' 'usage: <system> setup' "$JD_T_OUT"
_jd_t_contains 'help: names pbcopy' 'pbcopy' "$JD_T_OUT"

_jd_t_run jd setup now
_jd_t_status 'extra word: is an error' 1
_jd_t_contains 'extra word: says setup takes nothing' \
  "'jd setup' takes nothing after it" "$JD_T_ERR"
_jd_t_eq 'extra word: nothing on stdout' '' "$JD_T_OUT"

_jd_t_run jd help
_jd_t_contains 'jd help: names setup' '<system> setup' "$JD_T_OUT"

# Every command that needs the config says the same thing, and names
# the way out.

_jd_t_run jd 11.11
_jd_t_contains 'no config: a move names jd setup' "run 'jd setup'" "$JD_T_ERR"

_jd_t_run jd beta
_jd_t_contains 'no config: jd beta names jd setup' "run 'jd setup'" "$JD_T_ERR"

_jd_t_run jd new id 21 A title
_jd_t_status 'no config: jd new is an error' 1
_jd_t_contains 'no config: jd new names jd setup' "run 'jd setup'" "$JD_T_ERR"

# ------------------------------------------------------- a config exists

_jd_fx_build
_jd_fx_config_two "$JD_T_TMP/two.json"
_jd_t_load "$JD_T_TMP/two.json"

_jd_t_run jd setup
_jd_t_status 'config exists: jd setup still works' 0
_jd_t_contains 'config exists: the prompt names the config file' \
  "$JD_T_TMP/two.json" "$JD_T_OUT"
_jd_t_contains 'config exists: the prompt says to keep it' \
  'It exists already.' "$JD_T_OUT"
_jd_t_lacks 'config exists: the prompt does not say it is missing' \
  'does not exist' "$JD_T_OUT"
_jd_t_contains 'config exists: the person is told it exists' \
  'you have a config at' "$JD_T_ERR"

_jd_t_run d25 setup
_jd_t_status 'config exists: a per-system command prints it too' 0
_jd_t_contains 'config exists: a per-system command names the config' \
  "$JD_T_TMP/two.json" "$JD_T_OUT"

_jd_t_summary
