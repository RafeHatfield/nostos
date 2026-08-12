#!/usr/bin/env bash
# Case table for check-task-ids.sh, in the shape of the sibling guards.
#
# The guards in this directory have a history of shipping with silent
# bypasses that returned success while checking nothing — the compose guard
# had two, the dev-server guard had two more, and the k8s guard had seven.
# Every one was found by someone deliberately trying to defeat it. A security
# or integrity check nobody has attacked is a check you are guessing about.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$script_dir/check-task-ids.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

passed=0
failed=0

# run_case <expect: allow|deny> <name> then heredoc pairs of "filename" "body"
run_case() {
  local expect="$1" name="$2"; shift 2
  local dir out code
  dir="$(mktemp -d "$tmp_root/case.XXXXXX")"

  while [ "$#" -gt 0 ]; do
    printf '%s\n' "$2" > "$dir/$1"
    shift 2
  done

  out="$("$checker" "$dir" 2>&1)"
  code=$?

  local got
  if [ "$code" -eq 0 ]; then got="allow"; else got="deny"; fi

  if [ "$got" = "$expect" ]; then
    printf '  ok   [%s]  %s\n' "$expect" "$name"
    passed=$((passed + 1))
  else
    printf '  FAIL [%s, got %s]  %s\n' "$expect" "$got" "$name"
    printf '       output: %s\n' "$out"
    failed=$((failed + 1))
  fi
}

# run_msg <expect-substring> <name> then filename/body pairs.
# Exit-code-only assertions let a deny pass for the wrong reason — the
# refuse-when-empty branch and a real collision both exit 1, so a case meant
# to prove one could be satisfied by the other. These pin the message.
run_msg() {
  local want="$1" name="$2"; shift 2
  local dir out
  dir="$(mktemp -d "$tmp_root/msg.XXXXXX")"
  while [ "$#" -gt 0 ]; do
    printf '%s\n' "$2" > "$dir/$1"
    shift 2
  done
  out="$("$checker" "$dir" 2>&1)"
  if printf '%s' "$out" | grep -q "$want"; then
    printf '  ok   [msg]  %s\n' "$name"
    passed=$((passed + 1))
  else
    printf '  FAIL [msg]  %s\n' "$name"
    printf '       wanted: %s\n       got:    %s\n' "$want" "$out"
    failed=$((failed + 1))
  fi
}

echo
echo "Unique ids pass"

run_case allow "distinct ids in one file" \
  "a.md" '- [ ] TASK-001: one
- [x] TASK-002: two'

run_case allow "distinct ids across files" \
  "a.md" '- [ ] TASK-001: one' \
  "b.md" '- [x] TASK-002: two'

run_case allow "checked and unchecked boxes both count as claims" \
  "a.md" '- [ ] TASK-010: pending
- [x] TASK-011: done'

# The whole point of excluding README: it documents the format with literal
# placeholder entries, which are not claims on an id.
run_case allow "README template placeholders do not collide with real tasks" \
  "README.md" '- [ ] TASK-001: <one completable change>
- [x] TASK-002: <another>' \
  "phase-0.md" '- [x] TASK-001: Initialize the app
- [x] TASK-002: Set up Prisma'

run_case allow "an id mentioned in prose is not a claim" \
  "a.md" '- [ ] TASK-001: one
  - Context: supersedes TASK-001 in the old numbering, see also TASK-002.'

echo
echo "Collisions are refused"

run_case deny "same id twice in one file" \
  "a.md" '- [ ] TASK-001: one
- [x] TASK-001: a different thing'

run_case deny "same id across two files" \
  "phase-4.md" '- [x] TASK-500: capture-once guard' \
  "round-2.md" '- [x] TASK-500: unassigned resolution credits'

run_case deny "collision between a checked and an unchecked entry" \
  "a.md" '- [ ] TASK-700: pending version' \
  "b.md" '- [x] TASK-700: closed version'

run_case deny "three files claiming one id" \
  "a.md" '- [ ] TASK-551: markers' \
  "b.md" '- [ ] TASK-551: markers again' \
  "c.md" '- [ ] TASK-551: markers a third time'

# README is excluded from *claiming* ids, but a real file colliding with
# another real file must still fail even when a README is present — otherwise
# the exclusion could be widened by accident and disable the whole check.
run_case deny "README present does not suppress a real collision" \
  "README.md" '- [ ] TASK-001: <one completable change>' \
  "a.md" '- [x] TASK-300: thing' \
  "b.md" '- [x] TASK-300: other thing'

echo
echo "Indented entries are real claims"

# tasks/phase-2-metrics.md really does carry an indented, open,
# spec-referenced entry (TASK-531). A column-0 anchor skipped it silently, so
# a collision involving it could never have been reported.
run_case allow "an indented entry is counted" \
  "a.md" '- [ ] TASK-100: top level
    - [ ] TASK-101: nested under it'

run_case deny "indented entry colliding with a top-level one" \
  "a.md" '- [ ] TASK-100: top level' \
  "b.md" '    - [ ] TASK-100: indented, same id'

run_case deny "two indented entries colliding" \
  "a.md" '  - [ ] TASK-200: one' \
  "b.md" '      - [ ] TASK-200: two'

# An id followed by something other than a colon must still be a claim —
# otherwise a renumbering note or a parenthetical would hide one.
run_case deny "id followed by a parenthetical is still a claim" \
  "a.md" '- [x] TASK-300 (superseded): one' \
  "b.md" '- [x] TASK-300: two'

# ...but a longer id must not be read as a shorter one plus text.
run_case allow "TASK-1000 is not TASK-100" \
  "a.md" '- [ ] TASK-100: one' \
  "b.md" '- [ ] TASK-1000: a different, four-digit id'

echo
echo "Messages say what actually happened"

run_msg "claimed more than once" "collision message names the condition" \
  "a.md" '- [x] TASK-300: one' \
  "b.md" '- [x] TASK-300: two'

run_msg "a.md" "collision message names the files" \
  "a.md" '- [x] TASK-300: one' \
  "b.md" '- [x] TASK-300: two'

run_msg "no .TASK-nnn. entries found" "empty-subject refusal is distinguishable from a collision" \
  "a.md" '# nothing here'

echo
echo "Refuses rather than assuming safe"

run_case deny "no task entries at all is refused, not passed" \
  "a.md" '# Notes with no task entries'

run_case deny "only a README is refused" \
  "README.md" '- [ ] TASK-001: <one completable change>'

echo
echo "-------------------------------------------"
printf 'passed: %s   failed: %s\n' "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
  exit 1
fi
