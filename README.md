# cli.johnnydecimal.com

Shell utilities for your [Johnny.Decimal](https://johnnydecimal.com) system.

- [`jd-nav`](jd-nav/): `cd` around your system by number or word. bash 3.2+ and zsh.
- [`jd-prompt`](jd-prompt/): a nicer Johnny.Decimal prompt. zsh.

## Config

Everything reads the standard config file at `~/.jd/config.json`. An example file is provided.

See [jdcm.al/jdhq/configuration](https://jdcm.al/jdhq/configuration)

## Install

1. Install `jq` if you do not have it. On macOS: `brew install jq`.[^homebrew]
2. Clone this repo to `~/.jd/cli`:

   ```sh
   git clone https://github.com/johnnydecimal/cli.johnnydecimal.com ~/.jd/cli
   ```

3. If you do not have `~/.jd/config.json` yet, copy the example and edit it for your systems:

   ```sh
   cp ~/.jd/cli/config.example.json ~/.jd/config.json
   ```

4. Source the utilities you want from `.zshrc` (or `.bashrc`):

   ```sh
   source ~/.jd/cli/jd-nav/jd-nav.sh
   source ~/.jd/cli/jd-prompt/jd-prompt.zsh
   ```

5. Start a new shell.

[^homebrew]: Requires [Homebrew](https://brew.sh).

## Update

```sh
git -C ~/.jd/cli pull
```

## Versions

- The repo has one version number. Every tool in it shares that number.
- Versions follow [semantic versioning](https://semver.org).
- Each release is a git tag, for example `v1.1.0`.
- `jd version` prints the version you have.
- [CHANGELOG.md](CHANGELOG.md) lists what changed in each release.

## The config file

- `version`: the config format version. Currently `1`.
- `systems`: one entry per system. See [multiple systems](https://johnnydecimal.com/documentation/multiple-systems-overview).

For each system:

- `sys`: the [system identifier](https://johnnydecimal.com/documentation/acid-notation#sysacid).
- `title`: a name for the system.
- `root`: the filesystem root – the folder that holds your areas.
- `jdex`: the root of your JDex, if it is on your filesystem (e.g. an Obsidian vault). Optional.[^obsidian]
- `default: true`: the system a tool acts on when you do not name one. Optional. Without it, the first system is the default.

[^obsidian]: Noting that your Obsidian vault should live at `00.00` in your Johnny.Decimal system. That makes the path long so I simplified the example code. See [blog/0182](https://johnnydecimal.com/blog/0182-jdex-data-and-storage) for a deep-dive. If your JDex isn't filesystem-accessible, e.g. Apple Notes or Bear, omit this value.

## AI attribution

Concept and words by Johnny. Code by Claude.
