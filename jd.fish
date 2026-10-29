# SPDX-License-Identifier: MIT
# jd.fish - the shell hook for the Johnny.Decimal command line, in fish
#
# Source this file from config.fish:
#   source ~/.local/share/johnnydecimal/cli/jd.fish
#
# The tool itself is bin/jd, a program. Anything can run it: a script,
# cron, an agent, another program. This file does only what a separate
# process cannot do for you: change the directory of the shell you are
# typing in. There is no fish port of the zsh prompt (lib/theme.zsh);
# jd.sh does not load it outside zsh either.
#
# It defines jd, jdex, and one command per system in your config, named
# by its lowercase sys id: d25, p76. Each one runs bin/jd and changes to
# the folder that the program prints. This file also adds bin to $PATH,
# so that a script started from this shell finds jd too.
#
# A fish port of jd.sh - see jd.sh for the rest of the reasoning. PRs
# welcome for anything this port lacks, per the README.
#
# Requires jq.

set -l _jd_hook_self (status filename)
set -g _jd_hook_dir (path resolve (path dirname -- $_jd_hook_self))
set -g _jd_hook_bin $_jd_hook_dir/bin/jd

# bin on $PATH, so that a subprocess of this shell can run jd by name.
# Inside the shell the functions below take precedence, as functions do.
if not contains -- $_jd_hook_dir/bin $PATH
    set -gx PATH $_jd_hook_dir/bin $PATH
end

# Define one command. $argv[1] the name, the rest are words the program
# always receives before the user's own.
#
# Fish functions do not close over the caller's variables, so the parts
# that must persist after this call - the program's path, the fixed
# words - are written into the function's source as literal text via
# eval, the same method the old jd-nav.fish used. The body itself is
# self-contained: it names the program by its path, contains the cd
# inline, and calls no other function. So the function still works
# after an agent copies it.
#
# Status 3 from the program means a move, and its stdout is the folder
# to cd to. Any other status is the program's own, and its
# stdout, if there is any, is the answer. stderr is never captured, so
# match lists and errors stream while the command runs.
function _jd_hook_def
    set -l name $argv[1]
    set -l extra
    for e in $argv[2..-1]
        set -a extra (string escape -- $e)
    end
    eval "function $name
        set -l jd_out (env JD_HOOK=1 '$_jd_hook_bin' $extra \$argv)
        set -l jd_status \$status
        if test \"\$jd_status\" = 3
            cd -- \$jd_out
            and pwd
            return
        end
        test -n \"\$jd_out\"; and printf '%s\\n' \$jd_out
        return \$jd_status
    end"
end

# One command per system, read from the config now, because a shell
# cannot be given a new function name later. More than one system means
# every entry requires a sys, so a missing one is an error, not a skip.
#
# With no config, no jq, or no systems there is nothing to name, and
# nothing is printed: jd and jdex are still defined, and the program
# prints the error when you call one.
#
# The program determines where the config is: $JD_CONFIG, then the XDG
# place, then ~/.jd for now. 'jd paths config' prints the one it reads
# and nothing else, so this file contains no copy of that rule.
set -l _jd_hook_cfg ($_jd_hook_bin paths config 2>/dev/null)
set -l _jd_hook_n 0
if test -f "$_jd_hook_cfg"; and command -q jq
    set _jd_hook_n (jq -r '.systems | length' "$_jd_hook_cfg" 2>/dev/null)
    string match -qr '^[0-9]+$' -- "$_jd_hook_n"; or set _jd_hook_n 0
end

if test "$_jd_hook_n" -gt 1
    for _jd_hook_sys in (jq -r '.systems[].sys' "$_jd_hook_cfg")
        if test -z "$_jd_hook_sys"; or test "$_jd_hook_sys" = null
            printf 'jd: a system in %s has no %s - every entry requires one when there is more than one system\n' \
                "$_jd_hook_cfg" "'sys'" >&2
            continue
        end
        set -l _jd_hook_fn (string lower -- $_jd_hook_sys)
        if string match -qr '[^a-z0-9_]' -- $_jd_hook_fn; or string match -qr '^[0-9]' -- $_jd_hook_fn
            printf "jd: cannot define a function for sys id '%s'\n" "$_jd_hook_sys" >&2
            continue
        end
        _jd_hook_def $_jd_hook_fn --system $_jd_hook_sys
    end
end

# jd is the default system, or the only one. jdex is the same system, in
# its JDex. Neither names a system: the program resolves the default
# each time it runs, so a config you edit takes effect at once.
#
# Both are defined after the loop above, so a system whose sys id is
# 'jd' or 'jdex' does not replace the root command.
_jd_hook_def jd
_jd_hook_def jdex jdex

set -e _jd_hook_dir
set -e _jd_hook_bin
functions -e _jd_hook_def
