#!/usr/bin/env bash
# PreToolUse guard for git commands. Enforces two CLAUDE.md rules mechanically:
#
#   1. Branch -> PR -> merge. No direct commits or pushes to main.
#   2. One working copy per session. A second session must not move HEAD or
#      stage files in a working copy another session is already holding.
#
# These are hooks rather than instructions because an instruction is advice and
# a hook is a rule. An agent that has been working for an hour and is trying to
# be helpful will occasionally decide that just this once it is fine to commit
# to main. The hook does not have opinions.
#
# Reads the hook payload on stdin, emits a PreToolUse deny decision on violation
# and stays silent otherwise. Fails open: any unexpected state exits 0, because
# a broken guard must not block all work.

set -u

# Every field of the payload is read with jq. Without it `cmd` comes back empty
# and the script exits 0, permitting every git command — "branch protection is
# off" and "the command was fine" become the same silent outcome. Failing open
# is right for a broken guard; failing open *quietly* is not.
#
# It has to be systemMessage rather than stderr: on exit 0 Claude Code surfaces
# stdout in transcript mode only and does not surface stderr at all, so an
# `echo >&2` here would be very nearly the silence it is meant to break.
# claim-working-copy.sh uses the same channel, and printf covers a fixed string
# without the jq we have just established is missing.
command -v jq >/dev/null 2>&1 || {
  printf '%s\n' '{"systemMessage":"guard-git: jq not found — the git guard is DISABLED for this session"}'
  exit 0
}

MAIN_BRANCH="main"
LOCK_STALE_SECONDS=900 # a lock older than this is treated as dead

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // "."')
sid=$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')

[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# Two derived views of each command, because one string cannot serve both jobs.
#
# The old code stripped *all* quoted text globally and used the result for
# everything. That hid `bash -c "git push origin main"` completely — the whole
# command vanished — while `'git' commit` lost its command word. Stripping is
# only needed so a commit message mentioning "main" does not read as a ref, so
# it is now narrowed to exactly the flags that carry prose.
strip_messages() { # $1 -> $1 with -m/-F style arguments blanked
  printf '%s' "$1" | sed -E "s/(-m|--message|-F|--file)([[:space:]]*=?[[:space:]]*)('[^']*'|\"[^\"]*\")/\1\2MSG/g"
}

# Reduce a segment to something the tokeniser can read, without letting prose
# masquerade as a command.
#
# Grouping punctuation is never prose, so `(`, `\`, and backticks always become
# spaces — that is what makes `(git commit)` and `\git commit` visible.
#
# Quotes are the hard part, and the two needs genuinely conflict: looking inside
# them is required to catch `bash -c "git push origin main"`, and NOT looking
# inside them is required so `echo "git commit"` is not read as a git command.
# Resolved by position rather than by content — quotes are flattened only where
# a command word can actually live (after a shell `-c`, or at the very start of
# the segment as in `'git' commit`). Everywhere else quoted text is removed.
#
# This function decides ONLY whether a segment is worth looking at at all (the
# gate below, and the initial whole-command gate). Once a segment passes that
# gate, every subsequent parse of it uses ref_view() instead — see there for
# why deletion cannot be the general-purpose view.
normalise() { # $1 -> gate-worthy form of $1
  local x
  x=$(flatten_punct "$1")
  # Any wrapper that takes a command as a string argument: `bash -c`, and the
  # spellings a one-character edit reaches from it — `bash -lc`, `sh -ec`,
  # `bash --norc -c`, `ksh -c` — plus `eval`, which takes one with no shell name
  # at all. Matching only `-c` exactly made `bash -lc` a bypass while the case
  # table's `bash -c` row implied wrappers were handled as a class.
  if printf '%s' "$x" | grep -Eq "(^|[[:space:]])[^[:space:]]*sh([[:space:]]+--?[^[:space:]]+)*[[:space:]]+-[a-zA-Z]*c([[:space:]]|$)" ||
    printf '%s' "$x" | grep -Eq "(^|[[:space:]])eval([[:space:]]|$)" ||
    printf '%s' "$x" | grep -Eq "^[[:space:]]*['\"]"; then
    flatten_quotes "$x"
  else
    printf '%s' "$x" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g"
  fi
}

# The backslash leads rather than trails: GNU tr warns "an unescaped backslash
# at end of string is not portable" otherwise, on every call, and this file
# runs on every Bash tool invocation in a session.
flatten_punct() { printf '%s' "$1" | tr "\\\\()\`" '    '; }
flatten_quotes() { printf '%s' "$1" | tr "'\"" '  '; }

# The one general-purpose view used for everything past the initial gate:
# tokenising (git_subcmd, segment_target_dir, bare_cd_dir) and ref matching
# (names_main). `normalise` *deletes* quoted text outside a wrapper, and
# deleted text cannot be tokenised, matched, or resolved as a path — which
# used to make every quoted spelling of the protected branch invisible:
#
#     git push origin "main"              -> `git push origin `  -> allowed
#     git checkout 'main' && git commit   -> switch undetected   -> allowed
#
# and, just as badly, made a quoted -C/cd argument invisible to the directory
# resolution below, and made `-C`'s value swallow the actual subcommand
# (`git -C "." commit -m x` -> `git -C  commit -m x` -> git_subcmd reads the
# stray token where "commit" belonged as the subcommand and "commit" itself
# gets consumed as -C's value, so the real subcommand is missed entirely).
#
# Flattening a segment that already passed the gate is safe: the gate already
# confirmed a real, unquoted `git` invocation (or a recognised shell wrapper)
# exists in it, so there is no prose left to protect against by deleting the
# rest of the text.
ref_view() { flatten_quotes "$(flatten_punct "$1")"; }

# Only inspect commands that actually invoke git. Three things this gate has to
# get right, each of which it got wrong at some point:
#
#   <path>/ prefix   `git_subcmd` accepts `*/git`, but this gate once did not,
#                    so `/usr/bin/git commit` exited here and skipped every
#                    rule. Fixing a parser without fixing its gate leaves the
#                    bypass exactly where it was. `[^[:space:];&|]*/` admits a
#                    path while keeping `mygit` out.
#   leading class    `[^[:alnum:]_.-]` rather than a list, so `(git commit)`,
#                    `\git commit` and a backtick prefix are all seen.
#   normalise first  gating on globally quote-stripped text hid `'git' commit`
#                    and the entire body of `bash -c "git push origin main"`.
GIT_PATTERN='(^|[^[:alnum:]_.-])([^[:space:];&|]*/)?git[[:space:]]'
printf '%s' "$(normalise "$cmd")" | grep -Eq "$GIT_PATTERN" || exit 0

# Split into independently-evaluated segments. One Bash call routinely chains
# unrelated commands, and a rule must only see the arguments of the invocation it
# is judging: `git push my-branch && gh pr create --base main` is legitimate, but
# scanning it whole makes the PR target look like the push target.
#
# Split $cmd rather than a pre-stripped copy — a segment has to keep the text
# that says a git invocation is in there at all.
segments=$(printf '%s' "$cmd" | tr '\n' ';' | sed 's/&&/;/g; s/||/;/g; s/|/;/g' | tr ';' '\n')

# Extract the git subcommand from a segment; prints nothing if it is not a git
# invocation.
#
# This is a token walk rather than a regex because the regex it replaced —
# `git([[:space:]]+-[^[:space:]]+)*[[:space:]]+SUBCMD` — required every
# pre-subcommand token to begin with `-`. Global options that take their value
# as a *separate word* broke the chain and skipped every rule in this file:
#
#     git -C . commit -m x          -> `.` does not start with `-`, no match
#     git -c user.name=x commit     -> `user.name=x` likewise
#
# So `git -C . push origin main` was allowed. `--git-dir=.git commit` was
# caught only because the value is attached, which is the tell that the old
# matcher was keying on token *shape* rather than on git's actual grammar.
#
# Takes a ref_view segment (quotes flattened, not deleted) so a quoted -C
# value is a token like any other rather than a hole that swallows the real
# subcommand.
git_subcmd() { # $1 = ref_view segment -> prints the subcommand, or nothing
  local seen_git=0
  set -f # no globbing while word-splitting
  # shellcheck disable=SC2086
  set -- $1
  set +f

  while [ $# -gt 0 ]; do
    if [ "$seen_git" -eq 0 ]; then
      case "$1" in
        git | */git) seen_git=1 ;;
      esac
      shift
      continue
    fi
    # Order matters: attached-value options first, then the options whose value
    # is a separate token, then any other flag, then the subcommand itself.
    case "$1" in
      --*=*) shift ;; # value attached, e.g. --git-dir=.git
      -C | -c | --git-dir | --work-tree | --namespace | --exec-path | --super-prefix | --config-env)
        # Consume the value too, or it gets mistaken for the subcommand. This is
        # the whole bug: `git -C . commit` used to read `.` as the subcommand.
        shift
        [ $# -gt 0 ] && shift
        ;;
      -*) shift ;;
      *)
        printf '%s' "$1"
        return 0
        ;;
    esac
  done
  return 0
}

is_git_subcmd() { # $1 = ref_view segment, $2 = subcommand
  [ "$(git_subcmd "$1")" = "$2" ]
}

# Does this segment move HEAD onto the protected branch? Judged against the
# branch of the directory this specific segment targets (see resolve_dir()
# and the per-segment loop below) — a checkout in one worktree must not be
# read as switching the branch of a command that targets a different one.
switches_to_main() { # $1 = ref_view segment
  case "$(git_subcmd "$1")" in
    checkout | switch) ;;
    *) return 1 ;;
  esac
  # -b/-B create a branch *from* the named ref rather than switching to it.
  printf '%s' "$1" | grep -Eq '(^|[[:space:]])-[bB]([[:space:]]|$)' && return 1
  names_main "$1"
}

# Does this segment name the protected branch as a ref?
#
# The class has to include `/` and `+`: `HEAD:refs/heads/main` is the form git
# prints in its own output, and `+main` is the ordinary force spelling. Both
# push main and neither was matched when this only accepted space and `:`.
#
# Takes a ref_view segment — see ref_view() for why deletion cannot serve here.
names_main() { # $1 = ref_view segment
  printf '%s' "$1" | grep -Eq "(^|[[:space:]:/+])${MAIN_BRANCH}([[:space:]]|$)"
}

# --- TASK-300/301/361: the command's own target directory --------------------
#
# The payload's `cwd` is the one signal this guard has seen be wrong: a
# subagent's PreToolUse payload has reported the *root* checkout's directory
# even when the command itself runs entirely against a worktree, whether via
# a `cd <worktree>` or a `git -C <worktree>` on the mutating invocation. What
# follows resolves, per segment, the directory that segment's own git
# invocation actually targets, and only overrides the cwd-derived branch/lock
# state when that directory turns out to be a real git working copy.
#
# Resolve $2 (possibly relative) against $1, without requiring the path to
# exist — a directory a real `git` invocation would itself fail to reach
# should read as "no override" to the caller, not make this fail.
resolve_dir() { # $1 = base, $2 = maybe-relative dir -> absolute-ish path
  case "$2" in
    /*) printf '%s' "$2" ;;
    *) printf '%s/%s' "$1" "$2" ;;
  esac
}

# A literal `cd <dir>` segment changes what directory every later segment in
# the same command runs from, the way a real shell would — the exact form
# TASK-301 names. Only a bare `cd <dir>` is honoured; `cd -`, a bare `cd` with
# no argument, and anything fancier (`pushd`, `cd -P`) fall back to whatever
# direction is already known rather than guessing at one.
bare_cd_dir() { # $1 = ref_view segment -> the argument to a bare `cd`, or nothing
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f
  [ "${1:-}" = "cd" ] || return 0
  case "${2:-}" in
    '' | -*) return 0 ;;
  esac
  printf '%s' "$2"
}

# Explicit target directory named by *this segment's own* git invocation via
# `-C <dir>` — the strongest signal available, since it names exactly the
# directory that invocation runs against, independent of `cwd`, and it does
# NOT persist to later segments (unlike a bare `cd`): `git -C /a status &&
# git commit` must not let /a leak into the plain `git commit` that follows.
# Mirrors git_subcmd's own option-skipping so a global option before `-C` is
# never misread as the subcommand.
segment_target_dir() { # $1 = ref_view segment -> the -C argument, or nothing
  local seen_git=0
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f

  while [ $# -gt 0 ]; do
    if [ "$seen_git" -eq 0 ]; then
      case "$1" in
        git | */git) seen_git=1 ;;
      esac
      shift
      continue
    fi
    case "$1" in
      --*=*) shift ;;
      -C)
        shift
        [ $# -gt 0 ] && printf '%s' "$1"
        return 0
        ;;
      --git-dir | --work-tree | --namespace | --exec-path | --super-prefix | --config-env | -c)
        shift
        [ $# -gt 0 ] && shift
        ;;
      -*) shift ;;
      *) return 0 ;;
    esac
  done
  return 0
}

# Branch/git-dir as seen from a specific directory, or empty if that
# directory turns out not to be a git working copy at all (a typo'd -C/cd,
# say) — the caller falls back to the base (cwd-derived) state in that case
# rather than trusting nothing.
branch_at() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; } # $1 = dir
gitdir_at() { git -C "$1" rev-parse --absolute-git-dir 2>/dev/null; } # $1 = dir

# The payload's cwd is read via explicit `-C`, never via an actual `cd`, so a
# cwd that isn't even a working copy (a stronger failure than "wrong, but a
# checkout") does not by itself disable every rule below — a command naming
# its own directory via `cd`/`-C` can still be judged correctly. Empty values
# here are not an error: every consumer below already treats "" as "no
# override / not a working copy" and falls back accordingly, and a command
# that touches no real working copy anywhere simply has nothing for Rule 1 or
# Rule 2 to act on, which is the documented fail-open stance.
base_branch=$(branch_at "$cwd")
base_git_dir=$(gitdir_at "$cwd")

now=$(date +%s)

# Per-effective-directory state, keyed by resolved absolute path ("" = the
# payload cwd / no override named by the command). Lazily resolved and
# cached so a command that repeats the same -C/cd target across several
# segments only shells out to git for it once.
#
# Parallel indexed arrays rather than an associative array: macOS ships
# bash 3.2 (pre-4.0) as `/bin/bash`, which `#!/usr/bin/env bash` resolves to
# on an unmodified machine, and 3.2 has no `declare -A`. The number of
# distinct directories any one command names is tiny (base plus, in
# practice, at most one or two overrides), so a linear scan over indexed
# arrays costs nothing that matters here.
dir_keys=()
dir_branches=()
dir_gitdirs=()
dir_holders=()
dir_ages=()

# Prints the index of $1 in dir_keys and returns 0, or returns 1 if absent.
dir_index() { # $1 = key
  local i=0 n=${#dir_keys[@]}
  while [ "$i" -lt "$n" ]; do
    if [ "${dir_keys[$i]}" = "$1" ]; then
      printf '%s' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# Reads the lock at $1 (a git-dir) into the globals holder_out/age_out, the
# same "blank the holder if it's ours or stale" logic Rule 2 has always used.
lock_holder_at() { # $1 = git_dir
  local lock="$1/claude-session.lock" held_at h a
  holder_out=""
  age_out=0
  if [ -f "$lock" ]; then
    h=$(head -n1 "$lock" 2>/dev/null | cut -d' ' -f1)
    held_at=$(head -n1 "$lock" 2>/dev/null | cut -d' ' -f2)
    case "$held_at" in '' | *[!0-9]*) held_at=0 ;; esac
    a=$((now - held_at))
    if [ "$h" = "$sid" ] || [ "$a" -ge "$LOCK_STALE_SECONDS" ]; then
      h=""
    fi
    holder_out="$h"
    age_out="$a"
  fi
}

holder_out=""
age_out=0
[ -n "$base_git_dir" ] && lock_holder_at "$base_git_dir"

# The base/cwd state always lives at index 0 — every other consumer below
# relies on that to fall back to it.
dir_keys+=("")
dir_branches+=("$base_branch")
dir_gitdirs+=("$base_git_dir")
dir_holders+=("$holder_out")
dir_ages+=("$age_out")

# Lazily resolve and cache branch/git-dir/lock state for a directory key ("" is
# the base/cwd state, already seeded above at index 0).
ensure_dir_state() { # $1 = dir key ("" or an absolute-ish path)
  local key="$1" b gd
  dir_index "$key" >/dev/null && return
  gd=$(gitdir_at "$key")
  if [ -z "$gd" ]; then
    # Not a real working copy (a typo'd -C/cd) — fall back to the base state
    # entirely, exactly as an unrecognised directory always has here.
    dir_keys+=("$key")
    dir_branches+=("${dir_branches[0]}")
    dir_gitdirs+=("${dir_gitdirs[0]}")
    dir_holders+=("${dir_holders[0]}")
    dir_ages+=("${dir_ages[0]}")
    return
  fi
  b=$(branch_at "$key")
  lock_holder_at "$gd"
  dir_keys+=("$key")
  dir_branches+=("$b")
  dir_gitdirs+=("$gd")
  dir_holders+=("$holder_out")
  dir_ages+=("$age_out")
}

# `persistent` is the directory a bare `cd` most recently set, carried forward
# across segments the way a real shell would. Relative `cd`/`-C` arguments
# resolve against it (falling back to `cwd` before any `cd` has run) rather
# than against `cwd` unconditionally, so `cd a && cd b` and
# `cd /abs && git -C sub …` compose instead of each resolving independently
# against the same starting point.
persistent=""

while IFS= read -r raw_seg; do
  [ -n "$raw_seg" ] || continue

  stripped=$(strip_messages "$raw_seg")
  seg=$(ref_view "$stripped")

  # Directory tracking runs on *every* segment, regardless of whether it
  # invokes git — `cd` is a shell builtin, not a git command, so a bare `cd`
  # segment (no "git" anywhere in it) must still update `persistent` for
  # whatever segment comes after it. Gating this on the git-mention filter
  # below skipped exactly that case: `cd <dir> && git commit` never updated
  # `persistent` at all, because the `cd` segment alone never mentions git.
  # bare_cd_dir/segment_target_dir are immune to the prose risk that filter
  # guards against — they key off the segment's own *leading* token, not an
  # arbitrary substring, so `echo "cd /elsewhere"` (leading word `echo`)
  # cannot be mistaken for a real `cd`.
  cd_hit=$(bare_cd_dir "$seg")
  [ -n "$cd_hit" ] && persistent=$(resolve_dir "${persistent:-$cwd}" "$cd_hit")
  c_override=$(segment_target_dir "$seg")
  if [ -n "$c_override" ]; then
    seg_dir=$(resolve_dir "${persistent:-$cwd}" "$c_override")
  else
    seg_dir="$persistent"
  fi
  key="$seg_dir" # "" means the base/cwd state

  # Cheap prose filter: does this segment actually invoke git, outside quoted
  # text? Quotes are *deleted* here on purpose, so `echo "git commit"` never
  # reaches the rule evaluation below. Once a segment passes, its invocation
  # is confirmed real, so every later parse of it (already done above, for
  # directory tracking) uses the quote-*preserving* ref_view instead.
  printf '%s' "$(normalise "$stripped")" | grep -Eq "$GIT_PATTERN" || continue

  ensure_dir_state "$key"
  idx=$(dir_index "$key")
  branch="${dir_branches[$idx]}"
  holder="${dir_holders[$idx]}"
  age="${dir_ages[$idx]}"

  # --- Rule 1: no direct commits or pushes to main ---------------------------

  if is_git_subcmd "$seg" push; then
    # Explicit main ref, in any of its spellings: `origin main`, `HEAD:main`,
    # `:main`, `HEAD:refs/heads/main`, `+main`, `+refs/heads/main`.
    if names_main "$seg"; then
      deny "Blocked: pushes to ${MAIN_BRANCH} are not allowed (CLAUDE.md: Branch -> PR -> merge). Push the feature branch and open a PR instead, so CI status is visible before the change lands."
    fi
    # These push every local branch, including main, without naming it.
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])--(all|mirror)([[:space:]]|=|$)'; then
      deny "Blocked: 'git push --all' / '--mirror' pushes ${MAIN_BRANCH} without naming it (CLAUDE.md: Branch -> PR -> merge). Push the feature branch explicitly."
    fi
    # Bare `git push` while sitting on main pushes main.
    if [ "$branch" = "$MAIN_BRANCH" ]; then
      deny "Blocked: HEAD is on ${MAIN_BRANCH}, so this push would land directly on ${MAIN_BRANCH} (CLAUDE.md: Branch -> PR -> merge). Create a branch first."
    fi
  fi

  if [ "$branch" = "$MAIN_BRANCH" ]; then
    for sub in commit merge rebase "cherry-pick" revert; do
      if is_git_subcmd "$seg" "$sub"; then
        deny "Blocked: 'git ${sub}' on ${MAIN_BRANCH} would create commits directly on ${MAIN_BRANCH} (CLAUDE.md: no direct commits to ${MAIN_BRANCH}). Branch first, then open a PR."
      fi
    done
  fi

  # --- Rule 2: one working copy per session ----------------------------------

  if [ -n "$holder" ]; then
    for sub in commit checkout switch reset stash add rm restore merge rebase "cherry-pick" push; do
      if is_git_subcmd "$seg" "$sub"; then
        deny "Blocked: another Claude Code session (${holder}, active ${age}s ago) is already holding this working copy. Two sessions sharing one checkout means one of them commits the other's half-finished edits. Use EnterWorktree for an isolated copy, or wait for that session to finish. To override a session you know is dead: rm '${dir_gitdirs[$idx]}/claude-session.lock'"
      fi
    done
  fi

  # Applies to *later* segments targeting the same directory only. A checkout
  # onto main is itself legal; it is the commit chained after it that must be
  # judged against main.
  if switches_to_main "$seg"; then
    dir_branches[idx]="$MAIN_BRANCH"
  fi
done <<SEGMENTS
$segments
SEGMENTS

# Claim / refresh the lock for every distinct working copy this command
# touched — the base cwd plus any -C/cd override — not just the last one seen.
# A session running a stretch of `git -C <worktree> …` commands must keep its
# own root lock alive too, or a second session can claim the root out from
# under it while the first is still working there. Never steal a live one:
# `holder` is blanked above when the lock is ours or stale, so a non-empty
# holder here means another session is still active, and refreshing in that
# case would hand ownership to whoever ran git most recently — including a
# session that only ran a read-only command, which passes the checks above.
lock_i=0
lock_n=${#dir_keys[@]}
while [ "$lock_i" -lt "$lock_n" ]; do
  gd="${dir_gitdirs[$lock_i]}"
  if [ -n "$gd" ] && [ -z "${dir_holders[$lock_i]}" ]; then
    printf '%s %s\n' "$sid" "$now" >"${gd}/claude-session.lock" 2>/dev/null || true
  fi
  lock_i=$((lock_i + 1))
done

exit 0
