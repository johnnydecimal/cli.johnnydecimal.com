# SPDX-License-Identifier: MIT
# setup.sh - 'jd agent-setup', a prompt for your agent
# Part of the Johnny.Decimal command line. Sourced by bin/jd, which sets
# $_JD_CLI_DIR, and after lib/nav.sh, whose helpers it uses.
#
# The tools need ~/.jd/config.json, and writing it by hand is a chore.
# 'jd agent-setup' prints a prompt on stdout. Paste it into whatever agent you
# use, and the agent finds your systems and writes the config for you.
# It reads no config, so it is the one command that works before the
# rest do, and the 'no config' error names it.
#
# The prompt is the one home for setup: the systems, the config file,
# the source line in the rc file, and the optional zsh prompt. The
# johnnydecimal.com MCP server's install_cli tool clones this repo and
# then sends the agent here. Nothing else holds these steps.
#
# Only the prompt goes to stdout. The one thing said to the person, that
# a config exists already, goes to stderr, so that 'jd agent-setup | pbcopy'
# puts the prompt, and nothing else, on the clipboard. Nothing is said
# after the prompt: the shell hook captures stdout and prints it last,
# so a trailer would come out before the prompt it describes.
#
# Works in bash 3.2+ and zsh.

_jd_setup_usage() {
  cat <<'EOF'
usage: <system> agent-setup

  jd agent-setup            print a prompt for your agent. The agent finds
                            your systems and writes the config file for you
  jd agent-setup | pbcopy   the same, onto the macOS clipboard

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
    _jd_nav_err "'jd agent-setup' takes nothing after it - see 'jd agent-setup --help'"
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

1. Check that jq is installed. If it is not, tell me which package manager you are about to use, and wait for my yes: brew on macOS, apt on Debian or Ubuntu, dnf on Fedora. Stop until jq is installed.

2. Find my Johnny.Decimal systems. A system is a folder of areas, and every system has an area folder whose name starts with '10-19'. The system's root is the folder that holds the area folders. Its name often starts with a system identifier, like 'D25 My business'. On macOS run: mdfind -name "10-19". Elsewhere run: find ~ -maxdepth 5 -iname "10-19*". Show me what you found, and let me confirm each root before you write anything.

3. If you find no system, stop. This tool moves around a system, so one has to exist first. If I own a system from johnnydecimal.com that is not on this disk yet, and you have the Johnny.Decimal MCP server, call its install_system tool. It builds the system and writes this file. Otherwise tell me so, and point me at https://johnnydecimal.com to read how to build one, or https://johnnydecimal.com/products for a ready-made one.

4. Ask me whether my JDex, the index of my system, is a folder on disk, for example an Obsidian vault. If it is, put its path in that system's "jdex" field. If it is not, leave "jdex" out.

5. Write $cfg. If JD_CONFIG is set in my environment, it names the file instead. Use "version": 1 and one entry in "systems" per system. Each entry needs "title" and "root". "sys" is the system identifier, like D25. If I have one system and it has no identifier, leave "sys" out. If I have more than one system, every entry needs a "sys", and mark one "default": true. Leave out "beta" and "workPackages". If the file exists, add to its "systems" list and leave the other entries alone. Never overwrite it.

6. Add this line to the rc file for my shell:

   source $_JD_CLI_DIR/jd.sh

   zsh: .zshrc. bash: .bashrc on Linux, .bash_profile on macOS. fish: config.fish, and there the line is: source $_JD_CLI_DIR/jd.fish
   Show me the line and the file before you write. Never add the line twice. Append it. Never rewrite the file, and never reorder what is in it. If the rc file is a symlink, resolve it and tell me where the real file lives. It is often a dotfiles repo, and I commit that change myself.

7. Check your work. Run $_JD_CLI_DIR/bin/jd with no words. It should print the root folder of my default system. Then tell me to open a new shell, and to run 'jd' there.

8. Ask me whether I want the Johnny.Decimal path in my zsh prompt. There are two ways: _jd_pwd in the prompt I have, or Johnny's whole theme in place of it. The README section "The prompt theme" says how. The theme sets PROMPT, whatever PROMPT I had, with no check. So ask first, and say what it replaces: my own PROMPT, starship, powerlevel10k, or an oh-my-zsh theme. Do not add either unless I say yes. If I keep my own prompt, tell me that _jd_pwd is available and let me place it.

Safety rules:

- Read a file before you change it. Never overwrite one.
- Touch only two files: the rc file in step 6 and the configuration file in step 5.
- If anything is already set up differently from these steps, stop and ask me. A working shell matters more than a tidy install.
EOF
}
