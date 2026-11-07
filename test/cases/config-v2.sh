# SPDX-License-Identifier: MIT
# config-v2.sh - the version of the config, and the change from version
# 1 to version 2

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/fixtures.sh"

_jd_fx_build

# A version 1 config. $1 the path, $2 the JDex value, as JSON, $3 the
# workPackages value, as JSON, or empty for none.
_jd_t_v1() {
  jq -n --arg root "$JD_FX_ROOT" --argjson jdex "$2" --argjson wp "${3:-null}" '
    {version: 1, systems: [
      ({sys: "D25", title: "Test system", root: $root, jdex: $jdex, default: true}
        + (if $wp == null then {} else {workPackages: $wp} end)),
      {sys: "P76", title: "Second system", root: "/nowhere"}
    ]}' >"$1"
}

_jd_t_cfg="$JD_T_TMP/v1.json"
_jd_t_jq() { jq -c "$1" "$_jd_t_cfg"; }

# ------------------------------------------------- the note app and tasks

_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\"" \
  '{"notes": {"adapter": "obsidian", "vault": "D25 JDex"}, "tasks": {"adapter": "things", "source": "abc"}}'
cp "$_jd_t_cfg" "$JD_T_TMP/v1.orig"
_jd_t_config "$_jd_t_cfg"

_jd_t_run "$JD_T_BIN" 11.11
_jd_t_status 'migrate: the command still runs' 0
_jd_t_eq 'migrate: the command prints its folder' \
  "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID" "$JD_T_OUT"
_jd_t_eq 'migrate: prints one line' \
  "jd: changed the config to version 2. The old file is $_jd_t_cfg.v1" "$JD_T_ERR"
_jd_t_eq 'migrate: version 2' 2 "$(_jd_t_jq '.version')"
_jd_t_eq 'migrate: the note app moves into jdex' \
  "{\"app\":\"obsidian\",\"path\":\"$JD_FX_JDEX\",\"vault\":\"D25 JDex\"}" "$(_jd_t_jq '.systems[0].jdex')"
_jd_t_eq 'migrate: tasks.adapter becomes tasks.app' \
  '{"tasks":{"app":"things","source":"abc"}}' "$(_jd_t_jq '.systems[0].workPackages')"
_jd_t_eq 'migrate: the keys keep their order' '["sys","title","root","jdex","default","workPackages"]' \
  "$(_jd_t_jq '.systems[0] | keys_unsorted')"
_jd_t_eq 'migrate: a system with no jdex is unchanged' \
  '{"sys":"P76","title":"Second system","root":"/nowhere"}' "$(_jd_t_jq '.systems[1]')"
if cmp -s "$_jd_t_cfg.v1" "$JD_T_TMP/v1.orig"; then
  _jd_t_ok 'migrate: the old file is kept as .v1'
else
  _jd_t_bad 'migrate: the old file is kept as .v1' 'the old file' 'something else'
fi

_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'migrate: the next command prints nothing more' '' "$JD_T_ERR"

# An earlier .v1 is never replaced.
_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\""
_jd_t_run "$JD_T_BIN" 11.11
if cmp -s "$_jd_t_cfg.v1" "$JD_T_TMP/v1.orig"; then
  _jd_t_ok 'migrate: an earlier .v1 is not replaced'
else
  _jd_t_bad 'migrate: an earlier .v1 is not replaced' 'the first old file' 'the second'
fi
rm -f "$_jd_t_cfg.v1"

# --------------------------------------------------------- the JDex app

# A folder that is an Obsidian vault, and no note app in the config.
mkdir -p "$JD_FX_JDEX/.obsidian"
_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\""
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'migrate: a folder with .obsidian is an Obsidian JDex' \
  "{\"app\":\"obsidian\",\"path\":\"$JD_FX_JDEX\"}" "$(_jd_t_jq '.systems[0].jdex')"
rmdir "$JD_FX_JDEX/.obsidian"
rm -f "$_jd_t_cfg.v1"

_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\""
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'migrate: a folder with no .obsidian has no app' \
  "{\"path\":\"$JD_FX_JDEX\"}" "$(_jd_t_jq '.systems[0].jdex')"
rm -f "$_jd_t_cfg.v1"

_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\"" '{"notes": {"adapter": "none"}}'
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'migrate: the none note app is no app' \
  "{\"path\":\"$JD_FX_JDEX\"}" "$(_jd_t_jq '.systems[0].jdex')"
_jd_t_eq 'migrate: an empty workPackages is removed' 'false' \
  "$(_jd_t_jq '.systems[0] | has("workPackages")')"
rm -f "$_jd_t_cfg.v1"

# A config with no version is version 1.
_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\""
jq 'del(.version)' "$_jd_t_cfg" >"$_jd_t_cfg.tmp" && mv "$_jd_t_cfg.tmp" "$_jd_t_cfg"
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_eq 'migrate: no version is version 1' 2 "$(_jd_t_jq '.version')"
rm -f "$_jd_t_cfg.v1"

# A config that is a symlink stays a symlink, and the old file is next
# to the target.
mkdir -p "$JD_T_TMP/dotfiles"
_jd_t_v1 "$JD_T_TMP/dotfiles/config.json" "\"$JD_FX_JDEX\""
ln -s "$JD_T_TMP/dotfiles/config.json" "$JD_T_TMP/link.json"
_jd_t_config "$JD_T_TMP/link.json"
_jd_t_run "$JD_T_BIN" 11.11
if [ -L "$JD_T_TMP/link.json" ]; then
  _jd_t_ok 'migrate: a symlink stays a symlink'
else
  _jd_t_bad 'migrate: a symlink stays a symlink' 'a symlink' 'a file'
fi
_jd_t_eq 'migrate: the target is version 2' 2 "$(jq '.version' "$JD_T_TMP/dotfiles/config.json")"
if [ -f "$JD_T_TMP/dotfiles/config.json.v1" ]; then
  _jd_t_ok 'migrate: the old file is next to the target'
else
  _jd_t_bad 'migrate: the old file is next to the target' 'config.json.v1' 'no file'
fi
_jd_t_config "$_jd_t_cfg"

# 'jd paths' reads no config, so it changes nothing.
_jd_t_v1 "$_jd_t_cfg" "\"$JD_FX_JDEX\""
_jd_t_run "$JD_T_BIN" paths config
_jd_t_eq 'paths: does not change the config' 1 "$(_jd_t_jq '.version')"
_jd_t_run "$JD_T_BIN" version
_jd_t_eq 'version: does not change the config' 1 "$(_jd_t_jq '.version')"

# A folder that jd cannot write to.
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p "$JD_T_TMP/readonly"
  _jd_t_v1 "$JD_T_TMP/readonly/config.json" "\"$JD_FX_JDEX\""
  chmod 555 "$JD_T_TMP/readonly"
  _jd_t_config "$JD_T_TMP/readonly/config.json"
  _jd_t_run "$JD_T_BIN" 11.11
  _jd_t_status 'migrate: a folder jd cannot write to, exit status' 1
  _jd_t_contains 'migrate: says it could not change the config' \
    'the config is version 1, and jd could not change it to version 2' "$JD_T_ERR"
  _jd_t_eq 'migrate: the file is unchanged' 1 "$(jq '.version' "$JD_T_TMP/readonly/config.json")"
  chmod 755 "$JD_T_TMP/readonly"
  _jd_t_config "$_jd_t_cfg"
else
  _jd_t_skipped 'migrate: a folder jd cannot write to' 'root can write anywhere'
fi

# ------------------------------------------------------ other versions

jq -n --arg root "$JD_FX_ROOT" '{version: 3, systems: [{sys: "D25", root: $root}]}' >"$_jd_t_cfg"
cp "$_jd_t_cfg" "$JD_T_TMP/v3.orig"
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_status 'version 3: exit status' 1
_jd_t_eq 'version 3: names the fix' \
  "jd: the config is version 3, and this jd reads version 2 - run 'jd update'" "$JD_T_ERR"
if cmp -s "$_jd_t_cfg" "$JD_T_TMP/v3.orig"; then
  _jd_t_ok 'version 3: the file is unchanged'
else
  _jd_t_bad 'version 3: the file is unchanged' 'the same file' 'a changed file'
fi

jq -n --arg root "$JD_FX_ROOT" '{version: "two", systems: [{sys: "D25", root: $root}]}' >"$_jd_t_cfg"
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_status 'not a number: exit status' 1
_jd_t_contains 'not a number: says so' "a version that is not a number, 'two'" "$JD_T_ERR"

jq -n --arg root "$JD_FX_ROOT" '{version: 0, systems: [{sys: "D25", root: $root}]}' >"$_jd_t_cfg"
_jd_t_run "$JD_T_BIN" 11.11
_jd_t_status 'version 0: exit status' 1
_jd_t_contains 'version 0: names the version' 'the config is version 0, and this jd reads version 2' "$JD_T_ERR"

_jd_t_summary
