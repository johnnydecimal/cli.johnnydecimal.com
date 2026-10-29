# Adapters

`jd new wp` creates a work package in more than one place: a note in
the JDex, a folder in the filesystem, and a project in a task app. The
folder and the note are the same on every machine. The apps are not.

An adapter is one file that contains all the code for one app.
`lib/new.sh` never names an app. It calls the functions below, and each
adapter implements them for its own app.

There are two kinds.

- `tasks/` – the task app, which stores the project.
- `notes/` – the note app, which the link in the task app points back
  to.

Each kind has a `none.sh`, which does nothing and is the default.

## Choosing one

The system's entry in the config file names the adapter, and contains
the settings that the adapter requires:

```json
"workPackages": {
  "notes": { "adapter": "obsidian", "vault": "D25 JDex" },
  "tasks": { "adapter": "things", "source": "B3W2orf9oNBi3gmttjPT4Y" }
}
```

The config does not name the templates. They are in the `W0003` folder
in the filesystem. A tasks adapter's template file is named for the
adapter: `Work package template.things.json`.

jd has its own copy of a template file, in the `templates` folder of
this repo, with the same name. An adapter copies it into `W0003` when
the user has no template file.

`"adapter": "things"` loads `tasks/things.sh`. A name with no file is an
error that names the folder.

## What a tasks adapter defines

| Function | What it does |
| --- | --- |
| `jd_tasks_check` | Return 0 if the app can be used on this machine. Print why not, and return 1, if it cannot. |
| `jd_tasks_prepare` | Prepare to create the project, for example refresh the template file. Return 1, and `jd new` exits. It runs in the same shell as `jd new`, not in a subshell, so it can call `_jd_new_warn`. |
| `jd_tasks_create` | Create the project. `$1` is its name. Print its URL on stdout. |
| `jd_tasks_link` | Write the links into the project. `$1` is the URL that `jd_tasks_create` printed. |
| `jd_tasks_refresh` | Read the template project from the app and write it to the template file. Only `jd new wp --refresh` calls it. |

## What a notes adapter defines

| Function | What it does |
| --- | --- |
| `jd_notes_check` | Return 0 if the app can be used. Print why not, and return 1, if it cannot. |
| `jd_notes_url` | Print the link to this work package's note. |
| `jd_notes_parent_link` | Print the link to the ID's own JDex note, `_JD_NEW_PARENT_NOTE`. jd calls it only when the JDex has one note for the ID. |

## What an adapter can read

`lib/new.sh` sets these before it calls an adapter. An adapter reads
them. It does not set them, except for a default of its own.

| Variable | Value |
| --- | --- |
| `_JD_NEW_NUM` | `W0216` |
| `_JD_NEW_ID` | `21.41`, the ID the work package is linked to |
| `_JD_NEW_TITLE` | the title |
| `_JD_NEW_NAME` | `W0216~21.41 The title` |
| `_JD_NEW_NOTES_URL` | the note app's link. Empty until `jd_notes_url` has run |
| `_JD_NEW_TASKS_URL` | the task app's link. Empty until `jd_tasks_create` has run |
| `_JD_NEW_PARENT_NOTE` | `21.41 Videos`, the name of the ID's JDex note, with no `.md`. Empty when the JDex has no note for the ID, or more than one |
| `_JD_NEW_PARENT_LINK` | the note app's link to the ID's note. Empty until `jd_notes_parent_link` has run |
| `_JD_NEW_JDEX` | the JDex folder |
| `_JD_NEW_TASKS_TPL` | the template file, `W0003/Work package template.<adapter>.json`, as a full path. The file may not exist. The `W0003` folder exists by the time `jd_tasks_prepare` or `jd_tasks_refresh` runs, because jd creates it if it is missing. It may not exist when `jd_tasks_check` runs |
| `_JD_NEW_TASKS_DEFAULT` | jd's own template file, `templates/Work package template.<adapter>.json` in this repo, as a full path. The file may not exist |
| `_JD_NEW_TASKS_SOURCE` | the template project's ID in the app, from the config |
| `_JD_NEW_NOTES_VAULT` | the vault name, from the config |

These helpers are there too.

| Function | What it does |
| --- | --- |
| `_jd_new_links_json` | Leave out each line that contains `{{NOTES_URL}}`, `{{TASKS_URL}}` or `{{PARENT_LINK}}` when that link is empty. Then leave out each line that has nothing left indented under it. `$1` the template, which is JSON. Call it before `_jd_new_fill` |
| `_jd_new_fill` | Replace the placeholders in a template with their values. `$1` the text, `$2` `json` to escape the values for a JSON file |
| `_jd_new_uri` | URL-encode `$1` |
| `_jd_new_jstr` | Escape `$1` for the inside of a JSON string |
| `_jd_new_say` | Print a line about what was created, on stderr |
| `_jd_new_warn` | Add a warning code to `--json`'s `warnings`. `$1` the code |
| `_jd_nav_err` | Print `jd: ...` on stderr and return 1 |

## Order

`jd new wp` runs the steps in this order, and the order matters. The task
app is the only step that calls another program, so it runs before the
note and the folder. jd writes neither until that step succeeds.

1. `jd_notes_check`, `jd_tasks_check`.
2. `jd_notes_url`, then `jd_notes_parent_link`. `{{NOTES_URL}}` and `{{PARENT_LINK}}` now have values.
3. The work package area, `W0003` and `W0009` are created, if they are missing. jd copies its own template note into a new `W0003`.
4. `jd_tasks_prepare`, then `jd_tasks_create`. `{{TASKS_URL}}` now has a value.
5. The JDex note is written, with both links in it.
6. The folder is created.
7. `jd_tasks_link` writes both links into the task app.

## Writing one

Copy `none.sh` and fill in the functions. Two rules.

- Print nothing on stdout but the value that the function returns.
  `jd new` reads stdout.
- Say what is wrong on stderr, with `_jd_nav_err`, and return 1. The
  user must not have to read an error from the app itself.
