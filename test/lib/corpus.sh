# SPDX-License-Identifier: MIT
# corpus.sh - run a conformance corpus, which is data, not shell code
#
# A conformance corpus is one set of input lines plus the parse every
# implementation must produce for them. The point is that the same data
# file drives more than one implementation of the same grammar - a bash
# regex here, an awk program, a TypeScript parser in an Obsidian plugin -
# so they cannot drift apart.
#
# The check-in / check-out line grammar is the first user of this. Its
# corpus is not written yet. This file is the seam it drops into: when
# the data file arrives, no new shell code is needed.
#
# The data file
# -------------
# Path:   test/corpus/<name>.tsv
# Format: tab separated, one row per case.
#           field 1     the input line, exactly as it would be written
#           field 2+    the expected parse, one field per part
#         Blank lines and lines that start with '#' are ignored.
#         The first non-comment row may name the fields; if field 1 of
#         that row is the word 'input', the row is treated as a header
#         and skipped.
#
# The parser under test
# ---------------------
# Path:   test/corpus/<name>.parse.sh
# It must define one function:
#           _jd_corpus_parse "<input line>"
#         which prints the parse it got as tab separated fields, on one
#         line, and returns 0. A line it rejects should print nothing and
#         return non-zero; write that in the data file as a row with no
#         expected fields.
#
# Every other implementation reads the same .tsv with its own runner.
# Keep the data file the only place the cases live.

# Read one corpus and check every row. $1 the .tsv, $2 a label for
# messages. The parser must already be sourced.
_jd_corpus_run() {
  local file=$1 label=$2 tab row input want got n=0
  tab=$(printf '\t')
  while IFS= read -r row; do
    case $row in
      '' | '#'*) continue ;;
    esac
    input=${row%%"$tab"*}
    if [ "$n" -eq 0 ] && [ "$input" = input ]; then
      n=1
      continue
    fi
    n=$((n + 1))
    want=${row#*"$tab"}
    [ "$want" = "$row" ] && want=''
    got=$(_jd_corpus_parse "$input" 2>/dev/null) || got=''
    _jd_t_eq "$label: $input" "$want" "$got"
  done <"$file"
}
