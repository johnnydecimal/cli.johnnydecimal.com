# SPDX-License-Identifier: MIT
# corpus.sh - run every conformance corpus in test/corpus
#
# A corpus is a data file, not shell code. This file finds them and runs
# them. Adding a corpus means adding two files to test/corpus and nothing
# else. See test/README.md, and the header of test/lib/corpus.sh, for the
# format.
#
# There is no corpus yet. The check-in / check-out line grammar will be
# the first one. Until then this file reports a skip, so the seam is
# visible in the output rather than hidden.

[ -n "${JD_T_REPO-}" ] || {
  printf 'test: run the suite with test/run.sh, not this file\n' >&2
  exit 2
}

. "$JD_T_REPO/test/lib/harness.sh"
. "$JD_T_REPO/test/lib/corpus.sh"

_jd_t_dir=$JD_T_REPO/test/corpus
_jd_t_list=$JD_T_TMP/.corpus-list

# find, not a glob: zsh treats a glob that matches nothing as an error.
find "$_jd_t_dir" -maxdepth 1 -name '*.tsv' 2>/dev/null | sort >"$_jd_t_list"

if [ ! -s "$_jd_t_list" ]; then
  _jd_t_skipped 'corpus: nothing in test/corpus yet' 'no .tsv files'
  _jd_t_summary
fi

while IFS= read -r _jd_t_tsv; do
  _jd_t_name=$(basename -- "$_jd_t_tsv")
  _jd_t_name=${_jd_t_name%.tsv}
  _jd_t_parser=$_jd_t_dir/$_jd_t_name.parse.sh
  if [ ! -f "$_jd_t_parser" ]; then
    _jd_t_bad "corpus: $_jd_t_name" \
      "a parser at test/corpus/$_jd_t_name.parse.sh" 'no parser'
    continue
  fi
  . "$_jd_t_parser"
  _jd_corpus_run "$_jd_t_tsv" "$_jd_t_name"
  unset -f _jd_corpus_parse 2>/dev/null || true
done <"$_jd_t_list"

_jd_t_summary
