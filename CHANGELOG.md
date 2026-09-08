# Changelog

This repo uses [semantic versioning](https://semver.org). One version covers
every tool in it, because you update by pulling the whole repo.

Run `jd version` to see which version you have.

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
