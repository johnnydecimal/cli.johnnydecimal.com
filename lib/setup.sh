# SPDX-License-Identifier: MIT
# setup.sh - 'jd setup', a prompt for your agent
# Part of the Johnny.Decimal command line. Sourced by bin/jd, which sets
# $_JD_CLI_DIR, and after lib/nav.sh, whose helpers it uses.
#
# The tools need ~/.jd/config.json, and writing it by hand is a chore.
# 'jd setup' prints a prompt on stdout. Paste it into whatever agent you
# use, and the agent finds your systems and writes the config for you.
# It reads no config, so it is the one command that works before the
# rest do, and the 'no config' error names it.
#
# Only the prompt goes to stdout. The one thing said to the person, that
# a config exists already, goes to stderr, so that 'jd setup | pbcopy'
# puts the prompt, and nothing else, on the clipboard. Nothing is said
# after the prompt: the shell hook captures stdout and prints it last,
# so a trailer would come out before the prompt it describes.
#
# Works in bash 3.2+ and zsh.

_jd_setup_usage() {
  cat <<'EOF'
usage: <system> setup

  jd setup            print a prompt for your agent. The agent finds
                      your systems and writes the config file for you
  jd setup | pbcopy   the same, onto the macOS clipboard

The prompt is all that goes to stdout, so it can be piped. It names
this copy of the program and the config file it will read, so run it
from the install you mean to use.
EOF
}

_jd_setup() {
  local cfg state
  case ${1-} in
    -h|--help|help) _jd_setup_usage; return 0 ;;
  esac
  [ $# -eq 0 ] || {
    _jd_nav_err "'jd setup' takes nothing after it - see 'jd setup --help'"
    return 1
  }
  cfg=$(_jd_nav_config)
  if [ -f "$cfg" ]; then
    state="It exists already. Read it first, and change nothing in it without asking me."
    printf 'jd: you have a config at %s already - the prompt tells the agent to keep it\n' "$cfg" >&2
  else
    state="It does not exist yet."
  fi

  # The prompt. It is written in the user's voice, to the agent. The
  # heredoc is unquoted, so that the paths in it are this install's, and
  # so nothing in it may hold a backtick or a dollar sign.
  cat <<EOF
Set up the Johnny.Decimal command line for me.

The program is $_JD_CLI_DIR/bin/jd. It needs a configuration file at $cfg. $state

Read these before you change anything:

- $_JD_CLI_DIR/README.md, the Installation section.
- $_JD_CLI_DIR/config.example.json, the template.
- https://johnnydecimal.com/jdhq/configuration, which says what each field means.

If you have the Johnny.Decimal MCP server, call its install_cli tool. It walks you through the same steps. Otherwise:

1. Check that jq is installed. If it is not, tell me how to install it, and stop until it is.

2. Find my Johnny.Decimal systems. A system is a folder of areas, and every system has an area folder whose name starts with '10-19'. The system's root is the folder that holds the area folders. Its name often starts with a system identifier, like 'D25 My business'. On macOS run: mdfind -name "10-19". Elsewhere run: find ~ -maxdepth 5 -iname "10-19*". Show me what you found, and let me confirm each root before you write anything.

3. If you find no system, stop. This tool moves around a system, so one has to exist first. Tell me so, and point me at https://johnnydecimal.com to read how to build one, or https://johnnydecimal.com/products for a ready-made one.

4. Ask me whether my JDex, the index of my system, is a folder on disk, for example an Obsidian vault. If it is, put its path in that system's "jdex" field. If it is not, leave "jdex" out.

5. Write $cfg. Use "version": 1 and one entry in "systems" per system. Each entry needs "title" and "root". "sys" is the system identifier, like D25. If I have one system and it has no identifier, leave "sys" out. If I have more than one system, every entry needs a "sys", and mark one "default": true. Leave out "beta" and "workPackages".

6. Add this line to my .zshrc, or to my .bashrc, unless it is already there:

   source $_JD_CLI_DIR/jd.sh

7. Check your work. Run $_JD_CLI_DIR/bin/jd with no words. It should print the root folder of my default system. Then tell me to open a new shell, and to run 'jd' there.

8. Ask me whether I want the Johnny.Decimal zsh prompt. Step 5 of the README says how. Do not add it unless I say yes.
EOF
}
