# The JD CLI utilities

> Written by Claude. See [AI attribution](#ai-attribution).

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

3. If `~/.jd/config.json` does not exist, make it. Either way works.

   Let your agent write it. This prints a prompt. Paste it into whatever agent you use, and it finds your systems and writes the file:

   ```sh
   ~/.jd/cli/bin/jd agent-setup
   ```

   On macOS, `~/.jd/cli/bin/jd agent-setup | pbcopy` puts the prompt on the clipboard.

   Or copy the template and edit it for your systems:

   ```sh
   cp ~/.jd/cli/config.example.json ~/.jd/config.json
   ```

4. Add this line to `.zshrc`, or to `.bashrc`:

   ```sh
   source ~/.jd/cli/jd.sh
   ```

   It defines `jd`, `jdex`, and one command per system in your configuration. Each one runs the program and moves your shell to where the program says. In zsh it also loads the prompt.

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

## Running jd from a script or an agent

The tool is a program, `~/.jd/cli/bin/jd`. Nothing has to be sourced to run it, so a script, cron, or an agent's shell can use it.

```sh
~/.jd/cli/bin/jd 11.11             # the folder for ID 11.11
~/.jd/cli/bin/jd --system P76 22   # a system other than the default
~/.jd/cli/bin/jd version
```

- A move prints one absolute path on stdout and exits 0, so it reads as an answer: `cd "$(~/.jd/cli/bin/jd 11.11)"`.
- Match lists, reports, and errors go to stderr.
- `--system` is read as the first word and nowhere else, so it never collides with a title or with a flag of `jd new`.
- `jd new` takes `--json`, which prints one JSON object on stdout. Refer to [For agents](#for-agents).

  ```sh
  JD_BETA=1 ~/.jd/cli/bin/jd new id 21 A title --json
  ```

- `jd move` and `jd undo move` take `--json` too. Refer to [`jd move`](#jd-move).
- `source ~/.jd/cli/jd.sh` also puts `~/.jd/cli/bin` on `$PATH`, so a program started from your shell can run `jd` by name.

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

The program reads the configuration each time it runs, so a system that has moved takes effect at once.

Two things are read at shell start, and need a new shell: the list of per-system commands, because a shell cannot be given a new command name later, and the zsh prompt.

Refer to [johnnydecimal.com/jdhq/configuration](https://johnnydecimal.com/jdhq/configuration) for the fields.

## `jd new`

`jd new` makes a new thing. The word after `new` says what to make. It is required.

The title needs no quotes. It is every word after the category or ID, up to the first word that starts with `--`. A `-` anywhere else is part of the title, for example `SBS video - 14.20 Syncthing` or `Cut costs -20%`. Flags can go before the noun, after it, or after the title.

```sh
jd new id 21 A title        # the next free ID in category 21
jd new id 21.34 A title     # exactly ID 21.34, if it is not used
jd new wp 21.34 A title     # a work package for ID 21.34
```

- `jd new` is a beta feature. Turn beta on first. See [Beta](#beta).
- Run `jd new id --help` or `jd new wp --help` for the full list of flags.

### `jd new id`

- It makes the JDex note and the folder.
- The next free ID is one more than the highest ID in the category.
  - It counts the IDs in the JDex: the entries directly in the category, and directly in its archive, the .09 ID. For category 21, that is `21` and `21.09`.
  - A folder with no JDex entry is not an ID, so it is not counted. Nor is anything deeper inside an ID.
  - If the filesystem already has a folder with the new ID's number, jd stops, and names the folder.
  - It is never lower than .11.
  - A gap is not filled.

### `jd new wp`

- It makes the next free W number, the project in your task app, the JDex note, and the folder.
- The next free W number is one more than the highest in the JDex: the entries directly in the work package area, and directly in its archive, `W0009`. If the filesystem already has a folder with that number, jd stops, and names the folder.
- The system's `workPackages` block in the config names the adapters. Refer to [lib/adapters/README.md](lib/adapters/README.md).

### Templates

Templates are in the filesystem. jd finds them by number, so the config does not name them.

| Template | Where jd looks | If there is none |
| --- | --- | --- |
| `ID template.md` | The category's .03, then the area's .03, then `00.03`. For category 21: `21.03`, `20.03`, `00.03`. | The note is blank, and jd says so. |
| `Work package template.md` | `W0003` | The note is blank, and jd says so. |
| `Work package template/` | `W0003`. jd copies its contents into the new folder. | The folder is empty. |
| `Work package template.things.json` | `W0003` | jd makes it from Things. |

- The first `ID template.md` that jd finds is the one it uses. To give one category its own template, put a copy in that category's .03.
- If there are two folders with the same templates number, jd stops. It cannot tell which folder to use.
- The note never holds `{{`.
  - `{{ID}}`, `{{TITLE}}` and `{{NAME}}` are filled in. A work package also has `{{W}}`, `{{w}}`, `{{NOTES_URL}}` and `{{TASKS_URL}}`.
  - Anything else in double braces that jd does not know is left out of the note, and jd warns.
- A template note can hold a token, for example `{{?SCOPE}}` or `{{?DELIVERABLE What we hand over}}`.
  - Its flag is its name in lower case, with `-` for `_`: `--scope`, `--deliverable`.
  - Give the value after the title: `jd new wp 21.41 A title --scope "What we do" --deliverable=Video`.
  - A token with no value becomes its brief, `What we hand over`, or nothing.
  - jd names each flag you did not set: in `toFill` with `--json`, or on stderr otherwise.
  - A flag for a token that the template does not have is an error. The error lists the flags the template has.
- The Things template: you edit the template project in Things.
  - Before it makes each work package, jd reads that project out of Things. If the project has changed, jd rewrites the file.
  - `jd new wp --refresh` does the same, and makes nothing.
  - `workPackages.tasks.source` in the config is the project's ID in Things.

### For agents

- `--json` prints one JSON object on stdout, in place of the usual lines. `{ "ok": true, ... }` on success, `{ "ok": false, "code": "...", "message": "...", "path": "..." }` on error. stderr still carries the human lines.
  - `code` is the stable part, and it is never empty. Match on it. The `message` is written for a person to read, so it may be reworded.
  - `warnings` lists the codes for problems that did not stop the command, for example `no_template`.
- To fill in the tokens, first run a dry run with `--json`. `toFill` lists each token with its `brief` and its `flag`. Then run the command again with a value for each flag.
- `--dry-run` says what jd would make, and which templates it would use.

## `jd move`

`jd move` moves a file or a folder into the folder for an ID, and writes one line to a journal. `jd undo move` reads the journal and moves it back.

```sh
jd move ~/Downloads/invoice.pdf 21.34    # into the folder for 21.34
jd move ~/Desktop/Photos W0189           # a folder moves whole
jd undo move                             # move the last thing back
jd undo move ~/D25/.../invoice.pdf       # move that thing back
```

- `jd move` is a beta feature. Turn beta on first. See [Beta](#beta).
- The target is an ID or a W number. It is found the same way `jd 21.34` finds it. An ID that is in the JDex but has no folder gets its folder made.
- It prints the new path on stdout and exits 0. It does not cd.
- It refuses, and moves nothing, when the target folder already holds something with that name. It never renames.
- It refuses an iCloud stub, a `.name.icloud` file that is not downloaded. A Dropbox online-only file is not detected.
- It refuses when the target folder is inside the thing you are moving.
- `--dry-run` says what it would do, and moves nothing.
- Run `jd move --help` or `jd undo move --help` for the full text.

### The journal

Every move is one line in `~/.jd/journal.jsonl`. So is every undo. The file is append only, and jd never edits it.

```json
{"at":"2026-09-12T07:09:53Z","sys":"D25","id":"21.34","kind":"file","from":"/Users/you/Downloads/invoice.pdf","to":"/Users/you/Documents/D25/20-29 Finance/21 Accounts/21.34 Invoices/invoice.pdf","by":"person","host":"mymac.local"}
```

- `by` is `person` when the shell ran it, and `program` when a script or an agent ran the program.
- An undo line has `undoes`, the `at` of the move it undid, and `from` and `to` the other way round.
- The journal is for this machine. The paths in it belong here, so it is not in the system, and it does not sync.
- jd writes nothing into the JDex. An agent that files a mess reads the JSON result and writes the note itself.

### `jd undo move`

- With no path, it undoes the newest move in the system that is not yet undone. `--system` picks the system.
- With a path, it undoes the move that put that path where it is, in whichever system.
- It refuses if the moved thing is no longer where jd put it, code `moved_since`, or if something else is now where it came from, code `source_exists`.
- An undo is never a candidate for undo.

## Beta

Some features are in beta. They may change, or go, without notice. One flag turns all of them on.

```sh
jd beta          # say whether beta is on
jd beta on       # turn it on
jd beta off      # turn it off
```

The flag is `"beta": true` at the top level of `~/.jd/config.json`. `JD_BETA=1` turns beta on for one shell, and writes nothing.

## Update

```sh
git -C ~/.jd/cli pull
```

The v1.x `jd-nav` and `jd-prompt` paths are deleted at 3.0.0. A `.zshrc` that still sources one fails at shell start with "no such file".

Replace both lines with the single line in [Installation](#installation), which has been the documented line since 2.0.0.

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
