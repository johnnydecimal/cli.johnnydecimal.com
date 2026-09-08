# Changelog

This repo uses [semantic versioning](https://semver.org). One version covers
every tool in it, because you update by pulling the whole repo.

Run `jd version` to see which version you have.

## 2.0.5 – 2026-09-08

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

### Fixed

- Work packages whose name carries a `~` are now found. That is the
  normal form – `W0212~21.35 Some title` – but the direct lookup
  matched only `W0212` or `W0212 *`, and the word search required a
  space after the number. In a real system this meant `jd` could see
  1 of 40 work packages, and `jd W0212` reported no match. The direct
  lookup now also accepts `$id~*` and `$id.md`. Extend-the-ends are
  still excluded: `+` and `)` do not match.

## 2.0.3 – 2026-09-08

### Fixed

- The zsh prompt (`_jd_pwd`) now shortens the path for a single system
  with no `sys` too. It read config rows with `IFS=$'\t' read`, which
  treats a tab as ordinary IFS whitespace and silently drops a leading
  empty field — so a missing `sys` lost the system's root along with it,
  and `_jd_pwd` fell back to printing the full, unshortened path with no
  error. It now reads each row whole and slices it by hand.

## 2.0.2 – 2026-09-08

### Fixed

- A single system with no `sys` in its config entry now gets a working `jd`
  command. The docs always said `sys` is only needed for more than one
  system, but the code silently skipped defining `jd` at all when it was
  missing, with no error. `jd` now falls back to the entry's position in
  the config.
- More than one system with an entry missing `sys` now prints an error at
  shell start, instead of silently leaving that system with no command.

## 2.0.1 – 2026-09-08

### Added

- `jd-nav/jd-nav.sh` and `jd-prompt/jd-prompt.zsh` are back, as shims. Each
  one loads `jd.sh` and prints a line telling you to update your shell
  config. 2.0.0 deleted these paths, so a 1.x user who pulled lost the `jd`
  command, and lost the path from their zsh prompt. Nothing breaks now.
  The shims go at 3.0.0.

## 2.0.0 – 2026-09-07

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

### Added

- `jd-nav`: `cd` around a Johnny.Decimal system by number or word.
- `jd-prompt`: a Johnny.Decimal prompt path for zsh.
