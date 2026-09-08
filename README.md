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

5. For the zsh prompt, also add these lines to `.zshrc`, after the `source` line. `_jd_pwd` needs single quotes or `prompt_subst`:

   ```zsh
   setopt prompt_subst
   PROMPT='%B$(_jd_pwd)%b %# '
   ```

6. Start a new shell.

[^homebrew]: Requires [Homebrew](https://brew.sh).

## Configuration

Everything reads the standard config file at `~/.jd/config.json`.

Override the location with `$JD_CONFIG`.

The config is read once, when your shell starts. New or moved systems need a new shell.

See [johnnydecimal.com/jdhq/configuration](https://johnnydecimal.com/jdhq/configuration) for more info.

## Update

```sh
git -C ~/.jd/cli pull
```

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
