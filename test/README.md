# Tests

## Run them

```sh
test/run.sh
```

It runs every case file under bash and under zsh, and exits non-zero if
anything failed.

Run one group by name:

```sh
test/run.sh nav
test/run.sh prompt
```

The word is matched against the case filenames.

## What runs where

- The tools must work in bash 3.2, the bash macOS ships, and in zsh. So
  every case file runs once per shell.
- `test/run.sh` is POSIX sh. Everything under `test/lib` and
  `test/cases` runs under bash or zsh, because it sources `jd.sh`.
- Most cases go through the shell hook, which is what a person types.
  `cases/bin.sh` runs `$JD_T_BIN`, the program, which is what a script,
  cron or an agent gets. The program does not cd, so that file reads
  `$JD_T_OUT` and never `$JD_T_PWD`.
- Nothing needs installing. `jq` is the only dependency, the same as the
  tools.
- Environment:
  - `JD_TEST_SHELLS` – the shells to use. Default `/bin/bash zsh`.
  - `JD_TEST_KEEP=1` – keep the temp folder so you can look at it.

## Output

The format is close to TAP.

- `ok N - name` – it passed.
- `not ok N - name` – it failed. The next lines say which file and shell,
  what was expected, and what came back.
- `ok N - name # SKIP reason` – it did not apply here, for example a zsh
  prompt test under bash.
- `ok N - name # TODO known bug: ...` – see [Known bugs](#known-bugs).

The last block totals every case run and prints `PASS` or `FAIL`.

## The files

| Path | What it is |
| --- | --- |
| `run.sh` | The entry point. Finds the shells, makes a temp folder per case, totals the results. |
| `lib/harness.sh` | Counters, assertions, and the helpers that run `jd` and load a config. |
| `lib/fixtures.sh` | The fake systems, and every config shape the tests need. |
| `lib/corpus.sh` | Reads a conformance corpus. See [Conformance corpora](#conformance-corpora). |
| `cases/bin.sh` | `bin/jd`, the program, and the shape of the functions `jd.sh` makes. |
| `cases/config.sh` | Reading the config, and every way it can be wrong. |
| `cases/corpus.sh` | Runs each corpus in `test/corpus`. |
| `cases/known-bugs.sh` | Bugs the tests found, which nothing has fixed yet. |
| `cases/nav-fs.sh` | Navigation in the filesystem. |
| `cases/nav-jdex.sh` | Navigation in the JDex. |
| `cases/nav-make-id.sh` | Making an ID folder from its JDex entry. |
| `cases/move.sh` | `jd move` and `jd undo move`, and the journal they write. |
| `cases/new.sh` | `jd new wp`, and what every `jd new` shares: the noun, help, beta. |
| `cases/new-id.sh` | `jd new id`: the next free ID, and the ID template search. |
| `cases/prompt.sh` | `_jd_pwd`, the zsh prompt path. |
| `cases/setup.sh` | `jd agent-setup`, the prompt for your agent, and the `no config` error that names it. |
| `cases/tree.sh` | The match list, when a search finds more than one thing. |
| `cases/theme.sh` | The whole-prompt theme, `lib/theme.zsh`. |
| `cases/regressions.sh` | One test for every bug in the changelog. |
| `cases/version-usage.sh` | `jd version` and `jd help`. |

## How the fixtures work

- `test/run.sh` makes a temp folder for each case file, in each shell.
  It sets `$JD_T_TMP` to it, and `$HOME` to `$JD_T_TMP/home`.
- A case file calls `_jd_fx_build`. That makes three trees under
  `$JD_T_TMP/fixtures`:
  - `$JD_FX_ROOT` – the D25 test system.
  - `$JD_FX_JDEX` – its JDex, where an ID is a `.md` note, not a folder.
  - `$JD_FX_ROOT2` – the P76 test system, which has no JDex.
- The names hold spaces, an ampersand, and a comma, because real system
  names do.
- The tree carries the awkward cases on purpose. `test/lib/fixtures.sh`
  lists them at the top and says what each one is for.
- Configs are written by `_jd_fx_config_*`, one function per shape. Each
  takes the path to write.
- A case file that changes the tree calls `_jd_fx_reset` when it is done.
  `cases/nav-make-id.sh` and `cases/move.sh` do.

Nothing here reads `~/.jd/config.json` or goes near a real system.
`_jd_t_load` refuses a `$JD_CONFIG` that is not under `$JD_T_TMP`.

## Add a test

1. Pick the case file the test belongs in, or add one to `test/cases`.
   `run.sh` finds it without being told.
2. Start a new case file with the SPDX line, a comment block that says
   what it covers, then:

   ```sh
   . "$JD_T_REPO/test/lib/harness.sh"
   . "$JD_T_REPO/test/lib/fixtures.sh"

   _jd_fx_build
   _jd_fx_config_two "$JD_T_TMP/two.json"
   _jd_t_load "$JD_T_TMP/two.json"
   ```

3. Write the test. `jd` changes directory, so run it through
   `_jd_t_run`, which records where it went and then puts you back:

   ```sh
   _jd_t_run jd 11.11
   _jd_t_status 'id: exit status' 0
   _jd_t_at 'id: 11.11' "$JD_FX_ROOT/10-19 Area one/11 Category eleven/11.11 First ID"
   _jd_t_eq 'id: says nothing on stderr' '' "$JD_T_ERR"
   ```

4. End the file with `_jd_t_summary`. It prints the counts and sets the
   exit status.

### What the harness gives you

| Call | What it does |
| --- | --- |
| `_jd_t_config <config>` | Points `$JD_CONFIG` at a config, and loads nothing. For a case that only runs the program. |
| `_jd_t_load <config>` | The same, and sources `jd.sh` again, so this shell has `jd`. Sets `$JD_T_LOADERR`. |
| `_jd_t_libs` | Sources `lib` into this shell, for a test that drives a lib function directly. |
| `_jd_t_version` | The version, read from `bin/jd`, which is the one place it lives. |
| `_jd_t_run <cmd> [words]` | Runs the command from `$JD_T_TMP`, then returns there. |
| `_jd_t_run_from <dir> <cmd> [words]` | The same, from a directory you name. |
| `_jd_t_eq <name> <expected> <actual>` | They must be the same string. |
| `_jd_t_contains <name> <needle> <text>` | The text must hold the needle. |
| `_jd_t_lacks <name> <needle> <text>` | The text must not hold it. |
| `_jd_t_status <name> <expected>` | The exit status of the last run. |
| `_jd_t_at <name> <dir>` | Where the last run left us. |
| `_jd_t_skipped <name> <reason>` | This test does not apply here. |
| `_jd_t_eq_known <name> <expected> <actual> <note>` | A known bug. See below. |

After a run you also have `$JD_T_STATUS`, `$JD_T_OUT`, `$JD_T_ERR` and
`$JD_T_PWD`.

### Rules for a case file

- No arrays. bash 3.2 has no associative arrays, and array syntax
  differs between the shells.
- No globs. zsh treats a glob that matches nothing as an error. Use
  `find` and read the list.
- Quote every path. The fixture paths hold spaces.
- One name for one thing. A test name says what should be true, not what
  the code does.

## Known bugs

`cases/known-bugs.sh` holds tests for bugs that are real and not yet
fixed. They use `_jd_t_eq_known`, which prints the right answer and the
wrong one but does not turn the suite red. Red is for work that has gone
backwards, and none of these ever worked.

When a bug is fixed its line changes to `this now passes, so promote
it`. Move the test into the case file it belongs in and change the call
to `_jd_t_eq`.

## Conformance corpora

A conformance corpus is one set of input lines plus the parse every
implementation must produce for them. The check-in / check-out line
grammar will have three implementations – a bash regex, an awk program,
and TypeScript in an Obsidian plugin – and one corpus keeps them from
drifting apart.

There is no corpus yet. The seam is built, so adding one needs no new
shell code. Two files go in `test/corpus`:

- `<name>.tsv` – the data.
  - Tab separated. Field 1 is the input line. Fields 2 and after are the
    expected parse, one field per part.
  - Blank lines, and lines that start with `#`, are ignored.
  - A first row whose field 1 is the word `input` is a header and is
    skipped.
  - A row with no fields after the input is a line the parser must
    reject.
- `<name>.parse.sh` – the shell implementation.
  - It defines one function, `_jd_corpus_parse "<input line>"`.
  - It prints the parse as tab separated fields, on one line, and
    returns 0.
  - For a line it rejects it prints nothing and returns non-zero.

`cases/corpus.sh` finds every `.tsv`, sources the matching parser, and
runs the rows. Until a `.tsv` exists it reports one skip, so the seam is
visible in the output.

The other implementations read the same `.tsv` with their own runner.
The data file is the only place the cases live.
