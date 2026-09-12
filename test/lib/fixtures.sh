# SPDX-License-Identifier: MIT
# fixtures.sh - the fake Johnny.Decimal systems the tests navigate
#
# Every test runs against a system built here, under $JD_T_TMP. Nothing
# in the suite ever reads the machine's real config or touches a real
# system. The harness refuses to load a $JD_CONFIG outside $JD_T_TMP.
#
# A case file calls _jd_fx_build once, near the top. It then has:
#   $JD_FX_ROOT   the filesystem of the D25 test system
#   $JD_FX_JDEX   the JDex of the D25 test system
#   $JD_FX_ROOT2  the filesystem of the P76 test system, which has no JDex
#
# The paths hold spaces on purpose. Real system names do.
#
# Depths matter, because nav.sh looks for things at a fixed depth:
#   area      depth 1 from the root
#   category  depth 2
#   ID        depth 3
#   work pkg  depth 2, i.e. inside an area, beside the categories
#
# The tree carries the awkward names on purpose:
#   11.11+ Extension       an extend-the-end. 'jd 11.11' must not see it.
#   W0212~21.35 ...        the normal work package form. 2.0.4 fixed it.
#   W0212+ Kettle child    another extend-the-end. 'jd W0212' must not
#                          see it, and neither must the word search.
#   notes                  a folder with no number, for the zsh prompt
#   12.99 Made by jd.md    in the JDex only, so jd makes its folder
#   19.99 No category.md   in the JDex only, and its category is missing
#   W0300~21.35 ...        in the JDex only, so jd makes its folder
#   W0000-9999 Work ...    the area a work package folder is made in.
#                          Empty in the filesystem, so a test can see
#                          what jd puts there.
#   13 Odds & ends         a name with the characters a shell minds:
#                          '&', a comma, and more than one space

JD_FX_DIR="$JD_T_TMP/fixtures"
JD_FX_ROOT="$JD_FX_DIR/D25 Test system"
JD_FX_JDEX="$JD_FX_DIR/D25 JDex"
JD_FX_ROOT2="$JD_FX_DIR/P76 Second system"

# Build all three trees. Safe to call twice.
_jd_fx_build() {
  _jd_fx_build_root
  _jd_fx_build_jdex
  _jd_fx_build_root2
}

_jd_fx_build_root() {
  mkdir -p \
    "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID/sub/deeper" \
    "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11+ Extension" \
    "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.12 Second ID" \
    "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.13 Tripsy travel" \
    "$JD_FX_ROOT/10-19 Area one/12 Category twelve/12.11 Another thing" \
    "$JD_FX_ROOT/10-19 Area one/13 Odds & ends/13.11 Bits, bobs & things" \
    "$JD_FX_ROOT/10-19 Area one/W0189 Work package one" \
    "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.11 Tripsy notes" \
    "$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.35 Some title" \
    "$JD_FX_ROOT/20-29 Area two/22 Category twentytwo/22.11 Widget one" \
    "$JD_FX_ROOT/20-29 Area two/22 Category twentytwo/22.12 Widget two" \
    "$JD_FX_ROOT/20-29 Area two/W0212~21.35 Kettle rebuild" \
    "$JD_FX_ROOT/20-29 Area two/W0212+ Kettle child" \
    "$JD_FX_ROOT/W0000-9999 Work packages" \
    "$JD_FX_ROOT/notes"
  # A folder named like an ID, but too deep to be one. 'jd 11.11' must
  # not find it.
  mkdir -p "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.12 Second ID/11.11 Decoy"
}

_jd_fx_build_jdex() {
  mkdir -p \
    "$JD_FX_JDEX/10-19 Area one/11 Category eleven" \
    "$JD_FX_JDEX/10-19 Area one/12 Category twelve" \
    "$JD_FX_JDEX/10-19 Area one/19 Category nineteen" \
    "$JD_FX_JDEX/20-29 Area two/21 Category twentyone" \
    "$JD_FX_JDEX/20-29 Area two/22 Category twentytwo" \
    "$JD_FX_JDEX/W0000-9999 Work packages"
  _jd_fx_note "$JD_FX_JDEX/10-19 Area one/11 Category eleven/11.11 First ID.md"
  _jd_fx_note "$JD_FX_JDEX/10-19 Area one/11 Category eleven/11.12 Second ID.md"
  _jd_fx_note "$JD_FX_JDEX/10-19 Area one/11 Category eleven/11.13 Tripsy travel.md"
  _jd_fx_note "$JD_FX_JDEX/10-19 Area one/12 Category twelve/12.11 Another thing.md"
  _jd_fx_note "$JD_FX_JDEX/10-19 Area one/12 Category twelve/12.99 Made by jd.md"
  _jd_fx_note "$JD_FX_JDEX/10-19 Area one/19 Category nineteen/19.99 No category.md"
  _jd_fx_note "$JD_FX_JDEX/20-29 Area two/21 Category twentyone/21.11 Tripsy notes.md"
  _jd_fx_note "$JD_FX_JDEX/20-29 Area two/21 Category twentyone/21.35 Some title.md"
  _jd_fx_note "$JD_FX_JDEX/20-29 Area two/22 Category twentytwo/22.11 Widget one.md"
  _jd_fx_note "$JD_FX_JDEX/20-29 Area two/22 Category twentytwo/22.12 Widget two.md"
  _jd_fx_note "$JD_FX_JDEX/20-29 Area two/W0212~21.35 Kettle rebuild.md"
  _jd_fx_note "$JD_FX_JDEX/W0000-9999 Work packages/W0300~21.35 Made by jd.md"
}

_jd_fx_build_root2() {
  mkdir -p "$JD_FX_ROOT2/30-39 Area three/31 Category thirtyone/31.11 Pear"
}

_jd_fx_note() { printf 'fixture note\n' >"$1"; }

# The templates 'jd new' uses. Not part of _jd_fx_build, because the
# filesystem work package area is empty on purpose: other cases look in
# it to see what jd put there. A case that tests 'jd new' calls this.
#
# Templates live in the filesystem, in the templates ID at each level.
#   W0003 Templates/Work package template.md   the work package note
#   W0003 Templates/Work package template/     the work package folders
#   21.03 .../ID template.md   category 21's own ID template
#   20.03 .../ID template.md   area 20-29's ID template. Category 22 uses it
#   00.03 .../ID template.md   the system's ID template. Area 10-19 uses it
_jd_fx_build_templates() {
  local w3 tpl
  w3="$JD_FX_ROOT/W0000-9999 Work packages/W0003 Templates"
  tpl="$w3/Work package template"
  mkdir -p "$tpl/05 Planning" "$tpl/20 Words"
  printf 'fixture\n' >"$tpl/05 Planning/a file.txt"
  # A .DS_Store in a template must not reach the new work package.
  printf 'junk\n' >"$tpl/.DS_Store"
  cat >"$w3/Work package template.md" <<'EOT'
- Permalink:
	- ^{{w}}
- Related:
	- [Obsidian]({{NOTES_URL}})
	- [Things]({{TASKS_URL}})

---

## Scope for {{NAME}}
EOT
  _jd_fx_build_id_templates
}

# The three ID templates, one per level. Each says which level it is, so
# a test can tell which one jd used.
_jd_fx_build_id_templates() {
  local sys area cat
  sys="$JD_FX_ROOT/00-09 System area/00 System category/00.03 Templates for the system"
  area="$JD_FX_ROOT/20-29 Area two/20 Management of area 20-29/20.03 Templates for area 20-29"
  cat="$JD_FX_ROOT/20-29 Area two/21 Category twentyone/21.03 Templates for category 21"
  mkdir -p "$sys" "$area" "$cat"
  # {{FOO}} is not a placeholder jd knows. It is left out of the note.
  printf 'System template for {{NAME}}{{FOO}}\n' >"$sys/ID template.md"
  printf 'Area template for {{ID}}, {{TITLE}}\n' >"$area/ID template.md"
  cat >"$cat/ID template.md" <<'EOT'
Category template for {{NAME}}

{{?PURPOSE Why this ID exists}}
EOT
}

# A work package template note that holds '{{?TOKEN}}' tokens, for the
# toFill tests. It takes the place of the one _jd_fx_build_templates
# writes, so call it after that, or on its own.
#   $JD_FX_ROOT/W0000-9999 .../W0003 Templates/Work package template.md
_jd_fx_build_templates_tokens() {
  mkdir -p "$JD_FX_ROOT/W0000-9999 Work packages/W0003 Templates"
  cat >"$JD_FX_ROOT/W0000-9999 Work packages/W0003 Templates/Work package template.md" <<'EOT'
- Permalink:
	- ^{{w}}

---

## Scope

{{?SCOPE}}

## Deliverable

{{?DELIVERABLE What we hand over}}
EOT
}

# A $PATH with no jq on it, so the "jq is not installed" branch can be
# tested. Some machines carry jq in /usr/bin, so hiding it by trimming
# $PATH is not reliable. Build a bin folder instead and link in only the
# commands the tools and the harness use. Prints the folder.
#
# bash is in the list because bin/jd starts '#!/usr/bin/env bash', and
# env looks the shell up on $PATH like anything else.
_jd_fx_nojq_bin() {
  local dir cmd src
  dir="$JD_T_TMP/nojq-bin"
  mkdir -p "$dir"
  for cmd in cat find sort grep sed awk basename dirname mkdir rm tr env bash; do
    src=$(command -v "$cmd" 2>/dev/null) || continue
    [ -n "$src" ] && ln -sf "$src" "$dir/$cmd"
  done
  printf '%s' "$dir"
}

# Undo whatever a test made. jd makes a folder for an ID that is in the
# JDex but not in the filesystem, so a case that exercises that must put
# the tree back.
_jd_fx_reset() {
  rm -rf "$JD_FX_DIR"
  _jd_fx_build
}

# --------------------------------------------------------------- configs
#
# Each writer takes the path to write. The paths inside hold spaces but
# no quotes or backslashes, so they need no JSON escaping.

# Two systems. D25 is the default and has a JDex. P76 has neither.
_jd_fx_config_two() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX",
      "default": true
    },
    {
      "sys": "P76",
      "title": "Second system",
      "root": "$JD_FX_ROOT2"
    }
  ]
}
EOF
}

# One system, no sys. The docs say sys is only needed for more than one
# system. 2.0.2 and 2.0.3 are about this shape.
_jd_fx_config_single_nosys() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX"
    }
  ]
}
EOF
}

# One system, with a sys.
_jd_fx_config_single() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX"
    }
  ]
}
EOF
}

# One system, the second one. Used to show that $JD_CONFIG really does
# decide which system jd acts on.
_jd_fx_config_second_only() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "P76",
      "title": "Second system",
      "root": "$JD_FX_ROOT2"
    }
  ]
}
EOF
}

# Two systems, and D25 knows how to make a work package. The tasks
# adapter is left out, so it is 'none': the suite never talks to a task
# app.
_jd_fx_config_new() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX",
      "default": true,
      "workPackages": {
        "notes": { "adapter": "obsidian", "vault": "D25 JDex" }
      }
    },
    {
      "sys": "P76",
      "title": "Second system",
      "root": "$JD_FX_ROOT2"
    }
  ]
}
EOF
}

# The same, but it still holds the template paths that 2.5 read. jd no
# longer reads them, and says so.
_jd_fx_config_new_oldkeys() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX",
      "default": true,
      "workPackages": {
        "noteTemplate": "W0003 Template.md",
        "folderTemplate": "W0003 Templates/Copy me",
        "notes": { "adapter": "obsidian", "vault": "D25 JDex" },
        "tasks": { "template": "W0003 Templates/Template project.json" }
      }
    }
  ]
}
EOF
}

# The same, but the adapter names are wrong.
_jd_fx_config_new_badadapter() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX",
      "default": true,
      "workPackages": {
        "notes": { "adapter": "nosuchapp" }
      }
    }
  ]
}
EOF
}

# Two systems, and the second one has no sys. That is an error.
_jd_fx_config_multi_nosys() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX"
    },
    {
      "title": "Second system",
      "root": "$JD_FX_ROOT2"
    }
  ]
}
EOF
}

# The default is the second entry, not the first. jd must follow it.
_jd_fx_config_default_second() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "P76",
      "title": "Second system",
      "root": "$JD_FX_ROOT2"
    },
    {
      "sys": "D25",
      "title": "Test system",
      "root": "$JD_FX_ROOT",
      "jdex": "$JD_FX_JDEX",
      "default": true
    }
  ]
}
EOF
}

# A config with no systems in it.
_jd_fx_config_empty() {
  cat >"$1" <<'EOF'
{
  "version": 1,
  "systems": []
}
EOF
}

# A config that is not JSON.
_jd_fx_config_malformed() {
  cat >"$1" <<'EOF'
{
  "version": 1,
  "systems": [
EOF
}

# A system whose root does not exist on disk.
_jd_fx_config_missing_root() {
  cat >"$1" <<EOF
{
  "version": 1,
  "systems": [
    {
      "sys": "D25",
      "title": "Gone",
      "root": "$JD_FX_DIR/does not exist"
    }
  ]
}
EOF
}
