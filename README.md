# The JD CLI utilities

Command-line tools for a Johnny.Decimal system. They operate in bash 3.2 and later, and in zsh. The code is MIT licensed. Adapt it for other shells as necessary.[^pr]

[^pr]: PRs welcome if you do.

This repository documents installation. Usage is documented at [johnnydecimal.com/jdhq/jd-cli](https://johnnydecimal.com/jdhq/jd-cli).

## Requirements

- [Configuration file](https://johnnydecimal.com/jdhq/configuration).
  - This repository contains a template.
- [jq](https://jqlang.github.io/jq/).

## Installation

1. Install `jq` if it is not installed. On macOS: `brew install jq`.[^homebrew]
2. Clone this repository to `~/.jd/cli`:

   ```sh
   git clone https://github.com/johnnydecimal/cli.johnnydecimal.com ~/.jd/cli
   ```

3. If `~/.jd/config.json` does not exist, copy the template and edit it for your systems:

   ```sh
   cp ~/.jd/cli/config.example.json ~/.jd/config.json
   ```

4. Add this line to `.zshrc`, or to `.bashrc`:

   ```sh
   source ~/.jd/cli/jd.sh
   ```

   It loads the navigation in all shells. It loads the prompt in zsh only.

5. For the zsh prompt, add one of these two to `.zshrc`, after the `source` line.

   A prompt of your own, with the Johnny.Decimal path in it. `_jd_pwd` needs single quotes, or `prompt_subst`:

   ```zsh
   setopt prompt_subst
   PROMPT='%B$(_jd_pwd)%b %# '
   ```

   Or Johnny's prompt. It sets `PROMPT`, so put the line after all other lines that set `PROMPT`. Refer to [The prompt theme](#the-prompt-theme):

   ```zsh
   source ~/.jd/cli/lib/theme.zsh
   ```

6. Start a new shell.

[^homebrew]: Requires [Homebrew](https://brew.sh).

## The prompt theme

`lib/theme.zsh` is Johnny's prompt. It is for zsh only. `jd.sh` does not load it.

```
┏╸D25:…/11.11 Structure & registrations
┗╸mymac ❯❯
```

Add this line to `.zshrc`, after all other lines that set `PROMPT`:

```zsh
source ~/.jd/cli/lib/theme.zsh
```

- Chevron colours. The prompt reads these variables at each prompt, so put them before or after the source line:

  ```zsh
  JD_CHEVRON1=yellow
  JD_CHEVRON2=red
  ```

- For git status, load [git-prompt.zsh](https://github.com/woefe/git-prompt.zsh) before the theme. If it is not loaded, the theme's own `gitprompt` function operates and prints nothing.
- The symbols need a font that contains box-drawing characters.

## Configuration

All the tools read the configuration file at `~/.jd/config.json`.

`$JD_CONFIG` overrides its location.

The tools read the configuration once, at shell start. A new system, or a system that has moved, needs a new shell.

Refer to [johnnydecimal.com/jdhq/configuration](https://johnnydecimal.com/jdhq/configuration) for the fields.

## `jd new`

`jd new <ID> <title>` makes a work package: the next free W number, the
project in your task app, the JDex note, and the folder. Run `jd new
--help` for the full list of flags.

- `--json` prints one JSON object on stdout, in place of the usual
  lines. `{ "ok": true, ... }` on success, `{ "ok": false, "code": "...",
  "message": "...", "path": "..." }` on error. stderr still carries the
  human lines.
  `code` is the stable part, and it is never empty. Match on it. The
  `message` is written for a person to read, so it may be reworded.
- `--peek` prints the next free W number and makes nothing.
- A template note can hold a token jd does not fill in, for example
  `{{?SCOPE}}` or `{{?DELIVERABLE What we hand over}}`. jd new leaves
  it in the note as written, and names it, in `toFill` with `--json`
  or on stderr otherwise, so a human or an agent can fill it in after.

## Update

```sh
git -C ~/.jd/cli pull
```

### Migration from 1.x

Replace the two `source` lines with the single line in
[Installation](#installation). v1.x `jd-nav` and `jd-prompt` paths still
operate. They print a reminder at each shell start. They'll be deleted in
a future version.

## Tests

```sh
test/run.sh
```

The suite runs in bash and in zsh. It exits non-zero if a test fails. It
needs `jq`, and nothing else. It runs against fixture systems in a temporary
folder, not against your system.

Refer to [test/README.md](test/README.md) to add a test.

## Versions

- Versions follow [semantic versioning](https://semver.org).
- One version applies to all the tools in the repository.
- Each release has a git tag, for example `v2.0.0`.
- `jd version` prints the installed version.
- [CHANGELOG.md](CHANGELOG.md) lists the changes in each release.

## Licence

The code in this repository is [MIT](LICENSE), copyright Coruscade Pty Ltd.

The Johnny.Decimal system, its documentation, and the name are separate. See [johnnydecimal.com/licence](https://johnnydecimal.com/licence). Johnny.Decimal is a trademark of Coruscade Pty Ltd.

## AI attribution

- Johnny:
  - Designs the utility, i.e. decides what it does and how it behaves.
- Claude:
  - Writes the code.
  - Writes the text in the repository, e.g. the installation instructions, which Johnny then edits to save you from reading too much Claude 🫠.
