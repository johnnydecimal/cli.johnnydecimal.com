# SPDX-License-Identifier: MIT
# tasks/things.sh - Things 3, on macOS
#
# Things cannot copy a project. Its AppleScript dictionary says so:
# 'Projects can not be copied', error -1717. AppleScript can make a
# project, but a to do it makes inside one lands in the Inbox, and it
# cannot see headings at all.
#
# So this adapter does not copy. It keeps the template project as a
# file, in the JSON that the Things URL scheme reads, and builds a new
# project from that file. The file is written from the template project
# in the Things database, read only. You edit the template in Things.
#
# The file is refreshed before each new work package, so an edit in
# Things is never missed. It is rewritten only when the project has
# changed. 'jd new wp --refresh' refreshes it on its own.
#
# The URL scheme has no way to hand an ID back to a shell, so the new
# project is found by its name, which holds its W number and is unique.
#
# The template file is 'Work package template.things.json', in W0003.
# new.sh sets its path in $_JD_NEW_TASKS_TPL.
#
# Config:
#   workPackages.tasks.source     the ID of the template project in
#                                 Things. Copy it from 'Share > Copy
#                                 Link'. With no source, the file is
#                                 used as it is, and never refreshed.
#
# The template file holds the placeholders that new.sh fills:
# {{NAME}} for the project title, {{NOTES_URL}} and {{TASKS_URL}} in the
# project notes. Tags are not read: Things keeps them in a form the
# database does not spell out.

_jd_things_db() {
  local p
  for p in "$HOME/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac/"*"/Things Database.thingsdatabase/main.sqlite"; do
    if [ -f "$p" ]; then
      printf '%s' "$p"
      return 0
    fi
  done
  return 1
}

# The template file, filled in. Prints JSON.
_jd_things_payload() {
  local text
  text=$(cat "$_JD_NEW_TASKS_TPL") || return 1
  text=$(_jd_new_fill "$text" json)
  printf '%s' "$text" | jq -e . >/dev/null 2>&1 || {
    _jd_nav_err "the template is not JSON once the title is in it: $_JD_NEW_TASKS_TPL"
    return 1
  }
  printf '%s' "$text"
}

# The ID of the project named $1, or nothing.
_jd_things_id() {
  osascript - "$1" <<'EOF' 2>/dev/null
on run argv
  tell application "Things3"
    try
      return id of (first project whose name is (item 1 of argv))
    on error
      return ""
    end try
  end tell
end run
EOF
}

jd_tasks_check() {
  case $(uname -s) in
    Darwin) ;;
    *) _jd_nav_err "the things adapter needs macOS"; return 1 ;;
  esac
  command -v osascript >/dev/null 2>&1 || {
    _jd_nav_err "the things adapter needs osascript"
    return 1
  }
  open -Ra Things3 >/dev/null 2>&1 || {
    _jd_nav_err "Things 3 is not installed"
    return 1
  }
  [ -n "$_JD_NEW_TASKS_TPL" ] || {
    _jd_nav_err "the things adapter needs a W0003 folder in the work package area, to hold its template"
    return 1
  }
  return 0
}

# Refresh the template file from Things, then check that it exists.
#
# A refresh that fails is not an error while an older file exists: jd
# warns, and uses that file. With no file at all, it stops.
jd_tasks_prepare() {
  if [ -n "$_JD_NEW_TASKS_SOURCE" ]; then
    if _jd_things_sync; then
      [ "$_JD_THINGS_CHANGED" = 1 ] && _jd_new_say "tasks   template refreshed from Things"
    elif [ -f "$_JD_NEW_TASKS_TPL" ]; then
      _jd_nav_err "could not refresh the template from Things, so jd uses the file as it is: $_JD_NEW_TASKS_TPL"
      _jd_new_warn tasks_refresh_failed
    fi
  fi
  [ -f "$_JD_NEW_TASKS_TPL" ] || {
    _jd_nav_err "no template project at $_JD_NEW_TASKS_TPL - set workPackages.tasks.source in the config, then run 'jd new wp --refresh'"
    return 1
  }
  return 0
}

# Make the project. $1 its name. Prints its URL.
jd_tasks_create() {
  local data id n
  data=$(_jd_things_payload) || return 1
  data=$(printf '%s' "$data" | jq -sRr @uri)

  # -g leaves the terminal in front. Things still opens.
  open -g "things:///json?data=$data" || {
    _jd_nav_err "Things did not take the new project"
    return 1
  }

  # The URL scheme answers nothing, so wait for the project to appear.
  # Things has to start if it was not running, which is the slow case.
  n=0
  while [ "$n" -lt 60 ]; do
    id=$(_jd_things_id "$1")
    [ -n "$id" ] && break
    sleep 0.5
    n=$((n + 1))
  done
  [ -n "$id" ] || {
    _jd_nav_err "Things did not make a project named '$1' - look in Things before you try again"
    return 1
  }
  printf 'things:///show?id=%s' "$id"
}

# Write the links into the project's notes. $1 the project URL.
jd_tasks_link() {
  local id notes
  id=${1##*id=}
  [ -n "$id" ] || return 1
  notes=$(_jd_things_payload | jq -r '.[0].attributes.notes // ""') || return 1
  osascript - "$id" "$notes" <<'EOF' >/dev/null || return 1
on run argv
  tell application "Things3"
    set notes of project id (item 1 of argv) to (item 2 of argv)
  end tell
end run
EOF
  return 0
}

# Read the template project out of Things. Write the template file if
# it is different, or does not exist. Sets $_JD_THINGS_CHANGED to 1 if
# it wrote the file, and 0 if it did not.
#
# It reads the database, not the app, because AppleScript cannot see
# headings. The file is opened read only and never written to. A
# database that Things changes under the read is not a risk: the read
# either sees the old row or the new one.
#
# Order. Things sorts headings by their own index, and the to dos under
# a heading by theirs. A to do with no heading sits above every heading.
_jd_things_sync() {
  local db rows head items out old
  _JD_THINGS_CHANGED=0
  [ -n "$_JD_NEW_TASKS_SOURCE" ] || {
    _jd_nav_err "a refresh needs workPackages.tasks.source in the config: the ID of the template project in Things"
    return 1
  }
  [ -n "$_JD_NEW_TASKS_TPL" ] || {
    _jd_nav_err "--refresh needs a W0003 folder in the work package area, to hold the template"
    return 1
  }
  command -v sqlite3 >/dev/null 2>&1 || {
    _jd_nav_err "a refresh needs sqlite3"
    return 1
  }
  db=$(_jd_things_db) || {
    _jd_nav_err "no Things database on this machine"
    return 1
  }

  head=$(sqlite3 -json "file:$db?immutable=1" "
    select ifnull(p.notes, '') as notes, ifnull(a.title, '') as area
    from TMTask p left join TMArea a on a.uuid = p.area
    where p.uuid = '$_JD_NEW_TASKS_SOURCE' and p.type = 1;") || return 1
  [ -n "$head" ] && [ "$head" != '[]' ] || {
    _jd_nav_err "Things has no project with the ID $_JD_NEW_TASKS_SOURCE"
    return 1
  }

  rows=$(sqlite3 -json "file:$db?immutable=1" "
    select
      case when t.type = 2 then 'heading' else 'to-do' end as kind,
      t.uuid as uuid,
      t.title as title,
      ifnull(t.notes, '') as notes,
      case when t.type = 2 then t.\"index\"
           else ifnull(h.\"index\", -2000000000) end as gidx,
      case when t.type = 2 then -2000000000 else t.\"index\" end as sidx
    from TMTask t
    left join TMTask h on h.uuid = t.heading
    where (t.project = '$_JD_NEW_TASKS_SOURCE'
           or h.project = '$_JD_NEW_TASKS_SOURCE')
      and t.trashed = 0
      and (t.type = 2 or t.status = 0)
    order by gidx, sidx;") || return 1
  [ -n "$rows" ] || rows='[]'

  items=$(sqlite3 -json "file:$db?immutable=1" "
    select c.task as task, c.title as title
    from TMChecklistItem c
    join TMTask t on t.uuid = c.task
    left join TMTask h on h.uuid = t.heading
    where (t.project = '$_JD_NEW_TASKS_SOURCE'
           or h.project = '$_JD_NEW_TASKS_SOURCE')
      and c.status = 0 and t.trashed = 0
    order by c.\"index\";") || return 1
  [ -n "$items" ] || items='[]'

  out=$(jq -n \
    --argjson head "$head" \
    --argjson rows "$rows" \
    --argjson items "$items" '
    def checklist($uuid):
      [ $items[] | select(.task == $uuid)
        | { type: "checklist-item", attributes: { title: .title } } ];
    [ { type: "project",
        attributes: (
          { title: "{{NAME}}", notes: $head[0].notes }
          + (if $head[0].area == "" then {} else { area: $head[0].area } end)
          + { items: [ $rows[] |
                if .kind == "heading" then
                  { type: "heading", attributes: { title: .title } }
                else
                  { type: "to-do",
                    attributes: (
                      { title: .title }
                      + (if .notes == "" then {} else { notes: .notes } end)
                      + (checklist(.uuid) | if length == 0 then {}
                         else { "checklist-items": . } end)
                    ) }
                end ] }
        ) } ]') || return 1

  # '$(cat)' drops the last newline, and so does '$(jq)', so the two
  # compare equal when the file holds what would be written.
  old=$(cat "$_JD_NEW_TASKS_TPL" 2>/dev/null)
  [ -f "$_JD_NEW_TASKS_TPL" ] && [ "$out" = "$old" ] && return 0
  printf '%s\n' "$out" >"$_JD_NEW_TASKS_TPL" || {
    _jd_nav_err "could not write $_JD_NEW_TASKS_TPL"
    return 1
  }
  _JD_THINGS_CHANGED=1
  case $out in
    *'{{NOTES_URL}}'*) ;;
    *) printf 'jd: the template project has no {{NOTES_URL}} in its notes\n' >&2 ;;
  esac
  return 0
}

# 'jd new wp --refresh': refresh the template file, and say what
# happened.
jd_tasks_refresh() {
  _jd_things_sync || return 1
  if [ "$_JD_THINGS_CHANGED" = 1 ]; then
    printf 'jd: wrote %s\n' "$_JD_NEW_TASKS_TPL" >&2
  else
    printf 'jd: no change, %s already matches Things\n' "$_JD_NEW_TASKS_TPL" >&2
  fi
  return 0
}
