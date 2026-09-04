# jd-nav

Shell functions that cd around a Johnny.Decimal system. Requires `jq`. Works in bash 3.2+ and zsh.

## Install

See the [repo README](../README.md) for the clone and config steps. Then add this line to `.zshrc` or `.bashrc` and start a new shell:

```sh
source ~/.jd/cli/jd-nav/jd-nav.sh
```

## What it defines

Reads `~/.jd/config.json` (override with `$JD_CONFIG`).

- With one system in your config: command is `jd`.
- Two or more systems: one command per system, named by its lowercase sys id, for example `d25` and `p76`.
  - `jd` also exists and is the system marked `"default": true`, or the first one.

## Use

```sh
p76              # cd to the system root
p76 20-29        # cd to an area
p76 22           # cd to a category
p76 11.11        # cd to an ID
p76 W0189        # cd to a work package
p76 tripsy       # search all IDs for a word, cd if a single match
p76 21. tripsy   # search inside category 21 (`21` also works)
p76 20-29 word   # search inside area 20-29
p76 jdex 11.11   # same targets, in the JDex instead of the filesystem
p76 help         # this list
```

## Rules

- Two or more matches are displayed. No action is taken.
- Word search ignores case. More words narrow the match.
- An ID matches at the correct depth only, so a deeper folder also named `11.11` cannot match.
- `11.11` matches `11.11 Title`, not `11.11+ Extension`.
- A JDex ID is a text/Markdown file. You're taken to its folder.

## Missing folders

- An ID can have a JDex entry but no folder. This is normal – you make the folder when you first need it.
- In that case `jd-nav` makes the folder for you, then goes to it. It prints a line to say what it made.
- It takes the folder name from the JDex entry.
- Your config needs a `jdex` path, and the JDex must have one match for the ID.
- The category folder must exist. `jd-nav` does not make areas or categories.
