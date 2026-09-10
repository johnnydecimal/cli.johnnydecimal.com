# SPDX-License-Identifier: MIT
# beta.sh - the beta flag, and 'jd beta', which turns it on and off

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

# A JD_BETA from the shell that started the suite would turn beta on for
# every test here.
unset JD_BETA

_jd_fx_build
_jd_fx_config_new "$JD_T_TMP/beta.json"
_jd_t_load "$JD_T_TMP/beta.json"
_jd_t_cfg="$JD_T_TMP/beta.json"

_jd_t_beta() { jq -r '.beta' "$1"; }

# ---------------------------------------------------------------- status

_jd_t_run jd beta --help
_jd_t_status 'help: exit status' 0
_jd_t_contains 'help: prints the usage line' 'usage: <system> beta' "$JD_T_OUT"

_jd_t_run jd beta
_jd_t_status 'status: exit status' 0
_jd_t_eq 'status: a config with no beta key is off' 'beta is off' "$JD_T_OUT"

_jd_t_run jd beta status
_jd_t_eq 'status: the word status says the same' 'beta is off' "$JD_T_OUT"

# ---------------------------------------------------------------- on, off

_jd_t_run jd beta on
_jd_t_status 'on: exit status' 0
_jd_t_eq 'on: says so' 'beta is on' "$JD_T_OUT"
_jd_t_eq 'on: writes true' 'true' "$(_jd_t_beta "$_jd_t_cfg")"
_jd_t_eq 'on: the key goes straight after version' 'version,beta' \
  "$(jq -r 'keys_unsorted | .[0:2] | join(",")' "$_jd_t_cfg")"
_jd_t_eq 'on: keeps the systems' 'D25' "$(jq -r '.systems[0].sys' "$_jd_t_cfg")"

_jd_t_run jd beta
_jd_t_eq 'on: status now says on' 'beta is on' "$JD_T_OUT"

_jd_t_run jd beta off
_jd_t_status 'off: exit status' 0
_jd_t_eq 'off: says so' 'beta is off' "$JD_T_OUT"
_jd_t_eq 'off: writes false' 'false' "$(_jd_t_beta "$_jd_t_cfg")"

# A config already in the state asked for is not rewritten, so its own
# layout survives.
printf '{\n    "version": 1, "systems": %s\n}\n' \
  "$(jq -c '.systems' "$_jd_t_cfg")" >"$JD_T_TMP/layout.json"
cp "$JD_T_TMP/layout.json" "$JD_T_TMP/layout.before"
_jd_t_load "$JD_T_TMP/layout.json"
_jd_t_run jd beta off
_jd_t_status 'off when already off: exit status' 0
if cmp -s "$JD_T_TMP/layout.json" "$JD_T_TMP/layout.before"; then
  _jd_t_ok 'off when already off: does not rewrite the file'
else
  _jd_t_bad 'off when already off: does not rewrite the file' 'the same bytes' 'a rewritten file'
fi

# --------------------------------------------------------------- JD_BETA

_jd_t_load "$_jd_t_cfg"
JD_BETA=1
export JD_BETA
_jd_t_run jd beta
_jd_t_contains 'JD_BETA: status says it is on in this shell' \
  'because JD_BETA is set' "$JD_T_OUT"
_jd_t_run jd beta off
_jd_t_contains 'JD_BETA: off still says why it is on' \
  'because JD_BETA is set' "$JD_T_OUT"
_jd_t_eq 'JD_BETA: off writes nothing, because the config is already off' \
  'false' "$(_jd_t_beta "$_jd_t_cfg")"
unset JD_BETA

# --------------------------------------------------------- what it keeps

# A config with no version gets no "version": null.
jq 'del(.version)' "$_jd_t_cfg" >"$JD_T_TMP/nover.json"
_jd_t_load "$JD_T_TMP/nover.json"
_jd_t_run jd beta on
_jd_t_eq 'no version: still writes true' 'true' "$(_jd_t_beta "$JD_T_TMP/nover.json")"
_jd_t_eq 'no version: adds no version key' 'false' \
  "$(jq 'has("version")' "$JD_T_TMP/nover.json")"

# A config that is a symlink stays a symlink, and its target changes.
cp "$_jd_t_cfg" "$JD_T_TMP/real.json"
ln -s real.json "$JD_T_TMP/link.json"
_jd_t_load "$JD_T_TMP/link.json"
_jd_t_run jd beta on
_jd_t_status 'symlink: exit status' 0
if [ -L "$JD_T_TMP/link.json" ]; then
  _jd_t_ok 'symlink: the link is still a link'
else
  _jd_t_bad 'symlink: the link is still a link' 'a symlink' 'a regular file'
fi
_jd_t_eq 'symlink: the target is written' 'true' "$(_jd_t_beta "$JD_T_TMP/real.json")"

# The mode is carried over.
cp "$_jd_t_cfg" "$JD_T_TMP/mode.json"
chmod 644 "$JD_T_TMP/mode.json"
_jd_t_load "$JD_T_TMP/mode.json"
_jd_t_run jd beta on
_jd_t_eq 'mode: stays 644' '-rw-r--r--' "$(ls -l "$JD_T_TMP/mode.json" | cut -c1-10)"

# --------------------------------------------------------- what it refuses

_jd_t_load "$_jd_t_cfg"

_jd_t_run jd beta maybe
_jd_t_status 'unknown word: exit status' 1
_jd_t_contains 'unknown word: says so' 'not a beta command' "$JD_T_ERR"

_jd_t_run jd beta on now
_jd_t_status 'extra words: exit status' 1

# A config that is not JSON is left alone. It is broken after the load,
# so jd itself is still defined.
cp "$_jd_t_cfg" "$JD_T_TMP/broken.json"
_jd_t_load "$JD_T_TMP/broken.json"
printf '{ not json\n' >"$JD_T_TMP/broken.json"
_jd_t_run jd beta on
_jd_t_status 'not JSON: exit status' 1
_jd_t_eq 'not JSON: the file is untouched' '{ not json' "$(cat "$JD_T_TMP/broken.json")"

# A folder that cannot be written to: the write fails, and the config is
# untouched. Root can write anywhere, so the test means nothing as root.
if [ "$(id -u)" = 0 ]; then
  _jd_t_skipped 'read-only folder: refuses' 'running as root'
else
  mkdir "$JD_T_TMP/ro"
  cp "$_jd_t_cfg" "$JD_T_TMP/ro/config.json"
  _jd_t_load "$JD_T_TMP/ro/config.json"
  chmod 555 "$JD_T_TMP/ro"
  _jd_t_run jd beta on
  chmod 755 "$JD_T_TMP/ro"
  _jd_t_status 'read-only folder: exit status' 1
  _jd_t_contains 'read-only folder: says so' 'could not write' "$JD_T_ERR"
  _jd_t_eq 'read-only folder: the config is untouched' 'false' \
    "$(_jd_t_beta "$JD_T_TMP/ro/config.json")"
fi

# ------------------------------------------------------- where it works

# 'jd beta' reads no system, so a root folder that is not there does not
# stop it.
jq '.systems[0].root = "/nonexistent-jd-test-root"' "$_jd_t_cfg" >"$JD_T_TMP/noroot.json"
_jd_t_load "$JD_T_TMP/noroot.json"
_jd_t_run jd beta
_jd_t_status 'no root folder: status still works' 0

_jd_t_run jdex beta
_jd_t_status 'jdex beta: works from jdex too' 0

_jd_t_load "$_jd_t_cfg"
_jd_t_run jd help
_jd_t_contains 'help: the main usage lists beta' '<system> beta' "$JD_T_OUT"

_jd_t_summary
