# SPDX-License-Identifier: MIT
# setup.sh - 'jd agent-setup', a prompt for your agent
# Part of the Johnny.Decimal command line. Sourced by bin/jd, which sets
# $_JD_CLI_DIR, and after lib/paths.sh and lib/nav.sh, whose helpers it
# uses.
#
# The tools require a config file, and writing it by hand is a chore.
# 'jd agent-setup' prints a prompt on stdout. Paste it into whatever agent you
# use, and the agent finds your systems and writes the config for you.
# It reads no config, so it is the one command that works before the
# rest do, and the 'no config' error names it.
#
# The prompt is the one source for setup: the systems, the config file,
# the source line in the rc file, the optional zsh prompt, and the
# optional "workPackages" block that 'jd new wp' reads. The install_cli
# tool of the johnnydecimal.com MCP server returns steps for the agent:
# clone this repo, then run 'jd agent-setup'. Nothing else contains
# these steps.
#
# It is the one source for the move out of ~/.jd too. Up to 3.x the
# config, the journal and this repo were all in ~/.jd, the old place.
# When one of them is still there, the prompt starts with a step 0 to
# move it. So an agent that updates an old install runs the same
# command, and nothing else has to contain those steps either.
#
# Only the prompt is written to stdout. The one message to the person,
# that a config exists already, is written to stderr, so that 'jd
# agent-setup | pbcopy' copies the prompt, and nothing else, to the
# clipboard. Nothing is printed after the prompt: the shell hook
# captures stdout and prints it last, so a trailer would be printed
# before the prompt it describes.
#
# Works in bash 3.2+ and zsh.

_jd_setup_usage() {
  cat <<'EOF'
usage: <system> agent-setup

  jd agent-setup            print a prompt for your agent. The agent finds
                            your systems and writes the config file for you
  jd agent-setup | pbcopy   the same, onto the macOS clipboard

The prompt is all that is written to stdout, so it can be piped. It
names this copy of the program and the config file it will read, so run
it from the install you mean to use.

If your config, your journal or this copy of jd is still in ~/.jd, the
prompt starts with a step to move them. 'jd paths' prints where each one
is.
EOF
}

# Step 0 of the prompt, in $_JD_SETUP_MOVE: move what is still in ~/.jd,
# the old place. Empty when nothing is there. $_JD_PATHS_* are set.
#
# It sets a variable and does not print, because $( ) would remove the
# blank line at the end, and the prompt requires that line before step 1.
#
# The text is passed to the unquoted heredoc as a value, and the shell
# does not expand a value again. So a path in the text is safe whatever
# the path contains.
_jd_setup_move() {
  local nl list='' program=''
  nl='
'
  _JD_SETUP_MOVE=''
  case $_JD_PATHS_CONFIG_WAS in
    old)
      list="$list   - The configuration file: move $_JD_PATHS_CONFIG_OLD to $_JD_PATHS_CONFIG_NEW$nl"
      ;;
    both)
      list="$list   - An old configuration file that jd does not read: $_JD_PATHS_CONFIG_OLD. jd reads $_JD_PATHS_CONFIG_NEW. Show me the differences between the two files. Delete the old file only when I say yes.$nl"
      ;;
  esac
  case $_JD_PATHS_JOURNAL_WAS in
    old)
      list="$list   - The journal, which records each jd move: move $_JD_PATHS_JOURNAL_OLD to $_JD_PATHS_JOURNAL_NEW$nl"
      ;;
    both)
      list="$list   - An old journal that jd does not read: $_JD_PATHS_JOURNAL_OLD. jd reads $_JD_PATHS_JOURNAL_NEW. If you delete the old journal, jd undo move cannot undo the moves that are only in the old journal. Delete the old journal only when I say yes.$nl"
      ;;
  esac
  if [ "$_JD_PATHS_INSTALL_WAS" = old ]; then
    list="$list   - The program: move the folder $_JD_PATHS_INSTALL_OLD to $_JD_PATHS_INSTALL_NEW$nl"
    program="$nl   If you moved the program, change $_JD_PATHS_INSTALL_OLD to $_JD_PATHS_INSTALL_NEW in every source line in my rc file. Step 6 lists the rc file for each shell. Show me each line before you change the line. Change only the path. Then stop, and do not continue with this prompt. Run $_JD_PATHS_INSTALL_NEW/bin/jd agent-setup and follow the new prompt, which contains the new paths.$nl"
  fi
  [ -n "$list" ] || return 0
  _JD_SETUP_MOVE="${nl}0. First, move my jd files out of ~/.jd. Before version 4.0.0, jd stored its files in ~/.jd. jd now uses the paths in the XDG Base Directory Specification. jd still reads ~/.jd, but a later version of jd will not. Show me this list. Wait for my yes to each line before you move anything:$nl$nl$list$nl   Use mv. Do not copy, because there must be only one copy of each item. If a folder does not exist, make the folder with mode 700. If an item is a symlink, tell me the target of the symlink before you move the item. If I say no to a line, do not move that item. If I use the Johnny.Decimal agent skills, update the skills before you move the configuration file, or tell me to update them. An older skill reads the configuration file from ~/.jd. When ~/.jd is empty, ask me. Then remove ~/.jd with rmdir.$nl$program"
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
  # The prompt names the place the config belongs, which is where a new
  # one is written. A config that is still in the old place is moved
  # there in step 0.
  _jd_paths_resolve
  cfg=$_JD_PATHS_CONFIG_NEW
  if [ -f "$cfg" ]; then
    state="It exists already. Read it first, and change nothing in it without asking me."
    printf 'jd: you have a config at %s already - the prompt instructs the agent to keep it\n' "$cfg" >&2
  elif [ "$_JD_PATHS_CONFIG_WAS" = old ]; then
    state="My configuration file is still at $_JD_PATHS_CONFIG_OLD, the old place. Step 0 moves the file. Read the file first, and change nothing in it without asking me."
    printf 'jd: you have a config in ~/.jd, the old place - the prompt instructs the agent to move it, and not to change it\n' >&2
  else
    state="It does not exist yet."
  fi
  _jd_setup_move

  # The prompt. It is written in the user's voice, to the agent. The
  # heredoc is unquoted, so that the paths in it are this install's, and
  # so nothing in it may contain a backtick or a dollar sign.
  cat <<EOF
Set up the Johnny.Decimal command line for me.

The program is $_JD_CLI_DIR/bin/jd. It requires a configuration file at $cfg. $state

Read these before you change anything:

- $_JD_CLI_DIR/README.md, the Installation section.
- $_JD_CLI_DIR/config.example.json, the template.
- https://johnnydecimal.com/documentation/configuration, which describes each field.
$_JD_SETUP_MOVE
1. Check that jq is installed. If it is not, tell me which package manager you are about to use, and wait for my yes: brew on macOS, apt on Debian or Ubuntu, dnf on Fedora. Stop until jq is installed.

2. Find my Johnny.Decimal systems. A system is a folder of areas, and every system has an area folder whose name starts with '10-19'. The system's root is the folder that contains the area folders. Its name often starts with a system identifier, like 'D25 My business'. On macOS run: mdfind -name "10-19". Elsewhere run: find ~ -maxdepth 5 -iname "10-19*". Show me what you found, and let me confirm each root before you write anything.

3. If you find no system, stop. This tool navigates a system, so a system has to exist first. If I own a system from johnnydecimal.com that is not on this disk yet, and you have the Johnny.Decimal MCP server, call its install_system tool. That tool returns the steps to install the system and write this file. Otherwise tell me so, and give me the link to https://johnnydecimal.com to read how to build one, or https://johnnydecimal.com/products for a ready-made one.

4. Ask me whether my JDex, the index of my system, is a folder on disk, for example an Obsidian vault. If it is, put its path in that system's "jdex" field. If it is not, leave "jdex" out.

5. Write $cfg. jd calculated this path from my environment: JD_CONFIG if it is set, then XDG_CONFIG_HOME, then the default. Use this path, and do not calculate the path yourself. To see the path again, run $_JD_CLI_DIR/bin/jd paths. If the folder for this file is missing, make the folder with mode 700. Use "version": 1 and one entry in "systems" per system. Each entry requires "title" and "root". "sys" is the system identifier, like D25. If I have one system and it has no identifier, leave "sys" out. If I have more than one system, every entry requires a "sys", and mark one "default": true. Leave out "beta". Leave out "workPackages" too, because you add it in step 9. If the file exists, add to its "systems" list and leave the other entries alone. Never overwrite it.

6. Add this line to the rc file for my shell:

   source $_JD_CLI_DIR/jd.sh

   zsh: .zshrc. bash: .bashrc on Linux, .bash_profile on macOS. fish: config.fish, and there the line is: source $_JD_CLI_DIR/jd.fish
   Show me the line and the file before you write. Never add the line twice. Append it. Never rewrite the file, and never reorder what is in it. If the rc file is a symlink, resolve it and tell me where the real file is. The real file is often in a dotfiles repo, and I commit that change myself.

7. Check your work. Run $_JD_CLI_DIR/bin/jd with no words. It should print the root folder of my default system. Then tell me to open a new shell, and to run 'jd' there.

8. Ask me whether I want the Johnny.Decimal path in my zsh prompt. There are two ways: _jd_pwd in the prompt I have, or Johnny's whole theme in place of it. The README section "The prompt theme" contains the steps. The theme sets PROMPT, whatever PROMPT I had, with no check. So ask first, and say what the theme replaces: my own PROMPT, starship, powerlevel10k, or an oh-my-zsh theme. Do not add either unless I say yes. If I keep my own prompt, tell me that _jd_pwd is available and let me place it.

9. Ask me whether I want jd to create work packages. A work package is one piece of work with a number, like W0001. The command 'jd new wp' creates a note for it in my JDex and a folder for it in my system. If I say no, skip this step. If I say yes, do this for each system that I name:

   - The system requires a "jdex" path in its entry. If the entry has none, tell me, and skip this system.
   - Ask me whether I use Things 3 on this Mac. If I do, the block contains "tasks": { "adapter": "things" }. jd then creates a project in Things for each work package. Tell me to turn on Enable Things URLs in Things, in Settings > General.
   - Ask me whether my JDex is an Obsidian vault. If it is, the block contains "notes": { "adapter": "obsidian" }. The link that jd creates requires the Advanced URI community plugin. Look for the folder .obsidian/plugins/obsidian-advanced-uri in the vault. If the folder is missing, tell me to install the plugin.
   - If I said yes to Things or to Obsidian, add a "workPackages" block to the entry of the system, with the parts above. Show me the block before you write it. If I said no to both, write no block. jd creates work packages without one.
   - Make no folders and no templates. The first 'jd new wp' creates the folders and the templates that are missing, and prints the name of each one.
   - Check your work. Run $_JD_CLI_DIR/bin/jd new wp --dry-run 11.11 A test. With --dry-run, jd creates nothing. It should print the note and the folder that jd would create. Then tell me to run 'jd new wp --help' for more.

Safety rules:

- Read a file before you change it. Never overwrite one.
- Touch only two files: the rc file in step 6 and the configuration file in step 5. If there is a step 0, you can also move the items that step 0 lists.
- If anything is already set up differently from these steps, stop and ask me. A working shell matters more than a tidy install.
EOF
}
