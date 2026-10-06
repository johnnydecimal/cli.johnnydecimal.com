# SPDX-License-Identifier: MIT
# paths.sh - where jd keeps its files, and 'jd paths', which prints them
# Part of the Johnny.Decimal command line. Sourced by bin/jd, which sets
# $_JD_CLI_DIR. It is sourced first, because the other files in lib ask
# this one where the config and the journal are.
#
# jd follows the XDG Base Directory Specification. Each kind of file has
# its own base directory, and jd's folder in each one is 'johnnydecimal':
#
#   the config    $XDG_CONFIG_HOME/johnnydecimal/config.json
#                 The default is ~/.config/johnnydecimal/config.json
#   the journal   $XDG_STATE_HOME/johnnydecimal/journal.jsonl
#                 The default is ~/.local/state/johnnydecimal/journal.jsonl
#   jd itself     $XDG_DATA_HOME/johnnydecimal/cli
#                 The default is ~/.local/share/johnnydecimal/cli
#
# $JD_CONFIG names the config file itself, and wins over all of that.
#
# jd itself is wherever this repo was cloned. bin/jd finds its own
# folder, so the third pair is where the README says to clone it, and
# nothing is read from there.
#
# Up to 3.x all three were in ~/.jd, the old place. For now jd still
# reads a config or a journal there when the new place has none, and
# says so on stderr. A later release takes that out. It is everything
# here with OLD or WAS in its name.
#
# This is the one place that works a path out. The shell hooks ask
# 'jd paths config'. The agent skills and the johnnydecimal.com MCP
# server ask 'jd paths'. None of them holds a copy of the rule.
#
# 'jd paths' needs no config and no jq. 'jd paths --json' needs jq.
# Works in bash 3.2+ and zsh.

# jd's folder in each base directory.
_JD_PATHS_NAME=johnnydecimal

_jd_paths_usage() {
  cat <<'EOF'
usage: <system> paths [config|journal|install] [--json]

  jd paths            print the paths that jd uses, one on each line:
                      the config, the journal, and the folder that
                      contains jd
  jd paths config     print only the path of the config
  jd paths journal    print only the path of the journal
  jd paths install    print only the folder that contains jd
  jd paths --json     print the three paths as one JSON object

jd follows the XDG Base Directory Specification. In each base
directory, jd uses a folder with the name 'johnnydecimal'.

  config    $XDG_CONFIG_HOME/johnnydecimal/config.json
            The default is ~/.config/johnnydecimal/config.json.
            If you set $JD_CONFIG, jd reads only that file
  journal   $XDG_STATE_HOME/johnnydecimal/journal.jsonl
            The default is ~/.local/state/johnnydecimal/journal.jsonl
  install   The folder that contains this copy of jd. The README
            tells you to clone jd to $XDG_DATA_HOME/johnnydecimal/cli.
            The default is ~/.local/share/johnnydecimal/cli

A path in an XDG variable must start with '/'. If the path does not
start with '/', jd uses the default.

Before 4.0.0, jd kept all these files in ~/.jd. If the config or the
journal is still in ~/.jd, jd uses the file there, and 'jd paths'
prints the commands that move the file. A later version of jd will
not read ~/.jd.

'jd paths' does not need a config or jq. Only 'jd paths --json' needs
jq. If a file does not exist, 'jd paths' prints the path where jd
looks for the file.
EOF
}

# ------------------------------------------------------------- the rule

# An XDG base directory, in $_JD_PATHS_BASE. $1 the value of its
# variable, $2 its default, below $HOME.
#
# The spec says the path in the variable must be absolute, and that one
# which is not must be ignored. So a value with no leading '/' gets the
# default, and so does a variable that is empty or not set.
#
# It sets a variable and does not print, so that working the paths out
# costs no subshell. jd asks where the config is several times in a run.
_jd_paths_base() {
  case ${1-} in
    /*) _JD_PATHS_BASE=${1%/} ;;
    *) _JD_PATHS_BASE=${HOME-}/$2 ;;
  esac
}

# The file jd reads, in $_JD_PATHS_PICK, and what is in the old place,
# in $_JD_PATHS_WAS. $1 the new path, $2 the old one.
#
#   ''     nothing is in the old place. jd reads the new one
#   old    there is one in the old place only, so jd reads that
#   both   there is one in each. jd reads the new one, and the old one
#          is left over
#
# A ~/.jd that is a link to the new folder is one file with two names,
# so it is not 'both'.
_jd_paths_pick() {
  _JD_PATHS_PICK=$1
  _JD_PATHS_WAS=''
  [ -f "$2" ] || return 0
  if [ ! -e "$1" ]; then
    _JD_PATHS_PICK=$2
    _JD_PATHS_WAS=old
  elif [ ! "$1" -ef "$2" ]; then
    _JD_PATHS_WAS=both
  fi
}

# Work out every path, into the variables below. It runs each time a
# path is asked for, and nothing is kept from the last time: a variable
# that changed, or a file that moved, is seen at once.
#
#   _JD_PATHS_CONFIG        the config jd reads
#   _JD_PATHS_CONFIG_NEW    where the config belongs
#   _JD_PATHS_CONFIG_OLD    where it was up to 3.x
#   _JD_PATHS_CONFIG_WAS    '', old or both. See _jd_paths_pick
#
# The same four for JOURNAL, and for INSTALL. The install is never
# picked: it is the folder this copy of jd is in. Its WAS is 'old' when
# that folder is the old place.
_jd_paths_resolve() {
  local old=${HOME-}/.jd

  _jd_paths_base "${XDG_CONFIG_HOME-}" .config
  _JD_PATHS_CONFIG_NEW=$_JD_PATHS_BASE/$_JD_PATHS_NAME/config.json
  _JD_PATHS_CONFIG_OLD=$old/config.json
  if [ -n "${JD_CONFIG-}" ]; then
    # The user has named the file. The old place is not looked at.
    _JD_PATHS_CONFIG_NEW=$JD_CONFIG
    _JD_PATHS_CONFIG=$JD_CONFIG
    _JD_PATHS_CONFIG_WAS=''
  else
    _jd_paths_pick "$_JD_PATHS_CONFIG_NEW" "$_JD_PATHS_CONFIG_OLD"
    _JD_PATHS_CONFIG=$_JD_PATHS_PICK
    _JD_PATHS_CONFIG_WAS=$_JD_PATHS_WAS
  fi

  _jd_paths_base "${XDG_STATE_HOME-}" .local/state
  _JD_PATHS_JOURNAL_NEW=$_JD_PATHS_BASE/$_JD_PATHS_NAME/journal.jsonl
  _JD_PATHS_JOURNAL_OLD=$old/journal.jsonl
  _jd_paths_pick "$_JD_PATHS_JOURNAL_NEW" "$_JD_PATHS_JOURNAL_OLD"
  _JD_PATHS_JOURNAL=$_JD_PATHS_PICK
  _JD_PATHS_JOURNAL_WAS=$_JD_PATHS_WAS

  _jd_paths_base "${XDG_DATA_HOME-}" .local/share
  _JD_PATHS_INSTALL_NEW=$_JD_PATHS_BASE/$_JD_PATHS_NAME/cli
  _JD_PATHS_INSTALL_OLD=$old/cli
  _JD_PATHS_INSTALL=${_JD_CLI_DIR-}
  _JD_PATHS_INSTALL_WAS=''
  if [ "$_JD_PATHS_INSTALL" = "$_JD_PATHS_INSTALL_OLD" ]; then
    _JD_PATHS_INSTALL_WAS=old
  fi
}

# The config jd reads, and the journal it reads and writes. One line of
# stdout with no newline, for the files in lib to read with $( ).
_jd_paths_config() {
  _jd_paths_resolve
  printf '%s' "$_JD_PATHS_CONFIG"
}

_jd_paths_journal() {
  _jd_paths_resolve
  printf '%s' "$_JD_PATHS_JOURNAL"
}

# -------------------------------------------------------- the old place

# Say that a file is still in the old place, in one line on stderr.
# $1 'config' or 'journal'. It says nothing when the old place holds
# none.
#
# nav.sh calls it once in a command that reads the config, and move.sh
# once in a command that uses the journal. The line is short because it
# comes with every such command until the file is moved. 'jd paths' has
# the commands that move it.
_jd_paths_note() {
  local was=''
  _jd_paths_resolve
  case $1 in
    config) was=$_JD_PATHS_CONFIG_WAS ;;
    journal) was=$_JD_PATHS_JOURNAL_WAS ;;
  esac
  case $was in
    old)
      printf "jd: the %s is in ~/.jd, the old place - 'jd paths' says how to move it\n" \
        "$1" >&2
      ;;
    both)
      printf "jd: there is a %s in ~/.jd, the old place, that jd does not read - 'jd paths' says more\n" \
        "$1" >&2
      ;;
  esac
  return 0
}

# A path as a person types it into a shell. Below $HOME, and with
# nothing in it that a shell minds, it is ~/the/rest, which is short
# enough not to wrap. Anything else is the whole path in single quotes.
_jd_paths_sh() {
  local p=$1 rest
  if [ -n "${HOME-}" ]; then
    case $p in
      "$HOME"/*)
        rest=${p#"$HOME"/}
        case $rest in
          *[!A-Za-z0-9._/-]*) ;;
          *)
            printf '~/%s' "$rest"
            return 0
            ;;
        esac
        ;;
    esac
  fi
  case $p in
    *[!A-Za-z0-9._/-]*) printf "'%s'" "$(printf '%s' "$p" | sed "s/'/'\\\\''/g")" ;;
    *) printf '%s' "$p" ;;
  esac
}

# The commands that move one thing out of the old place. $1 what it is,
# $2 where it is, $3 the folder it goes into. It keeps its name.
#
# The folder is made with mode 700, which is what the spec asks of a
# program that makes one.
_jd_paths_howto() {
  local to
  to=$(_jd_paths_sh "$3")
  printf 'jd: %s is in ~/.jd, the old place. To move it:\n' "$1"
  printf '    mkdir -p -m 700 %s\n' "$to"
  printf '    mv %s %s/\n' "$(_jd_paths_sh "$2")" "$to"
}

# Everything 'jd paths' has to say about the old place, on stderr.
# Nothing when the old place holds nothing. $_JD_PATHS_* are set.
_jd_paths_report() {
  local said=0
  {
    case $_JD_PATHS_CONFIG_WAS in
      old)
        _jd_paths_howto 'the config' "$_JD_PATHS_CONFIG_OLD" \
          "$(dirname -- "$_JD_PATHS_CONFIG_NEW")"
        said=1
        ;;
      both)
        printf 'jd: there is a config in ~/.jd, the old place, that jd does not read.\n'
        printf '    jd reads %s\n' "$_JD_PATHS_CONFIG_NEW"
        printf '    If you do not need the old file, delete it: rm %s\n' \
          "$(_jd_paths_sh "$_JD_PATHS_CONFIG_OLD")"
        said=1
        ;;
    esac
    case $_JD_PATHS_JOURNAL_WAS in
      old)
        _jd_paths_howto 'the journal' "$_JD_PATHS_JOURNAL_OLD" \
          "$(dirname -- "$_JD_PATHS_JOURNAL_NEW")"
        said=1
        ;;
      both)
        printf 'jd: there is a journal in ~/.jd, the old place, that jd does not read.\n'
        printf '    jd reads %s\n' "$_JD_PATHS_JOURNAL_NEW"
        printf "    'jd undo move' cannot undo a move that is only in the old journal.\n"
        printf '    If you do not need the old journal, delete it: rm %s\n' \
          "$(_jd_paths_sh "$_JD_PATHS_JOURNAL_OLD")"
        said=1
        ;;
    esac
    if [ "$_JD_PATHS_INSTALL_WAS" = old ]; then
      _jd_paths_howto 'this copy of jd' "$_JD_PATHS_INSTALL_OLD" \
        "$(dirname -- "$_JD_PATHS_INSTALL_NEW")"
      printf '    Then change %s to %s\n' \
        "$(_jd_paths_sh "$_JD_PATHS_INSTALL_OLD")" \
        "$(_jd_paths_sh "$_JD_PATHS_INSTALL_NEW")"
      printf '    in your shell config, and start a new shell.\n'
      said=1
    fi
    if [ "$said" -eq 1 ]; then
      printf 'jd: this is temporary. A later version of jd will not read ~/.jd.\n'
      printf '    When ~/.jd is empty, delete it: rmdir %s\n' \
        "$(_jd_paths_sh "${HOME-}/.jd")"
      printf "    Your agent can move these for you: 'jd agent-setup' prints a prompt for your agent.\n"
    fi
  } >&2
}

# ---------------------------------------------------------------- --json

# The object 'jd paths --json' prints. $_JD_PATHS_* are set.
#
#   config    the config jd reads
#   journal   the journal jd reads and writes
#   install   the folder this copy of jd is in
#   warnings  codes for what is still in the old place: old_config,
#             old_journal and old_install for a thing jd uses there,
#             old_config_ignored and old_journal_ignored for one that is
#             left over. stderr has the commands
_jd_paths_emit_ok() {
  jq -n \
    --arg config "$_JD_PATHS_CONFIG" \
    --arg journal "$_JD_PATHS_JOURNAL" \
    --arg install "$_JD_PATHS_INSTALL" \
    --arg cw "$_JD_PATHS_CONFIG_WAS" \
    --arg jw "$_JD_PATHS_JOURNAL_WAS" \
    --arg iw "$_JD_PATHS_INSTALL_WAS" \
    'def code($was; $what):
       if $was == "old" then ["old_" + $what]
       elif $was == "both" then ["old_" + $what + "_ignored"]
       else [] end;
     {ok: true, config: $config, journal: $journal, install: $install,
      warnings: (code($cw; "config") + code($jw; "journal") + code($iw; "install"))}'
}

# An error. $1 is 1 under --json, $2 the code, $3 the message. The
# message goes to stderr. Under --json the error object goes to stdout
# as well, in the shape 'jd new' and 'jd move' use. Always returns 1.
_jd_paths_fail() {
  if [ "$1" -eq 1 ] && command -v jq >/dev/null 2>&1; then
    jq -n --arg code "$2" --arg message "$3" \
      '{ok: false, code: $code, message: $message, path: ""}'
  fi
  _jd_nav_err "$3"
}

# ------------------------------------------------------------ 'jd paths'

# _jd_paths is the entry point nav.sh calls for 'jd paths'. $@ the words
# after 'paths'.
#
# The paths go to stdout, because they are the answer. What there is to
# say about the old place goes to stderr, so that stdout is three lines
# of 'name path' and nothing else, whatever state the machine is in.
#
# 'jd paths config' prints one path and says nothing more, because the
# shell hooks run it every time a shell starts.
_jd_paths() {
  local json=0 name='' w
  # --json and help first, so that a bad word still gets the JSON error
  # it asked for.
  for w in "$@"; do
    case $w in
      -h | --help | help)
        _jd_paths_usage
        return 0
        ;;
      --json) json=1 ;;
    esac
  done
  for w in "$@"; do
    case $w in
      --json) ;;
      -*)
        _jd_paths_fail "$json" unknown_option "unknown option '$w'"
        return 1
        ;;
      config | journal | install)
        if [ -n "$name" ]; then
          _jd_paths_fail "$json" unexpected_word "unexpected word '$w'"
          return 1
        fi
        name=$w
        ;;
      *)
        _jd_paths_fail "$json" unknown_path \
          "'$w' is not a path jd has - see 'jd paths --help'"
        return 1
        ;;
    esac
  done
  if [ -n "$name" ] && [ "$json" -eq 1 ]; then
    _jd_paths_fail "$json" unexpected_word \
      "'jd paths $name' prints one path, so it takes no --json"
    return 1
  fi

  _jd_paths_resolve
  case $name in
    config) printf '%s\n' "$_JD_PATHS_CONFIG"; return 0 ;;
    journal) printf '%s\n' "$_JD_PATHS_JOURNAL"; return 0 ;;
    install) printf '%s\n' "$_JD_PATHS_INSTALL"; return 0 ;;
  esac

  if [ "$json" -eq 1 ]; then
    command -v jq >/dev/null 2>&1 || {
      _jd_nav_err "jq is not installed"
      return 1
    }
    _jd_paths_report
    _jd_paths_emit_ok
    return 0
  fi
  _jd_paths_report
  printf '%-9s%s\n' \
    config "$_JD_PATHS_CONFIG" \
    journal "$_JD_PATHS_JOURNAL" \
    install "$_JD_PATHS_INSTALL"
}
