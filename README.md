# The JD CLI utilities

Tools that help you work at your command-line. They're compatible with bash (3.2+) and zsh and are MIT licensed so you're free to adapt them for other shells.[^pr]

[^pr]: PRs welcome if you do.

This repo documents installation. Usage is documented at [johnnydecimal.com/jdhq/jd-cli](https://johnnydecimal.com/jdhq/jd-cli).

## Requirements

- [Configuration file](https://johnnydecimal.com/jdhq/configuration).
  - This repo contains a template.
- [jq](https://jqlang.github.io/jq/).

## Installation

1. Install `jq` if you do not have it. On macOS: `brew install jq`.[^homebrew]
2. Clone this repo to `~/.jd/cli`:

   ```sh
   git clone https://github.com/johnnydecimal/cli.johnnydecimal.com ~/.jd/cli
   ```

3. If you don't have `~/.jd/config.json` yet, copy the example and edit it for your systems:

   ```sh
   cp ~/.jd/cli/config.example.json ~/.jd/config.json
   ```

4. Add this line to `.zshrc` (or `.bashrc`):

   ```sh
   source ~/.jd/cli/jd.sh
   ```

   It loads the navigation in any shell, and the prompt under zsh only.

5. For the zsh prompt, pick one of the two and add it to `.zshrc`, after the `source` line.

   Your own prompt, with the Johnny.Decimal path in it. `_jd_pwd` needs single quotes or `prompt_subst`:

   ```zsh
   setopt prompt_subst
   PROMPT='%B$(_jd_pwd)%b %# '
   ```

   Or the whole prompt Johnny uses, which is one more source line. It sets
   `PROMPT`, so put it last, after anything else that touches your prompt.
   See [The prompt theme](#the-prompt-theme):

   ```zsh
   source ~/.jd/cli/lib/theme.zsh
   ```

6. Start a new shell.

[^homebrew]: Requires [Homebrew](https://brew.sh).

## The prompt theme

`lib/theme.zsh` is the whole prompt Johnny uses. It is zsh only, and `jd.sh`
does not load it, so you get it only if you source it.

```
┏╸D25:…/11.11 Structure & registrations
┗╸mymac ❯❯
```

- Line one is the Johnny.Decimal path. In front of it, when the last command
  failed, is its exit status.
- Line two is the host name, then the chevrons you type after.
- Sourcing the file is the request, so it sets `PROMPT`, whatever `PROMPT`
  you had. Put the line last, after anything else that touches the prompt.
  A prompt library usually sets one of its own, and the last one to run
  wins.
- To keep a prompt of your own, do not source this file. Use `$(_jd_pwd)` in
  your own `PROMPT` instead, as in step 5 above. You get the Johnny.Decimal
  path without the rest of this.
- Set the chevron colours before the source line:

  ```zsh
  JD_CHEVRON1=yellow
  JD_CHEVRON2=red
  ```

- Git status is not part of it. The prompt calls `gitprompt`, and the theme
  has a do-nothing `gitprompt` so it works without one. Load
  [git-prompt.zsh](https://github.com/woefe/git-prompt.zsh) before the theme
  and the prompt picks up the real one.
- The symbols need a font with box drawing in it. Every current terminal
  font has one.

## Configuration

Everything reads the standard config file at `~/.jd/config.json`.

Override the location with `$JD_CONFIG`.

The config is read once, when your shell starts. New or moved systems need a new shell.

See [johnnydecimal.com/jdhq/configuration](https://johnnydecimal.com/jdhq/configuration) for more info.

## Update

```sh
git -C ~/.jd/cli pull
```

Coming from 1.x, replace your two `source` lines with the single line in
[Installation](#installation). The old `jd-nav` and `jd-prompt` paths still
work, but they print a reminder each time your shell starts, and they will be
deleted at 3.0.0.

## Tests

```sh
test/run.sh
```

It runs the whole suite under bash and zsh, and exits non-zero if anything
failed. It needs `jq` and nothing else. The tests run against fake systems in a
temp folder, never against your own.

See [test/README.md](test/README.md) to add a test.

## Versions

- Versions follow [semantic versioning](https://semver.org).
- The repo has a single version, which all tools share.
- Each release is a git tag, for example `v2.0.0`.
- `jd version` prints the version you have.
- [CHANGELOG.md](CHANGELOG.md) lists what changed in each release.

## Licence

The code in this repository is [MIT](LICENSE), copyright Coruscade Pty Ltd.

The Johnny.Decimal system, its documentation, and the name are separate. See [johnnydecimal.com/licence](https://johnnydecimal.com/licence). Johnny.Decimal is a trademark of Coruscade Pty Ltd.

## AI attribution

- Johnny:
  - Designs the utility, i.e. decides what it does and how it behaves.
- Claude:
  - Writes the code.
  - Writes the text in the repository, e.g. the installation instructions, which Johnny then edits to save you from reading too much Claude 🫠.
