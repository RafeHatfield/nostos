#!/usr/bin/env bash
# Fails if any tracked file carries an unresolved git conflict marker.
#
# Ported from the starfish repo. The incident below happened there; it is kept
# because the failure mode is a property of Markdown and parallel agents, not
# of that project.
#
# This exists because three separate agents independently reported finding
# `<<<<<<< HEAD` committed to `docs/product-spec.md` and `tasks/known-gaps.md`
# on main — left there by an automated conflict resolution in a parallel round
# that handled the common marker shape and silently missed one variant.
#
# Markdown is why it survived: a conflict marker in a `.md` file breaks no
# build, fails no test, and renders as ordinary text. In the spec it was worse
# than cosmetic — the two sides were semantically opposite, one saying a bug
# was unfixed and the other saying it was fixed, so the contract documented a
# defect that no longer existed.
#
# Scans the working-tree contents of every tracked file, not `HEAD` — so this
# also catches a marker while it's still staged, before it's committed. That
# means it fires on every file a real conflicted merge has written markers
# into, which review found the comment here used to describe as "not this
# check's business" when the code did the opposite: a merge conflict marks
# its files as tracked-but-unmerged (`git ls-files -u`), not untracked, and
# this script would otherwise report every one of them mid-resolution. It now
# checks for that explicitly and skips rather than reports, so
# `npm run test:hooks` run during a real merge doesn't drown the developer in
# errors about the exact files they're already fixing.
#
# Matches all four marker lines git can write to a conflicted file —
# `<<<<<<<`, the diff3/zdiff3 base marker `|||||||` (only present under
# `merge.conflictStyle = diff3` or `zdiff3` — the "one variant" the resolver
# above silently missed), `=======`, and `>>>>>>>` — each tolerant of a
# trailing `\r` for a CRLF working tree. A bare `=======` or `|||||||` line
# with no `<<<<<<<`/`>>>>>>>` elsewhere in the same file is still reported:
# that is exactly the shape left behind by a resolver that strips the outer
# pair but not the one in the middle, which is the failure class this script
# exists to catch. The cost, accepted deliberately, is a false positive on a
# seven-`=`-character Markdown setext-heading underline; none exist in this
# tree today (checked before this comment was written), and one added on
# purpose can pick a different rule length.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target_dir="${1:-$repo_root}"
cd "$target_dir"

# A conflict currently being resolved is not this check's business (see
# above) — bail out before scanning anything written into it.
if [ -n "$(git ls-files -u 2>/dev/null)" ]; then
  echo "merge in progress — skipping conflict-marker scan."
  exit 0
fi

# One pattern, used for both detection and for printing the offending lines,
# so the two cannot drift the way the double `grep` call they replaced could.
pattern='^(<<<<<<< |\|\|\|\|\|\|\| |=======\r?$|>>>>>>> )'

# `git ls-files -z`, into a real file rather than a pipeline or a process
# substitution: `set -e`/`pipefail` do not see the exit status of a command
# feeding `< <(...)`, so a failing `git ls-files` (no repo, dubious
# ownership, `.git` absent — `.dockerignore` excludes it, so this would
# otherwise pass vacuously inside the app image) used to leave `failed` at 0
# and print a clean bill of health having read nothing. `-z`/NUL-delimited
# also avoids `git`'s C-style quoting of non-ASCII paths, which the plain
# `read` loop this replaced would silently skip past its `[ -f ]` guard.
file_list="$(mktemp)"
trap 'rm -f "$file_list"' EXIT

if ! git ls-files -z > "$file_list"; then
  echo "error: git ls-files failed — refusing to report a clean scan" >&2
  exit 1
fi

if [ ! -s "$file_list" ]; then
  echo "error: git ls-files listed no tracked files — refusing to report a clean scan" >&2
  exit 1
fi

failed=0
while IFS= read -r -d '' file; do
  [ -f "$file" ] || continue

  # `--` before the path so a filename that happens to start with `-` is
  # never read as a grep flag. The `if` form (rather than piping to
  # `>/dev/null`) keeps the failing exit status visible to `set -e`'s
  # exemptions while still letting a real grep error (2: unreadable file,
  # bad pattern) be told apart from "no match" (1) instead of both being
  # treated as clean.
  if matches="$(grep -nE "$pattern" -- "$file" 2>&1)"; then
    echo "error: $file contains unresolved git conflict markers:" >&2
    while IFS= read -r line; do
      echo "  $line" >&2
    done <<< "$matches"
    failed=1
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      echo "error: could not scan $file (grep exit $status): $matches" >&2
      failed=1
    fi
  fi
done < "$file_list"

if [ "$failed" -ne 0 ]; then
  echo "Resolve the conflict and commit the result. A marker in a Markdown file" >&2
  echo "breaks no build and fails no test — this check is the only thing that sees it." >&2
  exit 1
fi

echo "no unresolved conflict markers in tracked files."
