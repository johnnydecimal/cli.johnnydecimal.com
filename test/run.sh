#!/bin/sh
# SPDX-License-Identifier: MIT
# run.sh - run the whole test suite, in every shell the tools support
#
#   test/run.sh              run everything, in bash and zsh
#   test/run.sh nav-fs       run only the case files whose name matches
#
# The tools must work in bash 3.2, which is the bash macOS ships, and in
# zsh. So every case file runs once per shell. A failure in either one is
# a failure.
#
# Environment:
#   JD_TEST_SHELLS   space separated shells to use. Default: /bin/bash zsh
#   JD_TEST_KEEP     set to 1 to keep the temp directory for a look
#
# Each case file gets its own temp directory, its own $HOME, and its own
# fixture systems. Nothing here reads the real ~/.jd/config.json or goes
# near a real Johnny.Decimal system.
#
# This file is POSIX sh. The harness and the case files are not, because
# they source jd.sh and so must run under bash or zsh.

set -u

_jd_r_here=$(cd -- "$(dirname -- "$0")" && pwd -P)
JD_T_REPO=$(cd -- "$_jd_r_here/.." && pwd -P)
export JD_T_REPO

_jd_r_match=${1-}

# ------------------------------------------------------------ the shells

_jd_r_shells=''
for _jd_r_s in ${JD_TEST_SHELLS:-/bin/bash zsh}; do
  _jd_r_path=$(command -v "$_jd_r_s" 2>/dev/null || true)
  if [ -n "$_jd_r_path" ]; then
    _jd_r_shells="$_jd_r_shells $_jd_r_path"
  else
    printf 'run.sh: no %s on this machine, skipping it\n' "$_jd_r_s" >&2
  fi
done
if [ -z "$_jd_r_shells" ]; then
  printf 'run.sh: found none of the shells to test with\n' >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'run.sh: jq is not installed, and the tools need it\n' >&2
  exit 2
fi

# ------------------------------------------------------------- the cases

_jd_r_base=$(cd -- "$(mktemp -d)" && pwd -P)
_jd_r_cleanup() {
  [ "${JD_TEST_KEEP:-0}" = 1 ] || rm -rf "$_jd_r_base"
}
trap _jd_r_cleanup EXIT INT TERM

_jd_r_cases=$_jd_r_base/cases
find "$JD_T_REPO/test/cases" -maxdepth 1 -name '*.sh' | sort >"$_jd_r_cases"

printf '# jd test suite\n'
printf '# repo: %s\n' "$JD_T_REPO"
printf '# jq:   %s\n' "$(jq --version 2>&1)"

_jd_r_bad=0

for _jd_r_shell in $_jd_r_shells; do
  _jd_r_name=$(basename -- "$_jd_r_shell")
  _jd_r_ver=$("$_jd_r_shell" -c 'printf "%s" "${BASH_VERSION-}${ZSH_VERSION-}"' 2>/dev/null)
  printf '\n# ================ %s %s ================\n' "$_jd_r_name" "$_jd_r_ver"

  while IFS= read -r _jd_r_case; do
    _jd_r_file=$(basename -- "$_jd_r_case")
    case $_jd_r_match in
      '') ;;
      *) case $_jd_r_file in *"$_jd_r_match"*) ;; *) continue ;; esac ;;
    esac

    _jd_r_tmp=$_jd_r_base/$_jd_r_name/${_jd_r_file%.sh}
    mkdir -p "$_jd_r_tmp/home"
    _jd_r_counts=$_jd_r_tmp/.counts

    printf '\n# ---- %s ----\n' "$_jd_r_file"
    env \
      HOME="$_jd_r_tmp/home" \
      JD_CONFIG="$_jd_r_tmp/none.json" \
      JD_T_REPO="$JD_T_REPO" \
      JD_T_TMP="$_jd_r_tmp" \
      JD_T_SHELL="$_jd_r_name" \
      JD_T_FILE="test/cases/$_jd_r_file" \
      JD_T_COUNTS="$_jd_r_counts" \
      "$_jd_r_shell" "$_jd_r_case"
    _jd_r_status=$?

    if [ ! -f "$_jd_r_counts" ]; then
      printf 'not ok - %s [%s] did not finish (exit %s)\n' \
        "$_jd_r_file" "$_jd_r_name" "$_jd_r_status"
      _jd_r_bad=$((_jd_r_bad + 1))
      printf '0 1 0\n' >"$_jd_r_counts"
    elif [ "$_jd_r_status" -ne 0 ]; then
      _jd_r_bad=$((_jd_r_bad + 1))
    fi
  done <"$_jd_r_cases"
done

# ------------------------------------------------------------- the total

printf '\n# ================ total ================\n'
find "$_jd_r_base" -name '.counts' -exec cat {} + | awk -v bad="$_jd_r_bad" '
  { p += $1; f += $2; s += $3 }
  END {
    printf "# %d passed, %d failed, %d skipped, in %d case runs\n", p, f, s, NR
    if (f > 0 || bad > 0) { print "# FAIL"; exit 1 }
    print "# PASS"
  }
'
