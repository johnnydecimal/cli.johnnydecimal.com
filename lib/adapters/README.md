# Adapters

`jd new wp` makes a work package in more than one place: a note in the
JDex, a folder in the filesystem, and a project in a task app. The
folder and the note are the same on every machine. The apps are not.

An adapter is one file that holds everything one app needs to know.
`lib/new.sh` never names an app. It calls the functions below, and each
adapter answers for its own app.

There are two kinds.

- `tasks/` – the task app, which holds the project.
- `notes/` – the note app, which the link in the task app points back
  to.

Each kind has a `none.sh`, which does nothing and is the default.

## Choosing one

The system's entry in `~/.jd/config.json` names the adapter, and holds
whatever that adapter needs:

```json
"workPackages": {
  "notes": { "adapter": "obsidian", "vault": "D25 JDex" },
  "tasks": { "adapter": "things", "source": "B3W2orf9oNBi3gmttjPT4Y" }
}
```

The config does not name the templates. They are in the `W0003` folder
in the filesystem. A tasks adapter's template file is named for the
adapter: `Work package template.things.json`.

`"adapter": "things"` loads `tasks/things.sh`. A name with no file is an
error that names the folder.

## What a tasks adapter defines

| Function | What it does |
| --- | --- |
| `jd_tasks_check` | Return 0 if the app can be used on this machine. Print why not, and return 1, if it cannot. |
| `jd_tasks_prepare` | Get ready to make the project, for example refresh the template file. Return 1 to stop. It runs in the same shell as `jd new`, not in a subshell, so it can call `_jd_new_warn`. |
| `jd_tasks_create` | Make the project. `$1` is its name. Print its URL on stdout. |
| `jd_tasks_link` | Write the links into the project. `$1` is the URL that `jd_tasks_create` printed. |
| `jd_tasks_refresh` | Read the template project out of the app and write it to the template file. Only `jd new wp --refresh` calls it. |

## What a notes adapter defines

| Function | What it does |
| --- | --- |
| `jd_notes_check` | Return 0 if the app can be used. Print why not, and return 1, if it cannot. |
| `jd_notes_url` | Print the link to this work package's note. |

## What an adapter can read

`lib/new.sh` sets these before it calls an adapter. An adapter reads
them. It does not set them, except for a default of its own.

| Variable | Holds |
| --- | --- |
| `_JD_NEW_NUM` | `W0216` |
| `_JD_NEW_ID` | `21.41`, the ID the work package is linked to |
| `_JD_NEW_TITLE` | the title |
| `_JD_NEW_NAME` | `W0216~21.41 The title` |
| `_JD_NEW_NOTES_URL` | the note app's link. Empty until `jd_notes_url` has run |
| `_JD_NEW_TASKS_URL` | the task app's link. Empty until `jd_tasks_create` has run |
| `_JD_NEW_JDEX` | the JDex folder |
| `_JD_NEW_TASKS_TPL` | the template file, `W0003/Work package template.<adapter>.json`, as a full path. Empty if there is no `W0003` folder |
| `_JD_NEW_TASKS_SOURCE` | the template project's ID in the app, from the config |
| `_JD_NEW_NOTES_VAULT` | the vault name, from the config |

These helpers are there too.

| Function | What it does |
| --- | --- |
| `_jd_new_fill` | Put the values into a template. `$1` the text, `$2` `json` to escape them for a JSON file |
| `_jd_new_uri` | URL-encode `$1` |
| `_jd_new_jstr` | Escape `$1` for the inside of a JSON string |
| `_jd_new_say` | Print a line about what was made, on stderr |
| `_jd_new_warn` | Add a warning code to `--json`'s `warnings`. `$1` the code |
| `_jd_nav_err` | Print `jd: ...` on stderr and return 1 |

## Order

`jd new wp` runs the steps in this order, and the order matters. The task
app is the only step that talks to another program, so it goes first.
Nothing is written to disk until it has worked.

1. `jd_notes_check`, `jd_tasks_check`.
2. `jd_notes_url`. `{{NOTES_URL}}` is now known.
3. `jd_tasks_prepare`, then `jd_tasks_create`. `{{TASKS_URL}}` is now known.
4. The JDex note is written, with both links in it.
5. The folder is made.
6. `jd_tasks_link` writes both links into the task app.

## Writing one

Copy `none.sh` and fill in the functions. Two rules.

- Print nothing on stdout but the value the function is asked for.
  `jd new` reads stdout.
- Say what is wrong on stderr, with `_jd_nav_err`, and return 1. Do not
  make the user read an error from the app itself.
