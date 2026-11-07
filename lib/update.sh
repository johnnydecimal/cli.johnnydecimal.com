# SPDX-License-Identifier: MIT
# update.sh - the update check, and 'jd update', which pulls the latest
# version
# Part of the Johnny.Decimal command line. Sourced by bin/jd, after
# paths.sh and nav.sh.
#
# The check reads the list of tags from GitHub. No telemetry is sent.
#
# bin/jd calls _jd_update_after when a command is done. When stderr is a
# terminal, and the last check was 24 hours ago or more, it starts the
# check as a detached background process, and returns at once. The
# process writes the latest version to the cache file, and a later
# command reads that file. No command waits for the network.
#
# When the cache file names a version greater than this one, jd prints
# one line on stderr after every command. 'jd version' prints the line
# to a terminal or not.
#
# jd never checks, and never prints the line:
#   - when stderr is not a terminal: a script, cron, or an agent's shell
#   - for 'jd paths', which the shell hooks and the prompt run
#   - when JD_NO_UPDATE_CHECK=1, DO_NOT_TRACK=1, or the config contains
#     "updateCheck": false
#
# The cache file is one line, two fields separated by a tab: the time of
# the last check, in seconds since the epoch, and the latest version or
# '-'.
#
# Works in bash 3.2+ and zsh.

_JD_UPDATE_URL=https://github.com/johnnydecimal/cli.johnnydecimal.com.git
_JD_UPDATE_DAY=86400

_jd_update_usage() {
  cat <<'EOF'
usage: <system> update

  jd update           pull the latest version of jd, and print the
                      changelog entries since the version you had

The folder that contains jd must be a git clone on the branch main,
with no uncommitted changes. 'jd paths install' prints the folder.

Once a day, jd checks GitHub for a newer version. If there is one, jd
prints one line after each command. The check reads the list of tags
from GitHub.
No telemetry is sent. To turn the check off, set JD_NO_UPDATE_CHECK=1
or DO_NOT_TRACK=1, or add "updateCheck": false to the config.
EOF
}

# ------------------------------------------------------------- versions

# Return 0 if $1 is a version in the form 1.2.3.
_jd_update_is_version() {
  printf '%s\n' "${1-}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

# Return 0 if version $1 is greater than version $2. Return 1 if it is
# not, or if either one is not a version.
_jd_update_newer() {
  local a1 a2 a3 b1 b2 b3
  _jd_update_is_version "${1-}" && _jd_update_is_version "${2-}" || return 1
  IFS=. read -r a1 a2 a3 <<EOF
$1
EOF
  IFS=. read -r b1 b2 b3 <<EOF
$2
EOF
  [ "$a1" -ne "$b1" ] && { [ "$a1" -gt "$b1" ]; return; }
  [ "$a2" -ne "$b2" ] && { [ "$a2" -gt "$b2" ]; return; }
  [ "$a3" -gt "$b3" ]
}

# The greatest version in the output of 'git ls-remote --tags --refs', on
# stdin. A tag is v1.2.3 or 1.2.3. Any other tag is ignored.
_jd_update_latest_tag() {
  sed -n 's#^[0-9a-f]*[[:space:]]*refs/tags/v\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$#\1#p' |
    sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1
}

# The version that a copy of bin/jd defines. $1 the path of bin/jd.
_jd_update_version_in() {
  sed -n 's/^_JD_CLI_VERSION="\([^"]*\)".*/\1/p' "$1" 2>/dev/null
}

# ---------------------------------------------------------------- cache

_jd_update_now() { date +%s; }

# Return 0 if a time $1 is 24 hours or more before now, $2. A time after
# now means that the clock changed, so it is due too.
_jd_update_due() {
  [ $(($2 - $1)) -ge "$_JD_UPDATE_DAY" ] || [ "$1" -gt "$2" ]
}

# Read the cache file into $_JD_UPDATE_CHECKED and $_JD_UPDATE_LATEST. A
# missing or damaged file reads as no check.
_jd_update_cache_read() {
  local f c='' l=''
  _JD_UPDATE_CHECKED=0
  _JD_UPDATE_LATEST=''
  f=$(_jd_paths_cache)
  [ -f "$f" ] || return 0
  IFS=$'\t' read -r c l <"$f" || true
  case $c in '' | *[!0-9]*) c=0 ;; esac
  _jd_update_is_version "$l" || l=''
  _JD_UPDATE_CHECKED=$c
  _JD_UPDATE_LATEST=$l
}

# Write the cache file from $_JD_UPDATE_CHECKED and $_JD_UPDATE_LATEST.
# A temp file, then a rename, so that a process that
# reads the file never reads half of it.
_jd_update_cache_write() {
  local f dir tmp
  f=$(_jd_paths_cache)
  dir=$(dirname -- "$f")
  [ -d "$dir" ] || mkdir -p -m 700 "$dir" 2>/dev/null || return 1
  tmp=$(mktemp "$dir/.update-check.XXXXXX" 2>/dev/null) || return 1
  if printf '%s\t%s\n' "$_JD_UPDATE_CHECKED" "${_JD_UPDATE_LATEST:--}" >"$tmp"; then
    mv -f "$tmp" "$f"
  else
    rm -f "$tmp"
    return 1
  fi
}

# ---------------------------------------------------------------- check

_jd_update_tty() { [ -t 2 ]; }

# Return 0 if the check is off: JD_NO_UPDATE_CHECK, DO_NOT_TRACK, or
# "updateCheck": false in the config.
_jd_update_off() {
  local cfg
  case ${JD_NO_UPDATE_CHECK-} in '' | 0 | false | no) ;; *) return 0 ;; esac
  case ${DO_NOT_TRACK-} in '' | 0 | false | no) ;; *) return 0 ;; esac
  cfg=$(_jd_paths_config)
  [ -f "$cfg" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [ "$(jq -r 'if type == "object" then .updateCheck else null end' "$cfg" 2>/dev/null)" = false ]
}

# Read the latest version from GitHub, and write it to the cache file.
#
# This is the only network request jd makes. It is 'git ls-remote', so
# GitHub receives what git sends for any ls-remote, and nothing from jd.
# No telemetry is sent. It reads no git config, so that a rule in the
# user's config, such as url.<base>.insteadOf, cannot change the request,
# and it never prompts.
_jd_update_fetch() {
  local tags latest
  tags=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
    git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 \
    ls-remote --tags --refs "$_JD_UPDATE_URL" 2>/dev/null) || return 1
  latest=$(printf '%s\n' "$tags" | _jd_update_latest_tag)
  [ -n "$latest" ] || return 1
  _jd_update_cache_read
  _JD_UPDATE_LATEST=$latest
  _jd_update_cache_write
}

# Start _jd_update_fetch in the background, and return at once. Every
# stream is redirected, so that the hook's $( ) does not wait for it.
# SIGHUP is ignored, so that the check finishes when the terminal closes.
_jd_update_check_start() {
  command -v git >/dev/null 2>&1 || return 0
  (
    trap '' HUP
    _jd_update_fetch </dev/null >/dev/null 2>&1 &
  )
}

# bin/jd calls this when a command is done. $@ the words of the command.
_jd_update_after() {
  local w=${1-} force=0 now
  [ "$w" = jdex ] && w=${2-}
  case $w in
    paths | update) return 0 ;;
    -v | --version | version) force=1 ;;
  esac
  if [ "$force" -eq 0 ] && ! _jd_update_tty; then
    return 0
  fi
  _jd_update_off && return 0
  now=$(_jd_update_now)
  _jd_update_cache_read

  if _jd_update_newer "$_JD_UPDATE_LATEST" "$_JD_CLI_VERSION"; then
    printf "jd: version %s is available, this is %s - run 'jd update'\n" \
      "$_JD_UPDATE_LATEST" "$_JD_CLI_VERSION" >&2
  fi

  if _jd_update_tty && _jd_update_due "$_JD_UPDATE_CHECKED" "$now"; then
    # The time is written first, so that the commands that run while
    # the check runs do not start a check of their own.
    _JD_UPDATE_CHECKED=$now
    _jd_update_cache_write && _jd_update_check_start
  fi
  return 0
}

# ------------------------------------------------------------ jd update

# The changelog entries for every version greater than $2. $1 the path
# of CHANGELOG.md.
_jd_update_changelog() {
  [ -f "$1" ] || return 0
  awk -v old="$2" '
    function newer(a, b,    x, y, i) {
      split(a, x, ".")
      split(b, y, ".")
      for (i = 1; i <= 3; i++) {
        if (x[i] + 0 > y[i] + 0) return 1
        if (x[i] + 0 < y[i] + 0) return 0
      }
      return 0
    }
    /^## [0-9]+\.[0-9]+\.[0-9]+/ { on = newer($2, old) }
    on { print }
  ' "$1"
}

# Pull the latest version into a clone of this repo. $1 the folder.
_jd_update_run() {
  local dir=$1 branch old new before
  command -v git >/dev/null 2>&1 || { _jd_nav_err "git is not installed"; return 1; }
  if [ ! -e "$dir/.git" ]; then
    _jd_nav_err "$dir is not a git clone, so 'jd update' cannot update it - see https://github.com/johnnydecimal/cli.johnnydecimal.com"
    return 1
  fi
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD)
  if [ -z "$branch" ]; then
    _jd_nav_err "$dir is not on a branch - 'jd update' updates the branch main"
    return 1
  fi
  if [ "$branch" != main ]; then
    _jd_nav_err "$dir is on the branch '$branch' - 'jd update' updates the branch main"
    return 1
  fi
  if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    _jd_nav_err "$dir contains uncommitted changes - commit or discard them, then run 'jd update' again"
    return 1
  fi

  old=$(_jd_update_version_in "$dir/bin/jd")
  before=$(git -C "$dir" rev-parse HEAD)
  git -C "$dir" pull --ff-only -q || { _jd_nav_err "git pull failed in $dir"; return 1; }
  new=$(_jd_update_version_in "$dir/bin/jd")

  _jd_update_cache_read
  _JD_UPDATE_CHECKED=$(_jd_update_now)
  _JD_UPDATE_LATEST=$new
  _jd_update_cache_write

  if [ "$(git -C "$dir" rev-parse HEAD)" = "$before" ]; then
    printf 'jd %s is the latest version\n' "$new"
    return 0
  fi
  printf 'jd updated from %s to %s\n' "$old" "$new"
  if ! git -C "$dir" diff --quiet "$before" HEAD -- jd.sh jd.fish lib/prompt.zsh \
    lib/prompt.bash lib/theme.zsh lib/theme.bash; then
    printf 'Start a new shell to load the new shell hook.\n'
  fi
  if _jd_update_newer "$new" "$old"; then
    printf '\n'
    _jd_update_changelog "$dir/CHANGELOG.md" "$old"
  fi
}

# 'jd update'. $@ the words after 'update'.
_jd_update() {
  case ${1-} in
    -h | --help | help) _jd_update_usage; return 0 ;;
    '') ;;
    *) _jd_nav_err "'jd update' takes nothing after it"; return 1 ;;
  esac
  _jd_update_run "$_JD_CLI_DIR"
}
