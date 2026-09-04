# Changelog

This repo uses [semantic versioning](https://semver.org). One version covers
every tool in it, because you update by pulling the whole repo.

Run `jd version` to see which version you have.

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
