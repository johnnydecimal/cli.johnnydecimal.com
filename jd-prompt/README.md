# jd-prompt

A zsh prompt helper for Johnny.Decimal paths. Requires `jq`. zsh only.

## What it does

Defines `_jd_pwd`, a function to use in your prompt in place of `%~`.

- Outside a Johnny.Decimal system it prints the normal path, with `~` for home.
- At a system root it prints `D25:~`.
- Inside a system it anchors at the deepest numbered folder, so a long path becomes short:

  ```
  D25:…/11.11 Structure & registrations
  ```

Reads your systems from `~/.jd/config.json` (override with `$JD_CONFIG`), the same config `jd-nav` uses.

## Install

See the [repo README](../README.md) for the clone and config steps. Then:

1. Add this line to `.zshrc`:

   ```zsh
   source ~/.jd/cli/jd-prompt/jd-prompt.zsh
   ```

2. Use `$(_jd_pwd)` in your `PROMPT`. You need single quotes or `prompt_subst`, for example:

   ```zsh
   setopt prompt_subst
   PROMPT='%B$(_jd_pwd)%b %# '
   ```

3. Start a new shell. New or moved systems in the config need a new shell, or source the file again.
