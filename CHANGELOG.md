# Changelog

> AI generated.

This repo uses [semantic versioning](https://semver.org). One version covers
every tool in it, because you update by pulling the whole repo.

Run `jd version` to see which version you have.

## 2.5.1 – 2026-09-10

> AI generated. Reviewed by Johnny.

### Changed

- `jd beta on` warns you that beta features are unstable and modify
  your data. You also see the warning in `jd beta --help`, and when you
  run a beta feature with beta off.

## 2.5.0 – 2026-09-10

> AI generated. Reviewed by Johnny.

### Added

- Beta features, and one flag that turns them all on.
  - `jd beta` says whether beta is on. `jd beta on` and `jd beta off`
    turn it on and off.
  - The flag is `"beta": true` at the top level of `~/.jd/config.json`.
    `JD_BETA=1` turns beta on for one shell, and writes nothing.
  - Beta features may change, or go, without notice.
- `jd new 21.41 A title` makes a whole work package with one command.
  It is a beta feature.
  - It takes the next free W number from the JDex and the filesystem.
  - It writes the JDex note from your template note.
  - It makes the folder, and copies your template folder into it.
  - It makes the project in your task app, and writes the links both
    ways. Things is the first task app. Obsidian is the first note app.
  - The `workPackages` block in `~/.jd/config.json` names the templates
    and the apps. `config.example.json` shows the block.
- `jd new -n` says what it would make, and makes nothing.
- `jd new --no-tasks` makes the work package without the task app.
- `jd new --refresh` reads the template project out of Things and writes
  it to the template file.
- `jd new --json` prints one JSON object on stdout, for an agent. Every
  failure has a `code` that does not change.
- `jd new --peek` prints the next free W number, and makes nothing.
- A template note can hold a blank, such as `{{?SCOPE}}` or
  `{{?DELIVERABLE What we hand over}}`. `jd new` leaves the blank in the
  note and names it, so that you or your agent can fill it in.

### Changed

- `new` and `beta` are command words in first position. `jd new` and
  `jd beta` no longer search for a folder with that word in its name. A
  scoped search, such as `jd 21 new`, still does.

## 2.4.1 – 2026-09-10

> AI generated. Reviewed by Johnny.

### Changed

- `jd` finds the work package area by the start of its number. It looks
  for a folder named `W0000...` at the top of the system. It used to
  read the area from the JDex entry's parent folder, and match the whole
  number, so a renamed area stopped it.

  A work package always lives in `W0000-9999`, so there is nothing to
  work out. The linked ID in a name like `W0214~00.00` is not read.

## 2.4.0 – 2026-09-10

> AI generated.

### Added

- A work package that is in the JDex but has no folder gets its folder
  made for it, the same as an ID does. `jd W0189` makes
  `W0189~21.41 Some title` from the JDex entry of that name, then goes
  to it.

  A work package number does not say which area it belongs to, so the
  area comes from the JDex entry's parent folder. If the filesystem has
  no folder for that area, `jd` says so and makes nothing.

## 2.3.0 – 2026-09-10

> AI generated.

### Added

- `jdex` is a command of its own, next to `jd`. It goes to the JDex of
  the system `jd` acts on, which is the default system, or the only one.
  `jdex 11.11` and `jd jdex 11.11` are the same command.

  `jdex` takes every target `jd` takes: an area, a category, an ID, a
  work package, a word search, and a search inside an area or category.
  A system with no `jdex` path in the config gives an error that names
  the system.

  For a system that is not the default, the older form still applies:
  `p76 jdex 11.11`.

### Fixed

- `jd jdex version`, `jd jdex -v` and `jd jdex --version` print the
  version. They used to search the JDex for the word.

## 2.2.2 – 2026-09-09

> AI generated.

### Changed

- The README is written as instructions. No contractions, one name for
  one thing, and a sentence for each fact. The prompt theme section now
  shows the line that loads it, which it referred to but did not print.
  Nothing in the tools changed.

## 2.2.1 – 2026-09-09

> AI generated.

### Changed

- The README's prompt theme section is shorter. Nothing in the tools
  changed. The version moves because a `git pull` is how you get the
  repo, so every push is a release.

## 2.2.0 – 2026-09-09

> AI generated.

### Changed

- `lib/theme.zsh` now sets `PROMPT` whenever you source it. Sourcing the
  file is the request, so it does what you asked and says nothing.

  2.1.0 tried to leave a prompt of your own alone, by comparing `PROMPT`
  against the prompts zsh and its usual hosts set. That cannot work. A
  prompt library sets a `PROMPT` of its own, and the theme read that as
  yours and stood down. `git-prompt.zsh` does it, and so do starship and
  powerlevel10k. The check failed for the people most likely to source
  the file.

  Source the line last, after anything else that touches the prompt. To
  keep a prompt of your own, do not source the file: put `$(_jd_pwd)` in
  your own `PROMPT` and you have the Johnny.Decimal path without the
  rest of it.

  Gone with the check: the one-line message it printed, and the
  `_JD_THEME_PROMPT` variable it left in your shell.

## 2.1.0 – 2026-09-09

> AI generated.

### Added

- `lib/theme.zsh`, the whole prompt Johnny uses, for anyone who does not
  want to write their own. It is zsh only, and `jd.sh` does not load it.
  You get it with one more source line in `.zshrc`, after the `jd.sh` one:

  ```zsh
  source ~/.jd/cli/lib/theme.zsh
  ```

  It sets `PROMPT` only when you have not set one yourself. Any `PROMPT`
  that is not a stock zsh one is yours, so the theme says one line and
  leaves it alone. Git status is not part of it: the prompt calls
  `gitprompt`, and the theme defines a do-nothing one, so
  [git-prompt.zsh](https://github.com/woefe/git-prompt.zsh) is yours to
  add or leave out.

### Changed

- A search that finds more than one thing draws its list as a tree.
  Each match sits under the folder that holds it, and that folder is
  named once however many matches are in it. The area is not shown,
  because the ID number already says which area it is in.

  ```
  jd: 3 matches for 'cli':
    ├─ 21 Products & services
    │  └─ 21.42 CLI tools
    ├─ 33 Customers & clients
    │  └─ 33.11 List of all customers & clients
    └─ W0000-9999 Work packages
       └─ W0213~31.13 Video showing JD CLI changes and setup
  ```

  It was one full path per line, which wrapped. The tree is drawn by
  `awk`, which is POSIX and on every machine the tools run on. Without
  `awk` the list prints the old way.

## 2.0.5 – 2026-09-08

> AI generated.

### Fixed

- `jd` no longer leaves an `idx` variable behind in your shell. The setup
  function assigned it without declaring it local, so it escaped and stayed
  there. It happened on the path a single system with no `sys` takes, which
  is the config shape most people have.
- A bare `jd` no longer dies under `set -u` (bash) or `setopt nounset`
  (zsh). It read `$1` before it had checked there was one, so it failed
  with `1: parameter not set` instead of going to the system root. Any
  `jd` with an argument was unaffected, which is how the fault was found.
  All six unguarded reads are now `${1-}`, including the three error paths
  that run when there is no config.

## 2.0.4 – 2026-09-08

> AI generated.

### Fixed

- Work packages whose name carries a `~` are now found. That is the
  normal form – `W0212~21.35 Some title` – but the direct lookup
  matched only `W0212` or `W0212 *`, and the word search required a
  space after the number. In a real system this meant `jd` could see
  1 of 40 work packages, and `jd W0212` reported no match. The direct
  lookup now also accepts `$id~*` and `$id.md`. Extend-the-ends are
  still excluded: `+` and `)` do not match.

## 2.0.3 – 2026-09-08

> AI generated.

### Fixed

- The zsh prompt (`_jd_pwd`) now shortens the path for a single system
  with no `sys` too. It read config rows with `IFS=$'\t' read`, which
  treats a tab as ordinary IFS whitespace and silently drops a leading
  empty field — so a missing `sys` lost the system's root along with it,
  and `_jd_pwd` fell back to printing the full, unshortened path with no
  error. It now reads each row whole and slices it by hand.

## 2.0.2 – 2026-09-08

> AI generated.

### Fixed

- A single system with no `sys` in its config entry now gets a working `jd`
  command. The docs always said `sys` is only needed for more than one
  system, but the code silently skipped defining `jd` at all when it was
  missing, with no error. `jd` now falls back to the entry's position in
  the config.
- More than one system with an entry missing `sys` now prints an error at
  shell start, instead of silently leaving that system with no command.

## 2.0.1 – 2026-09-08

> AI generated.

### Added

- `jd-nav/jd-nav.sh` and `jd-prompt/jd-prompt.zsh` are back, as shims. Each
  one loads `jd.sh` and prints a line telling you to update your shell
  config. 2.0.0 deleted these paths, so a 1.x user who pulled lost the `jd`
  command, and lost the path from their zsh prompt. Nothing breaks now.
  The shims go at 3.0.0.

## 2.0.0 – 2026-09-07

> AI generated.

### Added

- `LICENSE`, the MIT text the code has always been under.

### Changed

- One source line replaces two. In `.zshrc` or `.bashrc`, replace:

  ```sh
  source ~/.jd/cli/jd-nav/jd-nav.sh
  source ~/.jd/cli/jd-prompt/jd-prompt.zsh
  ```

  with:

  ```sh
  source ~/.jd/cli/jd.sh
  ```

  `jd.sh` loads the navigation in any shell, and the prompt under zsh only.

- The scripts moved to `lib/nav.sh` and `lib/prompt.zsh`. Source `jd.sh`, not
  these.
- Messages and `jd version` say `jd`, not `jd-nav`.
- `jd-nav/README.md` and `jd-prompt/README.md` are gone. This repo documents
  installation. Usage is documented at
  [johnnydecimal.com/jdhq/jd-cli](https://johnnydecimal.com/jdhq/jd-cli).

## 1.1.0 – 2026-09-04

> AI generated.

### Added

- `jd-nav`: an ID that has a JDex entry but no folder now gets its folder
  made for you. `jd-nav` takes the name from the JDex entry, prints a line to
  say what it made, then goes to the new folder. The system needs a `jdex`
  path in the config, and the category folder must exist. Areas and
  categories are never made.
- `jd-nav`: `version`, `--version` and `-v` print the version. They work even
  when the config or `jq` is missing.

### Changed

- Version numbers now follow semver, and both tools share one repo version in
  `_JD_CLI_VERSION`. This replaces `_JD_NAV_VERSION`, which nothing read.

## 1.0.0 – 2026-08-23

> AI generated.

### Added

- `jd-nav`: `cd` around a Johnny.Decimal system by number or word.
- `jd-prompt`: a Johnny.Decimal prompt path for zsh.
