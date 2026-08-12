#!/usr/bin/env bash
# Case table for guard-git.sh.
#
# This exists because `docs/ai-development-practices.md` argues that "a hook you
# have not exercised is a hook you are guessing about" — and then shipped 172
# lines of bash whose only tests were five commands run by hand and never
# committed. An automated review subsequently found four bypasses, three of
# which are in this table. Uncommitted tests are not tests.
#
# SCOPE — read this before trusting a green run. These cases pipe a payload
# straight into guard-git.sh. They do not exercise .claude/settings.json, which
# decides whether Claude Code invokes the hook at all. An `if: "Bash(git *)"`
# there once filtered out every path-prefixed invocation, so three rows in this
# table passed while the bypass they assert against was wide open in production.
# A green run here means the script is correct, not that the wiring reaches it.
#
# Usage:  ./scripts/claude-hooks/guard-git.test.sh
# Runs against a scratch repo, so it cannot touch the real working copy.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/guard-git.sh"
REPO=$(mktemp -d)
WT_PARENT="" # set once the TASK-301 worktree cases below create it
WT=""        # the worktree itself, nested one level inside WT_PARENT — see
             # "Relative cd/-C composition" below for why it is nested
PASS=0
FAIL=0

cleanup() { rm -rf "$REPO" "$WT_PARENT"; }
trap cleanup EXIT

# Scratch repo with both a main and a feature branch, plus a "scratch" branch
# that exists only to park a worktree on while shuffling "main"/"feature"
# between $REPO and a second worktree below — git refuses to have the same
# branch checked out in two places at once, so a third slot is needed to move
# either one without the other being in the way.
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name Test
git -C "$REPO" commit -q --allow-empty -m init
git -C "$REPO" branch feature
git -C "$REPO" branch scratch

# The hook stays silent to allow and prints a JSON deny decision to block, so an
# empty response means allow. jq's `//` fallback cannot express that: given empty
# input jq emits nothing, so the fallback never runs. Reading that empty string
# as a verdict is what made 13 passing cases look like failures on the first run
# of this file.
decision() { # $1 = payload -> "allow" | "deny"
  local raw
  raw=$(printf '%s' "$1" | "$HOOK")
  if [ -z "$raw" ]; then
    printf 'allow'
  else
    printf '%s' "$raw" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
  fi
}

# $1 expected: deny | allow
# $2 branch to be on
# $3 description
# $4 command
check() {
  local expected="$1" on_branch="$2" desc="$3" cmd="$4" got payload
  if ! git -C "$REPO" checkout -q "$on_branch" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    printf '  FAIL setup: could not checkout %s in REPO — %s\n' "$on_branch" "$desc"
    return
  fi
  rm -f "$REPO/.git/claude-session.lock"

  payload=$(printf '{"tool_input":{"command":%s},"cwd":%s,"session_id":"test-session"}' \
    "$(printf '%s' "$cmd" | jq -Rs .)" "$(printf '%s' "$REPO" | jq -Rs .)")

  got=$(decision "$payload")

  if [ "$got" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf '  ok   %-8s %s\n' "[$got]" "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL expected %s, got %s — %s\n      cmd: %s\n' "$expected" "$got" "$desc" "$cmd"
  fi
}

echo "Rule 1: no commits or pushes to main"

check deny  main    "plain commit on main"                  "git commit -m x"
check deny  main    "commit with -C (separate-word value)"  "git -C . commit -m x"
check deny  main    "commit with -c k=v"                    "git -c user.name=x commit -m y"
check deny  main    "commit with --git-dir=<attached>"      "git --git-dir=.git commit -m x"
check deny  main    "merge on main"                         "git merge feature"
check deny  main    "rebase on main"                        "git rebase feature"
check deny  main    "commit via absolute path"              "/usr/bin/git commit -m x"
check deny  main    "commit via relative path"              "./git commit -m x"
check deny  main    "push main via absolute path"           "/usr/bin/git push origin main"
check allow main    "a binary merely ending in git"         "mygit commit -m x"
check allow feature "commit on a feature branch"            "git commit -m x"
check allow feature "merge on a feature branch"              "git merge main"

# TASK-300: merging main *into* a feature branch is the ordinary way to
# resolve a conflict before a PR — it lands a commit on the feature branch,
# never on main, so it must key on the checked-out branch, not on "main"
# appearing anywhere in the merged ref.
check allow feature "merge origin/main from a feature branch"       "git merge origin/main"
check deny  main    "merge origin/main with main checked out"       "git merge origin/main"
check allow feature "merge an arbitrary sha from a feature branch"  "git merge 0123456789abcdef0123456789abcdef01234567"

echo
echo "Push refs — every spelling of main"

check deny  feature "push origin main"                      "git push origin main"
check deny  feature "push HEAD:main"                        "git push origin HEAD:main"
check deny  feature "push HEAD:refs/heads/main"             "git push origin HEAD:refs/heads/main"
check deny  feature "push +main (force spelling)"           "git push origin +main"
check deny  feature "push +refs/heads/main"                 "git push origin +refs/heads/main"
check deny  feature "push --all"                            "git push --all"
check deny  feature "push --mirror"                         "git push --mirror"
check deny  feature "push with -C"                          "git -C . push origin main"
# Quoting the ref used to erase it: normalise deletes quoted text, and
# names_main ran on that output, so `"main"` was simply not there to match.
# A whole spelling class the section heading claimed to cover and did not.
check deny  feature "push origin \"main\" (double-quoted)"  "git push origin \"main\""
check deny  feature "push origin 'main' (single-quoted)"    "git push origin 'main'"
check deny  feature "push \"refs/heads/main\""              "git push origin \"refs/heads/main\""
check deny  main    "bare push while on main"               "git push"
check allow feature "push the feature branch"               "git push origin feature"
check allow feature "push -u origin feature"                "git push -u origin feature"

echo
echo "Compound commands"

check deny  feature "checkout main then commit"             "git checkout main && git commit -am x"
check deny  feature "switch main then commit"               "git switch main; git commit -am x"
check deny  feature "checkout main then merge"              "git checkout main && git merge feature"
check allow feature "push branch then open PR against main" "git push origin feature && gh pr create --base main"
check allow feature "checkout -b from main, then commit"    "git checkout -b new main && git commit -m x"
check allow feature "quoted 'main' in a commit message"     "git commit -m \"merge into main branch\""
# The allow side of TASK-015: a well-quoted message mentioning the protected
# branch stays inert. The deny side — a heredoc message with inner quotes, which
# really is denied in a live shell — is deliberately NOT asserted. Payloads reach
# this harness already JSON-encoded, so the shell-level quoting that triggers it
# cannot be reproduced faithfully, and a case bent until it went red would pin
# the bend rather than the behaviour. A real gap in the table, recorded as one.
check allow feature "message quoting a push command"        "git commit -m \"see: git push origin main\""
check deny  main    "cd then commit (settings.json if-gate)"  "cd . && git commit -m x"
check deny  main    "subshell prefix"                       "(git commit -m x)"
check deny  main    "backslash prefix"                      "\\git commit -m x"
check deny  main    "bash -c wrapping a push to main"       "bash -c \"git push origin main\""
check deny  main    "quoted command word"                   "'git' commit -m x"
check deny  feature "checkout \"main\" then commit"         "git checkout \"main\" && git commit -am x"
check deny  feature "switch 'main' then commit"             "git switch 'main'; git commit -am x"
# Wrapper spellings one character away from `bash -c`. Pinning only `bash -c`
# read as "wrappers are handled", which was not true of any of these.
check deny  main    "bash -lc"                              "bash -lc \"git push origin main\""
check deny  main    "sh -ec"                                "sh -ec \"git push origin main\""
check deny  main    "bash --norc -c"                        "bash --norc -c \"git push origin main\""
check deny  main    "ksh -c"                                "ksh -c \"git push origin main\""
check deny  main    "eval, with no shell name at all"       "eval \"git push origin main\""

echo
echo "TASK-361/review: a quoted -C value must not swallow the subcommand"

# `normalise` used to *delete* the quoted "." before either git_subcmd or
# segment_target_dir ever saw it, so `git -C "." commit -m x` read as `git -C
#  commit -m x`: `-C` consumed the "commit" token as its value and both rules
# skipped the segment entirely (a real Rule 1 bypass, not just a missed
# override). ref_view flattens rather than deletes, so the quoted value is a
# token like any other.
check deny  main    "commit with -C (quoted, dot)"           "git -C \".\" commit -m x"
check deny  main    "push main with -C (quoted, dot)"        "git -C \".\" push origin main"

echo
echo "Non-git and read-only pass through"

check allow main    "read-only status on main"              "git status"
check allow main    "read-only log on main"                 "git log --oneline"
check allow main    "git diff on main"                      "git diff HEAD~1"
check allow main    "not a git command at all"              "npm test"
check allow main    "mentions git in prose only"            "echo 'remember to git commit later'"

echo
echo "Rule 2: one working copy per session"

# Session A claims the lock, then B is judged against it.
claim_for() { # $1 = session id
  printf '{"tool_input":{"command":"git add -A"},"cwd":%s,"session_id":"%s"}' \
    "$(printf '%s' "$REPO" | jq -Rs .)" "$1" | "$HOOK" >/dev/null
}

check_as_b() { # $1 expected  $2 desc  $3 cmd
  local expected="$1" desc="$2" cmd="$3" got payload
  git -C "$REPO" checkout -q feature
  rm -f "$REPO/.git/claude-session.lock"
  claim_for "session-A"
  payload=$(printf '{"tool_input":{"command":%s},"cwd":%s,"session_id":"session-B"}' \
    "$(printf '%s' "$cmd" | jq -Rs .)" "$(printf '%s' "$REPO" | jq -Rs .)")
  got=$(decision "$payload")
  if [ "$got" = "$expected" ]; then
    PASS=$((PASS + 1)); printf '  ok   %-8s %s\n' "[$got]" "$desc"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL expected %s, got %s — %s\n' "$expected" "$got" "$desc"
  fi
}

check_as_b deny  "second session: commit is blocked"        "git commit -m x"
check_as_b deny  "second session: checkout is blocked"      "git checkout other"
check_as_b allow "second session: read-only passes"         "git status"

# A live "session-A" lock is left behind in $REPO/.git/claude-session.lock by
# the three cases above and nothing clears it — check_dir() below clears it
# itself for exactly this reason (see the comment there).

echo
echo "TASK-301: a payload whose cwd is a worktree, not the root checkout"

# Like check(), but the payload's `cwd` is $5 rather than always $REPO — the
# case check() cannot express, since it hard-codes cwd=$REPO and derives the
# lock path from it. The lock itself is always keyed off $WT's own git-dir
# (not whatever $5 is), because that is the working copy every one of these
# cases actually touches, on both sides of the fix.
#
# $6, optional: a substring the decision's own reason must contain when
# $1=deny. Without this, a stray lock (session-A's, left by check_as_b above,
# or the fixture's own) can make a `deny` row pass via Rule 2 — "another
# working copy is held" — while the thing actually under test, Rule 1's
# branch check, silently never fires. decision()/check() elsewhere only
# compare allow/deny for the same reason this file's own TASK-503-style
# review found worth calling out.
check_dir() { # $1 expected  $2 setup-fn  $3 desc  $4 cmd  $5 payload cwd  $6 expected reason substring
  local expected="$1" setup="$2" desc="$3" cmd="$4" payload_cwd="$5" expect_reason="${6:-}"
  local got payload gd raw reason
  "$setup"
  gd=$(git -C "$WT" rev-parse --absolute-git-dir 2>/dev/null)
  [ -n "$gd" ] && rm -f "$gd/claude-session.lock"
  # Rule 2's "second session" cases above leave a fresh, non-stale lock on
  # $REPO; several of these cases use cwd=$REPO and must deny via Rule 1, not
  # via a stale Rule 2 lock nobody here claimed.
  rm -f "$REPO/.git/claude-session.lock"

  payload=$(printf '{"tool_input":{"command":%s},"cwd":%s,"session_id":"test-session"}' \
    "$(printf '%s' "$cmd" | jq -Rs .)" "$(printf '%s' "$payload_cwd" | jq -Rs .)")
  raw=$(printf '%s' "$payload" | "$HOOK")
  if [ -z "$raw" ]; then
    got="allow"
    reason=""
  else
    got=$(printf '%s' "$raw" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')
    reason=$(printf '%s' "$raw" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')
  fi

  if [ "$got" != "$expected" ]; then
    FAIL=$((FAIL + 1))
    printf '  FAIL expected %s, got %s — %s\n      cmd: %s\n' "$expected" "$got" "$desc" "$cmd"
    return
  fi
  if [ -n "$expect_reason" ] && ! printf '%s' "$reason" | grep -qF -- "$expect_reason"; then
    FAIL=$((FAIL + 1))
    printf '  FAIL %s — got %s for the right decision but reason did not mention "%s"\n      reason: %s\n      cmd: %s\n' \
      "$desc" "$got" "$expect_reason" "$reason" "$cmd"
    return
  fi
  PASS=$((PASS + 1))
  printf '  ok   %-8s %s\n' "[$got]" "$desc"
}

# WT is nested one level inside WT_PARENT (WT_PARENT/mid/leaf) rather than a
# bare mktemp -d, specifically so the "relative cd/-C composition" cases below
# have two path segments to compose across — a single-level WT could not tell
# "resolved against cwd" apart from "resolved against the directory a prior cd
# actually reached".
WT_PARENT=$(mktemp -d)
WT="$WT_PARENT/mid/leaf"
mkdir -p "$WT_PARENT/mid"
git -C "$REPO" checkout -q main
git -C "$REPO" worktree add -q "$WT" feature

# $REPO on main, $WT on feature — feature is parked on "scratch" first so
# checking $REPO onto main never collides with feature being held elsewhere.
setup_worktree_on_feature() {
  git -C "$WT" checkout -q scratch
  git -C "$REPO" checkout -q main
  git -C "$WT" checkout -q feature
}

# $WT holds "main" itself — $REPO has to give main up first (parking on
# feature) before $WT can take it.
setup_worktree_on_main() {
  git -C "$WT" checkout -q scratch
  git -C "$REPO" checkout -q feature
  git -C "$WT" checkout -q main
}

# The literal scenario the task describes: the payload's own `cwd` is
# genuinely the worktree, and this already worked before any fix — kept as a
# regression lock, not proof of the fix.
check_dir allow setup_worktree_on_feature \
  "cwd is the worktree itself, on feature (root on main)" \
  "git commit -m x --allow-empty" "$WT"
check_dir deny setup_worktree_on_main \
  "cwd is the worktree itself, on main" \
  "git commit -m x --allow-empty" "$WT" "main"

# The actual TASK-301 bug: the payload's `cwd` is pinned to the *root*
# checkout, but the command names the worktree itself via a leading `cd` or
# `git -C`. Before the fix, branch/git_dir/lock all resolved from $REPO
# regardless — a commit that would land on $WT's feature branch read as
# landing on $REPO's main.
check_dir allow setup_worktree_on_feature \
  "cwd is root (on main); command cd's into the worktree (on feature)" \
  "cd $WT && git commit -m x --allow-empty" "$REPO"
check_dir deny setup_worktree_on_main \
  "cwd is root; command cd's into the worktree, which is on main" \
  "cd $WT && git commit -m x --allow-empty" "$REPO" "main"
check_dir allow setup_worktree_on_feature \
  "cwd is root (on main); command uses git -C into the worktree (on feature)" \
  "git -C $WT commit -m x --allow-empty" "$REPO"
check_dir deny setup_worktree_on_main \
  "cwd is root; command uses git -C into the worktree, which is on main" \
  "git -C $WT commit -m x --allow-empty" "$REPO" "main"

echo
echo "Review: quoted cd/-C paths must not lose the override"

# normalise deletes quoted text outside a shell wrapper, and bare_cd_dir /
# segment_target_dir used to be fed that deleting view — a quoted path, the
# form an agent will actually write, fell back to the wrong cwd and denied
# the commit exactly as TASK-301 did before its own fix.
check_dir allow setup_worktree_on_feature \
  "quoted cd into the worktree (on feature)" \
  "cd \"$WT\" && git commit -m x --allow-empty" "$REPO"
check_dir deny setup_worktree_on_main \
  "quoted cd into the worktree, which is on main" \
  "cd \"$WT\" && git commit -m x --allow-empty" "$REPO" "main"
check_dir allow setup_worktree_on_feature \
  "quoted git -C into the worktree (on feature)" \
  "git -C \"$WT\" commit -m x --allow-empty" "$REPO"

echo
echo "Review: relative cd/-C paths must compose, not resolve against cwd alone"

# `cd mid && cd leaf` must land in WT_PARENT/mid/leaf ($WT), not
# WT_PARENT/leaf (resolving the second cd against cwd instead of against
# where the first cd actually left off).
check_dir allow setup_worktree_on_feature \
  "two relative cd's compose (cd mid && cd leaf)" \
  "cd mid && cd leaf && git commit -m x --allow-empty" "$WT_PARENT"
check_dir deny setup_worktree_on_main \
  "two relative cd's compose, worktree on main" \
  "cd mid && cd leaf && git commit -m x --allow-empty" "$WT_PARENT" "main"
# `cd mid && git -C leaf …` must resolve leaf against WT_PARENT/mid, not
# against WT_PARENT.
check_dir allow setup_worktree_on_feature \
  "relative cd then relative -C compose (cd mid && git -C leaf)" \
  "cd mid && git -C leaf commit -m x --allow-empty" "$WT_PARENT"

echo
echo "Review: -C on one segment must not carry to a later, unrelated segment"

# The load-bearing invariant guard-git.sh states in a comment (resolve_dir's
# section) but which had no row: a -C naming the worktree on a read-only
# segment must not leak into a later plain `git commit`, which really does
# run against $REPO on main.
check_dir deny setup_worktree_on_feature \
  "-C on a read-only segment does not carry to a later plain commit" \
  "git -C $WT status && git commit -m x" "$REPO" "main"
# The mirror image: a directory named by a *later* segment must not apply to
# an earlier one either — the commit here runs first, against $REPO on main,
# before the -C segment is ever reached.
check_dir deny setup_worktree_on_feature \
  "a directory named by a later segment does not apply backwards" \
  "git commit -m x && git -C $WT status" "$REPO" "main"

echo
echo "-------------------------------------------"
printf 'passed: %d   failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
