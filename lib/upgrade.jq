# SPDX-License-Identifier: MIT
# upgrade.jq - the list that 'jd upgrade' prints
# Part of the Johnny.Decimal command line. lib/upgrade.sh runs it with
# jq -f, and passes it these arguments:
#
#   $stage    "system": print las, sbs or null, from $marker and $disk
#             "plan":   print what jd must read from the disk: { needs }
#             "result": print the result object
#   $h        [history]   the history of the system, schema 1
#   $disk     [entries]   the area, category and ID folders of the system
#   $jdex     [entries]   the JDex notes, and the area and category
#                         folders of a nested JDex
#   $marker   [marker]    the version file jd found, or null
#   $checks   [checks]    what lib/upgrade.sh read for "plan": { empty,
#                         note, tree }. {} before that
#   $from     the release that --from names, or ""
#   $jdexKind nested, flat, bear or none
#
# An entry is { kind, num, name, loc }. kind is area, category, id or
# note. loc is a path, or 'bear:' and a Bear note ID.
#
# The history's format is in the site repo, in
# src/data/systemHistory/README.md. A release's changes turn the release
# before into it. This file replays them from the installed release to
# the current one, and compares the result with the disk.
#
# A folder is matched on its number, never on its full name.

# ------------------------------------------------------------- names

# A key that ignores case, punctuation and '&' against 'and'. The 'no
# special characters' packs and a person's small edits still match.
def norm: ascii_downcase | gsub("[^a-z0-9]"; "") | gsub("and"; "");

# The emoji in a name. Every character from U+2190 up, except ■ and
# U+FE0F. An en dash, U+2013, is in some titles, and is below that.
def ekey: explode | map(select(. >= 8592 and . != 9632 and . != 65039)) | implode;

def hasq: contains("■");

# Case, and the space settings, folded the same way for a name and a
# title.
def squash($s):
  ascii_downcase
  | if $s.spaceHandling == "preserve" then gsub(" +"; " ") | sub("^ "; "") | sub(" $"; "")
    else gsub("[ _]"; "") end;

# A name without its number, ■ and emoji, folded.
def core($num; $s): .[($num | length):] | explode | map(select(. < 8592)) | implode | squash($s);
def tcore($s): explode | map(select(. < 8592)) | implode | squash($s);

def camel:
  [splits(" +")]
  | .[0] + ([.[1:][] | if length > 0 then (.[0:1] | ascii_upcase) + .[1:] else . end] | join(""));

def transform($s):
  (if $s.casing == "lower" then ascii_downcase else . end)
  | if $s.spaceHandling == "underscore" then gsub(" "; "_")
    elif $s.spaceHandling == "camelCase" then camel
    else . end;

# The folder name the site creates for an outline entry, with the
# install's settings.
# The same rules as buildDisplayName on the site.
def render($s):
  . as $e
  | ($e.id + " "
     + (if $e.kind == "id" and $s.useHeaderSquare and ($e.header // false) then "■ " else "" end)
     + $e.title
     + (if $e.kind != "area" and $s.useEmoji and ($e.emoji // null) != null then " " + $e.emoji else "" end))
  | transform($s);

# Is the name . the name of outline entry $e in the current release?
def isTarget($e; $num; $s):
  . as $name
  | ($name == ($e | render($s)))
    or ((($name | core($num; $s)) == ($e.title | tcore($s)))
        and (($s.useEmoji | not) or $e.kind == "area" or (($name | ekey) == (($e.emoji // "") | ekey)))
        and (($s.useHeaderSquare | not) or $e.kind != "id" or (($name | hasq) == ($e.header // false))));

# Is the name . the name the install created for outline entry $e? Looser than
# isTarget, because installed names vary the most.
def isInstalled($e; $num; $s):
  . as $name
  | ($name == ($e | render($s)))
    or (($name | core($num; $s)) == ($e.title | tcore($s)))
    or (($name[($num | length):] | norm) == ($e.title | norm));

# Does the name . have the title of $e, whatever its emoji and ■?
def isTitle($e; $num; $s): core($num; $s) == ($e.title | tcore($s));

def has($list; $x): any($list[]; . == $x);

# Is the name . the name the install created for any of the entries $es?
def isAnyInstalled($es; $num; $s): . as $name | any($es[]; . as $x | $name | isInstalled($x; $num; $s));

# Is this entry a note, and not a folder of a nested JDex?
def isNote: (.loc | endswith(".md")) or (.loc | startswith("bear:"));

# The name of a template folder or file, folded. The packs' names carry
# an arrow and an emoji, '↖ Holiday template 🏝️', which the no-emoji
# packs leave off. The arrow is kept, so that '↖ Holiday template' and
# 'Holiday template' differ.
def tkey:
  explode | map(select(. != 65039)) | implode
  | sub(" [^\\u0000-\\u007f]+$"; "")
  | ascii_downcase | gsub("[ _]"; "");

# ----------------------------------------------------------- settings

def inferred:
  [$disk[0][] | select(.kind != "area")] as $ci
  | {
      useEmoji: any($ci[]; (.name | ekey) != ""),
      useHeaderSquare: any($disk[0][]; .name | hasq),
      casing: (if any($disk[0][]; .num as $n | .name[($n | length):] | test("[A-Z]")) then "preserve"
               elif ($disk[0] | length) > 0 then "lower" else "preserve" end),
      spaceHandling: (if any($disk[0][]; .name | test(" ")) then "preserve"
                      elif any($disk[0][]; .name | test("_")) then "underscore"
                      elif ($disk[0] | length) > 0 then "camelCase" else "preserve" end)
    };

# ------------------------------------------------------------ marker

def ymd: "[0-9]{4}-[0-9]{2}-[0-9]{2}";

# '00-09 …/00 …/00.00 JDex …/VERSION.txt' as '00.00/VERSION.txt'.
def shortPath: split("/") | (.[-2] | .[0:5]) + "/" + .[-1];

def parseMarker:
  if . == null then {}
  else
    .file as $f | .text as $x
    | (($x | split("\n")[0] | sub("\\s+$"; ""))) as $line
    | ($f | shortPath) as $short
    | if ($f | test("version\\.json$"; "i")) then
        (try ($x | fromjson) catch {}) as $j
        | {source: $short, system: $j.system, release: $j.release, settings: $j.settings}
      elif ($x | test("Version: *[0-9]")) then
        ($x | capture("Version: *(?<v>[0-9][0-9.]*[0-9])").v) as $v | {source: "\($short): Version: \($v)", system: "sbs", marker: $v}
      elif ($x | test("Downloaded: *" + ymd)) then
        ($x | capture("Downloaded: *(?<d>" + ymd + ")").d) as $d | {source: "\($short): Downloaded: \($d)", date: $d}
      elif ($x | test("Installed: *" + ymd)) then
        ($x | capture("Installed: *(?<d>" + ymd + ")").d) as $d | {source: "\($short): Installed: \($d)", date: $d}
      elif ($x | test("^[0-9]+\\.[0-9]+\\.[0-9]+ " + ymd)) then
        ($x | capture("^(?<v>[0-9]+\\.[0-9]+\\.[0-9]+) (?<d>" + ymd + ")")) as $c
        | {source: "\($short): \($line)", marker: $c.v, date: $c.d}
      elif ($f | test("^[0-9][0-9]-[0-9][0-9][^/]*/11[^/]*/11\\.02")) and ($x | test("^[0-9]+\\.[0-9]+\\.[0-9]+")) then
        ($x | capture("^(?<v>[0-9]+\\.[0-9]+\\.[0-9]+)(\\.[a-z])?(?<s>-no-emoji|-no-special-chars)?")) as $c
        | {source: "\($short): \($line)", system: "las", marker: $c.v, noEmoji: ($c.s == "-no-emoji")}
      else {source: $short} end
  end;

# las or sbs. The version file says, or the title of area 10-19 does.
def systemOf:
  ($marker[0] | parseMarker) as $m
  | if $m.system == "las" or $m.system == "sbs" then $m.system
    else
      ([$disk[0][] | select(.kind == "area" and .num == "10-19") | .name | norm] | first // "") as $a
      | if ($a | contains("lifeadmin")) then "las"
        elif ($a | contains("businessadministration")) then "sbs"
        else null end
    end;

# ----------------------------------------------------------- release

def omap($r): reduce $r.outline[] as $e ({}; .[$e.id] = $e);

# How many of the folders match release $r by number and title, and by
# emoji when the install has emoji.
def score($r; $s):
  omap($r) as $o
  | [$disk[0][] | . as $d | $o[$d.num] as $e | select($e != null)
     | ((if ($d.name | core($d.num; $s)) == ($e.title | tcore($s)) then 1 else 0 end)
        + (if $s.useEmoji and $e.kind != "area" and (($d.name | ekey) == (($e.emoji // "") | ekey)) then 1 else 0 end))]
  | add // 0;

# { release } or { error, candidates }. $m the parsed marker, $s the
# settings.
def findRelease($m; $s):
  $h[0].releases as $rs
  | ([$rs[].release]) as $ids
  | if $from != "" then
      if has($ids; $from) then {release: $from, source: "--from"}
      else {error: "unknown_release", message: "\($from) is not a release of the \($h[0].system | ascii_upcase): \($ids | join(", "))"} end
    elif $m.release != null then
      if has($ids; $m.release) then {release: $m.release, source: $m.source}
      else {error: "unknown_release", message: "\($m.source) names the release \($m.release), which the history does not have"} end
    else
      (if $m.marker != null then [$rs[] | select(has(.markers // []; $m.marker))] else [] end) as $bym
      | (if ($bym | length) > 0 then {c: $bym, source: $m.source}
         elif $m.date != null then
           [$rs[] | select(.release <= $m.date)] as $before
           | if ($before | length) == 0 then {c: [$rs[0]], source: $m.source}
             elif ($before[-1].release == $m.date) and ($before | length) > 1 then {c: $before[-2:], source: $m.source}
             else {c: [$before[-1]], source: $m.source} end
         else {c: $rs, source: "the folder names"} end) as $pick
      | if ($pick.c | length) == 1 then {release: $pick.c[0].release, source: $pick.source}
        else
          [$pick.c[] | {release, score: score(.; $s)}] as $sc
          | ($sc | map(.score) | max) as $best
          | [$sc[] | select(.score == $best) | .release] as $top
          # Releases whose folder names are the same cannot be told
          # apart, and need not be: the earliest one lists every later
          # change, and the disk says which of them the install has.
          | def names($r): [$r.outline[] | [.id, .title,
              (if $s.useEmoji then .emoji else null end),
              (if $s.useHeaderSquare then .header else null end)]] | sort;
            ([$pick.c[] | select(.release as $x | has($top; $x))]) as $tied
          | ($tied | map(names(.)) | unique | length == 1) as $same
          | if ($top | length) == 1 or $same then
              {release: $top[0], source: (if $pick.source == "the folder names" then $pick.source else "\($pick.source) and the folder names" end)}
            else {error: "ambiguous_release", message: "the install fits more than one release: \($top | join(", ")). Name one with --from", candidates: $top} end
        end
    end;

# ------------------------------------------------------------ replay

# Replay every release after the installed one. A token follows each
# entry of the installed outline through the moves: its value is the
# entry's number in the installed release. An entry a release adds has
# the token '+' and its number.
#
# seen[token] is every outline entry the token has had, oldest first: a
# folder or a note with any of those names, or a note with any of those
# descriptions, is the install's.
def replay($installedOutline; $after):
  reduce $after[] as $r (
    {at: (reduce $installedOutline[] as $e ({}; .[$e.id] = $e.id)), removed: [], repurposed: [],
     seen: (reduce $installedOutline[] as $e ({}; .[$e.id] = [$e]))};
    ($r.changes) as $c
    | reduce ($c[] | select(.op == "remove")) as $x (.;
        .removed += [{token: .at[$x.id], id: $x.id}] | .at |= del(.[$x.id]))
    | ([$c[] | select(.op == "move")]) as $mv
    | if ($mv | length) > 0 then
        .at as $old
        | .at = (reduce $mv[] as $m ($old; del(.[$m.from])))
        | reduce $mv[] as $m (.; .at[$m.to] = $old[$m.from])
      else . end
    | reduce ($c[] | select(.op == "repurpose")) as $x (.;
        .repurposed += [{token: .at[$x.id],
          moveTo: (if ($x.contents | type) == "object" then .at[$x.contents.moveTo] else null end)}])
    | reduce ($c[] | select(.op == "add")) as $x (.; .at[$x.id] = "+" + $x.id)
    | omap($r) as $o
    | reduce (.at | to_entries[] | select(.value != null)) as $kv (.;
        .seen[$kv.value] += [$o[$kv.key] // empty]));

# ------------------------------------------------------------- sides

def rank: .state as $st | {none: -1, done: 0, todo: 1, ask: 2} | .[$st];

# The worse of two sides. null when neither applies.
def worst($a; $b):
  [$a, $b] | map(select(. != null and .state != "none"))
  | if length == 0 then null else max_by(rank) end;

def entriesAt($map; $num): $map[$num] // [];

# The state of each side, for the item.
def sides($fs; $ns):
  def st: if . == null or .state == "none" then null else .state end;
  {folderState: ($fs | st), noteState: ($ns | st)};

# One side, the folder or the note, of a move or a rename. $src the
# entries at the installed number, $dst at the current number.
def changeSide($src; $dst; $es; $t; $n; $f; $s; $own):
  ([$src[] | select(.name | isAnyInstalled($es; $n; $s))] | first) as $si
  | ([$dst[] | select(.name | isTarget($t; $f; $s))] | first) as $dt
  | ([$dst[] | select(.name | isTitle($t; $f; $s))] | first) as $dtt
  | if $n != $f then
      if $si != null then
        if $own then {state: "ask", reason: "own", loc: $dst[0].loc} else {state: "todo", loc: $si.loc} end
      elif $dt != null then {state: "done", loc: $dt.loc}
      elif $dtt != null then {state: "todo", loc: $dtt.loc}
      elif ($src | length) == 0 and ($dst | length) == 0 then {state: "none"}
      else {state: "ask", reason: "renamed", loc: (($src[0] // $dst[0]).loc)} end
    else
      if $dt != null then {state: "done", loc: $dt.loc}
      elif $si != null then {state: "todo", loc: $si.loc}
      elif $dtt != null then {state: "todo", loc: $dtt.loc}
      elif ($src | length) == 0 then {state: "none"}
      else {state: "ask", reason: "renamed", loc: $src[0].loc} end
    end;

# Is every line of a note its description, a heading, a link or blank?
# Then the person has written nothing in it.
def untouched:
  split("\n") | all(.[];
    test("^\\s*$") or test("^\\s*>") or test("^\\s*#") or test("^\\s*\\[[^]]*\\]\\([^)]*\\)\\s*$")
    or test("^\\s*- \\[[^]]*\\]\\([^)]*\\)\\s*$"));

def firstQuote:
  [split("\n")[] | select(test("^\\s*>")) | sub("^\\s*> ?"; "") | sub("\\s+$"; "")] | first;

# ------------------------------------------------------------- items

def isStdZero($e):
  ($e.kind == "id" and ($e.id | test("\\.0[0-9]$")))
  or ($e.kind == "category" and ($e.id | test("^[0-9]0$")));

def items:
  ($h[0].releases) as $rs
  | ($marker[0] | parseMarker) as $m
  | ($m.settings // inferred
     | if $m.noEmoji then .useEmoji = false else . end) as $s
  | findRelease($m; $s) as $found
  | if $found.error then {ok: false, code: $found.error, message: $found.message} + (if $found.candidates then {candidates: $found.candidates} else {} end)
    else
    ([$rs | to_entries[] | select(.value.release == $found.release) | .key] | first) as $i
    | $rs[$i] as $inst
    | $rs[-1] as $cur
    | omap($inst) as $io
    | omap($cur) as $co
    | ($found.release >= "2026-05-11" and $found.release < "2026-09-07") as $window
    | replay($inst.outline; $rs[$i + 1:]) as $rp
    | (reduce ($rp.at | to_entries[] | select(.value != null)) as $kv ({}; .[$kv.value] = $kv.key)) as $final
    | (reduce $disk[0][] as $d ({}; .[$d.num] += [$d])) as $dm
    | (reduce ($jdex[0][] | select(.kind != "note")) as $d ({}; .[$d.num] += [$d])) as $jm
    | [$jdex[0][] | select(.kind == "note")] as $jnotes
    | ($checks[0] // {}) as $ck
    | ([$rp.repurposed[].token]) as $rpTokens
    | (def missing($e): {state: "ask", reason: (if $window and isStdZero($e) then "stdzero" else "missing" end)};
       def combined($a; $b; $e): worst($a; $b) // missing($e);

       # Moves and renames: every installed entry that is still in the
       # current release.
       [ $inst.outline[] as $e
         | $e.id as $n
         | $final[$n] as $f
         | select($f != null and (has($rpTokens; $n) | not))
         | $co[$f] as $t
         | select($t != null)
         | select($n != $f or ($e | render($s)) != ($t | render($s)))
         | (($f != $n) and ($io[$f] == null)) as $vacantNot
         | ($rp.seen[$n] // [$e]) as $es
         | changeSide(entriesAt($dm; $n); entriesAt($dm; $f); $es; $t; $n; $f; $s;
             $vacantNot and (entriesAt($dm; $f) | length) > 0) as $fs
         | (if $jdexKind == "none" then null
            else changeSide(entriesAt($jm; $n); entriesAt($jm; $f); $es; $t; $n; $f; $s;
              $vacantNot and (entriesAt($jm; $f) | length) > 0) end) as $ns
         | {op: (if $n != $f then "move" else "rename" end), id: $f, kind: $t.kind}
           + (if $n != $f then {from: $n} else {} end)
           + {name: ($t | render($s)), folder: $fs.loc, note: $ns.loc} + sides($fs; $ns)
           + (combined($fs; $ns; $t) | {state, reason})
       ]

       # Repurposes: same number, new purpose.
       + [ $rp.repurposed[]
           | select(.token != null and (.token | startswith("+") | not))
           | .token as $n
           | $final[$n] as $f
           | select($f != null)
           | $io[$n] as $e | $co[$f] as $t
           | ($rp.seen[$n] // [$e]) as $es
           | (if .moveTo != null then $final[.moveTo] else null end) as $to
           | ([entriesAt($dm; $n)[] | select(.name | isTarget($t; $f; $s))] | first) as $dt
           | ([entriesAt($dm; $n)[] | select(.name | isAnyInstalled($es; $n; $s))] | first) as $di
           | ([entriesAt($dm; $n)[] | select(.name | isTitle($t; $f; $s))] | first) as $dtt
           | (if $dt != null then {state: "done", loc: $dt.loc}
              elif $dtt != null then {state: "todo", loc: $dtt.loc}
              elif $di != null then
                if $to == null and $ck.empty[$di.loc] == false then {state: "ask", reason: "obsolete", loc: $di.loc}
                else {state: "todo", loc: $di.loc, need: (if $to == null then $di.loc else null end)} end
              elif (entriesAt($dm; $n) | length) > 0 then {state: "ask", reason: "renamed", loc: entriesAt($dm; $n)[0].loc}
              else {state: "none"} end) as $fs
           | (if $jdexKind == "none" then null
              else changeSide(entriesAt($jm; $n); entriesAt($jm; $f); $es; $t; $n; $f; $s; false) end) as $ns
           | {op: "repurpose", id: $f, kind: $t.kind, title: $t.title, name: ($t | render($s)),
              contents: (if $to != null then {moveTo: $to} else "obsolete" end),
              folder: $fs.loc, note: $ns.loc, needEmpty: $fs.need} + sides($fs; $ns)
             + (combined($fs; $ns; $t) | {state, reason})
         ]

       # Removes.
       + [ $rp.removed[]
           | select(.token != null and (.token | startswith("+") | not))
           | .token as $n
           | $io[$n] as $e
           | ($rp.seen[$n] // [$e]) as $es
           | def pick($list): ([$list[] | select(.name | isAnyInstalled($es; $n; $s))] + $list) | first;
             # A folder, in the system or in a nested JDex: delete it only
             # if it is empty. A note: only if the person wrote nothing
             # in it. A name the install did not create: the person
             # uses the number for something of their own.
             def removeSide($x):
               if $x == null then {state: "none"}
               elif ($x.name | isAnyInstalled($es; $n; $s) | not) then {state: "none"}
               elif ($x | isNote) then
                 (if ($ck.note[$x.loc] // "") | untouched then {state: "todo", loc: $x.loc}
                  else {state: "ask", reason: "note", loc: $x.loc} end)
               elif $ck.empty[$x.loc] == false then {state: "ask", reason: "files", loc: $x.loc}
               else {state: "todo", loc: $x.loc} end;
             pick(entriesAt($dm; $n)) as $d
           | pick(entriesAt($jm; $n)) as $j
           | removeSide($d) as $fs
           | removeSide($j) as $ns
           | {op: "remove", id: $n, kind: $e.kind, title: $e.title, folder: $fs.loc, note: $ns.loc,
              needEmpty: ([$d, (if $j != null and ($j | isNote | not) then $j else null end)] | map(select(. != null) | .loc)),
              needNote: (if $j != null and ($j | isNote) then $j.loc else null end)}
             + sides($fs; $ns)
             + (worst($fs; $ns) // {state: "done"} | {state, reason})
         ]

       # Adds.
       + [ $rp.at | to_entries[] | select((.value // "") | startswith("+"))
           | .key as $f
           | $co[$f] as $t
           | select($t != null)
           | ($io[$f] != null) as $vacated
           | def addSide($list):
               ([$list[] | select(.name | isTarget($t; $f; $s))] | first) as $dt
               | ([$list[] | select(.name | isTitle($t; $f; $s))] | first) as $dtt
               | if $dt != null then {state: "done", loc: $dt.loc}
                 elif $dtt != null then {state: "todo", loc: $dtt.loc, retitle: true}
                 elif ($list | length) == 0 or $vacated then {state: "todo"}
                 else {state: "ask", reason: "own", loc: $list[0].loc} end;
             addSide(entriesAt($dm; $f)) as $fs
           | (if $jdexKind == "none" or ($jdexKind != "nested" and $t.kind != "id") then null
              else addSide(entriesAt($jm; $f)) end) as $ns
           # The folder and the note exist, with the title but not the
           # emoji or the ■: a rename, not an add.
           | (def renames($x): $x == null or ($x.retitle // false) or $x.state == "done";
              renames($fs) and renames($ns) and (($fs.retitle // false) or ($ns.retitle // false))) as $retitle
           | {op: (if $retitle then "rename" else "add" end), id: $f, kind: $t.kind, name: ($t | render($s)),
              folder: $fs.loc, note: $ns.loc} + sides($fs; $ns)
             + (worst($fs; $ns) | {state, reason})
         ]

       # Descriptions. The JDex note's first quote is the description.
       + (if $jdexKind == "none" then [] else
         [ $inst.outline[] as $e
           | select($e.kind == "id")
           | $e.id as $n
           | $final[$n] as $f
           | select($f != null)
           | $co[$f] as $t
           | select($t != null and ($t.description // null) != null and ($e.description // null) != ($t.description // null))
           | ($rp.seen[$n] // [$e]) as $es
           | ([entriesAt($jm; $n)[] | select(.name | isAnyInstalled($es; $n; $s))]
              + [entriesAt($jm; $f)[] | select(.name | isTarget($t; $f; $s))]
              + entriesAt($jm; $n) | first) as $j
           | ($ck.note[$j.loc // ""] // null) as $text
           | (if $j == null then missing($t)
              elif $text == null then {state: "todo"}
              elif ($text | firstQuote) == $t.description then {state: "done"}
              elif has([$es[].description // empty]; $text | firstQuote) then {state: "todo"}
              else {state: "ask", reason: "edited"} end) as $ns
           | {op: "description", id: $f, kind: "id", from: ($e.description // null), to: $t.description,
              folder: null, note: $j.loc, needNote: $j.loc, folderState: null, noteState: $ns.state}
             + ($ns | {state, reason})
         ] end)

       # Templates: the difference between the installed set and the
       # current one, top-most paths only.
       + ( [ ($inst.templates // [])[] | .id as $tid
             | (if $io[$tid] != null then $final[$tid] else $tid end) as $fid
             | select($fid != null) | .id = $fid ] as $t0
         | ($cur.templates // []) as $t1
         | def key: "\(.id)\u001f\(.path)";
           ([$t0[] | key]) as $k0 | ([$t1[] | key]) as $k1
         | def topmost($set): [$set[] | . as $x
             | select(any($set[]; . as $y | $y.id == $x.id and ($x.path | startswith($y.path + "/"))) | not)];
           topmost([$t0[] | select(has($k1; key) | not)]) as $rm
         | topmost([$t1[] | select(has($k0; key) | not)]) as $ad
         | def folderFor($tid):
             entriesAt($dm; $tid) as $l
             | (if $co[$tid] != null then [$l[] | select(.name | isTarget($co[$tid]; $tid; $s))] else [] end) + $l
             | first;
           def findIn($tree; $path):
             ($path | split("/") | map(tkey)) as $want
             | [$tree[] | select((.rel | split("/") | map(tkey)) == $want)] | first;
           ( [$rm[] | . as $x | folderFor($x.id) as $d
               | ($ck.tree[$d.loc // ""] // null) as $tree
               | (if $d == null then {state: "done"}
                  elif $tree == null then {state: "todo"}
                  else findIn($tree; $x.path) as $hit
                    | if $hit == null then {state: "done"}
                      elif $hit.type == "f" then {state: "ask", reason: "file"}
                      elif any($tree[]; .type == "f" and (.rel | startswith($hit.rel + "/"))) then {state: "ask", reason: "files"}
                      else {state: "todo"} end end) as $st
               | {op: "removeTemplate", id: $x.id, path: $x.path, type: $x.type, folder: $d.loc, note: null, needTree: $d.loc,
                  folderState: $st.state, noteState: null}
                 + ($st | {state, reason})]
           + [$ad[] | . as $x | folderFor($x.id) as $d
               | ($ck.tree[$d.loc // ""] // null) as $tree
               | (if $d == null then
                    (if ($rp.at[$x.id] // "") | startswith("+") then {state: "todo"}
                     else {state: "ask", reason: "missing"} end)
                  elif $tree == null then {state: "todo"}
                  elif findIn($tree; $x.path) != null then {state: "done"}
                  else {state: "todo"} end) as $st
               | {op: "addTemplate", id: $x.id, path: $x.path, type: $x.type, folder: $d.loc, note: null, needTree: $d.loc,
                  folderState: $st.state, noteState: null}
                 + ($st | {state, reason})] ) )

       # JDex-only notes.
       + (if $jdexKind == "none" then [] else
           ([($inst.notes // [])[].id]) as $n0 | ([($cur.notes // [])[].id]) as $n1
           | def noteFor($id): [$jnotes[] | select(.name == $id or (.name | startswith($id + " ")))] | first;
             [ ($inst.notes // [])[] | select(has($n1; .id) | not) | . as $x | noteFor($x.id) as $j
               | {op: "removeNote", id: $x.id, title: $x.title, folder: null, note: $j.loc}
                 + (if $j == null then {state: "done"} else {state: "ask", reason: "removeNote"} end) ]
           + [ ($cur.notes // [])[] | select(has($n0; .id) | not) | . as $x | noteFor($x.id) as $j
               | {op: "addNote", id: $x.id, title: $x.title, folder: null, note: $j.loc}
                 + (if $j == null then {state: "todo"} else {state: "done"} end) ]
         end)

       # Two folders with one number.
       + [ $dm | to_entries[] | select((.value | length) > 1)
           | select($co[.key] != null or $io[.key] != null)
           | {op: "duplicate", id: .key, kind: .value[0].kind, folders: [.value[].loc], folder: .value[0].loc,
              note: null, state: "ask", reason: "duplicate"} ]
      ) as $items
    | {ok: true, system: $h[0].system,
       release: {installed: $found.release, current: $cur.release, source: $found.source},
       settings: $s, items: $items}
    end;

def order: .op as $op | {remove: 0, move: 1, repurpose: 2, rename: 3, add: 4, description: 5,
             removeTemplate: 6, addTemplate: 7, removeNote: 8, addNote: 9, duplicate: 10} | .[$op];

def reasons: {
  files: "the folder contains files",
  file: "the template file may contain your changes",
  renamed: "the name differs from the name the install created",
  own: "another folder or note already has this number",
  edited: "the description is not the one the install wrote",
  missing: "the install has no folder or note for it",
  stdzero: "the install has no folder or note for it. Downloads from 2026-05-11 to 2026-09-07 left out the standard zeros by default",
  note: "the note contains more than its description",
  obsolete: "the old contents are obsolete, and the folder contains files",
  removeNote: "the note may contain your text",
  duplicate: "more than one folder has this number"
};

def plan:
  items as $r
  | if $r.ok then
      {ok: true, needs: {
        empty: ([$r.items[] | .needEmpty // empty | if type == "array" then .[] else . end] | unique),
        note: ([$r.items[] | .needNote // empty] | unique),
        tree: ([$r.items[] | .needTree // empty] | unique)}}
    else $r end;

def result:
  items as $r
  | if $r.ok then
      $r | .items |= (map(del(.needEmpty, .needNote, .needTree)
                         | if .reason == null then del(.reason) else .reason as $k | .reason = (reasons | .[$k]) end)
                      | sort_by(order, .id))
    else $r end;

if $stage == "system" then systemOf
elif $stage == "plan" then plan
else result end
