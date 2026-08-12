#!/usr/bin/env bash
# Case table for check-no-conflict-markers.sh, in the shape of
# check-compose-exposure.test.sh.
#
# This exists because the first version of that script shipped with several
# silent bypasses, each returning success while checking little or nothing:
# a failing `git ls-files` (or no repository at all — `.dockerignore`
# excludes `.git` from the app image) read as a clean scan; a missed diff3
# base marker (`|||||||`); non-ASCII filenames skipped via git's C-quoting;
# and a filename starting with `-` read as a grep flag. A check nobody has
# tried to defeat is a check you are guessing about. Every bypass found in
# review is a case below.
#
# Usage:  ./scripts/claude-hooks/check-no-conflict-markers.test.sh
# Every case gets its own scratch git repo, so this cannot touch the real
# working copy — and the checker under test accepts an optional directory
# argument for exactly this reason.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$script_dir/check-no-conflict-markers.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

passed=0
failed=0

new_repo() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Test
}

# run_case <expect: allow|deny> <name> <setup function>
# The setup function receives the scratch dir as $1 and leaves it in
# whatever state (tracked files, untracked files, mid-merge, no repo at all)
# the case wants to assert against.
run_case() {
  local expect="$1" name="$2" setup="$3"
  local dir out code got

  dir="$(mktemp -d "$tmp_root/case.XXXXXX")"
  "$setup" "$dir"

  out="$("$checker" "$dir" 2>&1)"
  code=$?

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

echo
echo "Clean trees pass"

setup_clean() {
  new_repo "$1"
  printf 'nothing to see here\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init
}
run_case allow "clean tracked file" setup_clean

echo
echo "Conflict markers are caught, each shape on its own"

setup_head_marker() {
  new_repo "$1"
  printf '<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> feature\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init
}
run_case deny "full conflict block (all four lines)" setup_head_marker

setup_bare_equals() {
  new_repo "$1"
  printf 'some prose\n=======\nmore prose\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init
}
run_case deny "bare ======= alone, no paired outer markers" setup_bare_equals

setup_bare_close() {
  new_repo "$1"
  printf 'some prose\n>>>>>>> deadbeef\nmore prose\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init
}
run_case deny "bare >>>>>>> alone" setup_bare_close

setup_diff3_base() {
  new_repo "$1"
  printf '<<<<<<< HEAD\nours\n||||||| base\ncommon ancestor\n=======\ntheirs\n>>>>>>> feature\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init
}
run_case deny "diff3/zdiff3 base marker (|||||||) — previously invisible" setup_diff3_base

setup_crlf() {
  new_repo "$1"
  printf '<<<<<<< HEAD\r\nours\r\n=======\r\ntheirs\r\n>>>>>>> feature\r\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init
}
run_case deny "CRLF working tree still matches the middle marker" setup_crlf

echo
echo "Regression: bypasses found in review of the first version"

setup_dash_filename() {
  new_repo "$1"
  printf '<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> feature\n' > "$1/-weird.md"
  git -C "$1" add -- -weird.md
  git -C "$1" commit -q -m init
}
run_case deny "filename starting with '-' isn't read as a grep flag" setup_dash_filename

setup_nonascii_filename() {
  new_repo "$1"
  printf '<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> feature\n' > "$1/fö÷ö.md"
  git -C "$1" add -- "fö÷ö.md"
  git -C "$1" commit -q -m init
}
run_case deny "non-ASCII filename isn't skipped via git's C-quoting" setup_nonascii_filename

setup_not_a_repo() {
  : # leave the scratch dir empty — no `git init` at all
}
run_case deny "not a git repository fails, rather than passing vacuously" setup_not_a_repo

echo
echo "Documented carve-outs"

setup_untracked() {
  new_repo "$1"
  printf 'nothing to see here\n' > "$1/tracked.md"
  git -C "$1" add tracked.md
  git -C "$1" commit -q -m init
  printf '<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> feature\n' > "$1/scratch.md"
}
run_case allow "marker in an untracked file is not this check's business" setup_untracked

setup_merge_in_progress() {
  new_repo "$1"
  printf 'line one\n' > "$1/a.md"
  git -C "$1" add a.md
  git -C "$1" commit -q -m init

  git -C "$1" checkout -q -b feature
  printf 'line one\nfeature change\n' > "$1/a.md"
  git -C "$1" commit -q -am feature

  git -C "$1" checkout -q main
  printf 'line one\nmain change\n' > "$1/a.md"
  git -C "$1" commit -q -am main

  git -C "$1" merge feature -q --no-edit >/dev/null 2>&1 || true
}
run_case allow "a real conflicted merge is skipped, not reported" setup_merge_in_progress

echo
echo "-------------------------------------------"
printf 'passed: %d   failed: %d\n' "$passed" "$failed"

[ "$failed" -eq 0 ]
