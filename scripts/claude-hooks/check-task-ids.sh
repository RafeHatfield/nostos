#!/usr/bin/env bash
# Asserts every `- [ ]`/`- [x] TASK-nnn:` id in tasks/ is claimed exactly once.
#
# Ported from the starfish repo, comments and all. The failures described below
# happened there, not here; they are kept verbatim because they are the reason
# this guard exists and because nothing about them is starfish-specific — any
# repo where two branches edit a task file will reproduce case 2 on its first
# parallel round.
#
# It went wrong three times there, each with a different shape and each caught
# by a human or a reviewer rather than by anything automatic:
#
#   1. Conflict markers committed to main produced FOUR entries for one defect
#      (TASK-551/561/571/581), because four agents each hit the same markers
#      from a different task and each raised their own.
#   2. TASK-715/716 were claimed by two branches at once. Git merged both task
#      files cleanly — the entries sat in different sections, so there was no
#      textual conflict — and the collision only surfaced when someone read
#      both.
#   3. TASK-500/501 each named two entirely different tasks across
#      phase-4-hardening.md and round-2-review-findings.md, undetected for
#      long enough that both were closed.
#
# The task list is the only map of what is left. A duplicated id makes a
# reference ambiguous ("see TASK-500" — which one?) and a duplicated *defect*
# makes the remaining work look larger than it is. Both are the same harm as a
# gap nobody wrote down: the map stops describing the territory.
#
# Deliberately checks ids only, not content. Two entries describing the same
# underlying defect under different ids is the harder problem (case 1 above)
# and no text scanner can see it; this closes the mechanical half, which is
# the half that recurs on every parallel branch.
#
# A text scanner rather than Node, for the same reason as the sibling guards:
# this runs in the CI `hooks` job, which has no Node and no install step.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tasks_dir="${1:-$repo_root/tasks}"

if [ ! -d "$tasks_dir" ]; then
  echo "error: $tasks_dir not found" >&2
  exit 1
fi

# `tasks/README.md` documents the file format and contains literal template
# placeholders (`- [ ] TASK-001: <one completable change>`). Those are examples
# of the shape, not claims on an id, so it is excluded — by exact filename, not
# by a pattern that could quietly widen to real task files later.
readme="$tasks_dir/README.md"

collisions=0
found_any=0

# Collect "id<TAB>file" for every real task entry, then look for repeats.
pairs="$(
  for f in "$tasks_dir"/*.md; do
    [ -e "$f" ] || continue
    [ "$f" = "$readme" ] && continue
    while IFS= read -r id; do
      printf '%s\t%s\n' "$id" "$(basename "$f")"
    done < <(grep -oE '^[[:space:]]*- \[[ xX]\] TASK-[0-9]+([^0-9]|$)' "$f" 2>/dev/null | grep -oE 'TASK-[0-9]+' || true)
  done
)"

if [ -n "$pairs" ]; then
  found_any=1
fi

# `sort | uniq -d` yields each id claimed more than once, anywhere. The
# per-file `uniq -c` in the loop body is what distinguishes "twice in one
# file" from "once in each of two files", and prints the count alongside each
# filename so the message says which shape it is.
while IFS= read -r id; do
  [ -z "$id" ] && continue
  files="$(printf '%s\n' "$pairs" | awk -F'\t' -v want="$id" '$1 == want { print $2 }' | sort | uniq -c | awk '{printf "%s(x%s) ", $2, $1}')"
  echo "error: $id is claimed more than once: $files" >&2
  collisions=1
done < <(printf '%s\n' "$pairs" | awk -F'\t' '{print $1}' | sort | uniq -d)

# A tasks/ directory with no entries at all means this scanner stopped
# matching the entry format, not that the project ran out of tasks. Refuse
# rather than pass, the same way the sibling guards do — a check that silently
# succeeds when it cannot find its subject is worse than no check.
if [ "$found_any" -eq 0 ]; then
  echo "error: no 'TASK-nnn' entries found under $tasks_dir. If the entry format changed, update this guard; until then it is refusing rather than passing on a subject it could not find." >&2
  exit 1
fi

if [ "$collisions" -ne 0 ]; then
  # Numeric sort, and only *claim* lines — a lexicographic sort suggests a
  # taken id the moment a four-digit one exists (TASK-1000 < TASK-999 as
  # strings), and matching bare `TASK-[0-9]+` would pick up ids merely
  # mentioned in prose, which are not claims.
  echo "Pick the next free id: grep -ohE '^[[:space:]]*- \[[ xX]\] TASK-[0-9]+' tasks/*.md | grep -oE '[0-9]+' | sort -n | tail -1" >&2
  exit 1
fi

total="$(printf '%s\n' "$pairs" | awk -F'\t' '{print $1}' | sort -u | wc -l | tr -d ' ')"
echo "task ids: $total distinct, no collisions."
