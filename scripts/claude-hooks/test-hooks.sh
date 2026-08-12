#!/usr/bin/env bash
# Runs every Claude Code hook guard and its behaviour suite.
#
# Invoke directly (`./scripts/claude-hooks/test-hooks.sh`) until the engine is
# chosen and there is a task runner to hang it off. When CI exists, the CI job
# must run this same script rather than a re-listed set of guards: a guard
# registered in only one of the two runs nowhere that gates a merge, which is
# how a guard shipped dead in the project this was ported from.
#
# Fails loudly rather than skipping when shellcheck is missing — a hooks check
# that silently passes with nothing checked is worse than no check.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "error: shellcheck is not installed. Install it (e.g. 'brew install shellcheck' or 'apt-get install shellcheck') and re-run." >&2
  exit 1
fi

shellcheck scripts/claude-hooks/*.sh

# The case table runs before the checker it covers, every time. A checker
# nobody has tried to defeat is a checker you are guessing about; several of
# these had silent bypasses that returned success while checking nothing.
./scripts/claude-hooks/guard-git.test.sh

# Nothing else sees a conflict marker in a Markdown file — it breaks no build
# and fails no test.
./scripts/claude-hooks/check-no-conflict-markers.test.sh
./scripts/claude-hooks/check-no-conflict-markers.sh

# The task list is the only map of what work is left, and a duplicated id
# makes a reference ambiguous.
./scripts/claude-hooks/check-task-ids.test.sh
./scripts/claude-hooks/check-task-ids.sh

echo
echo "all hook guards passed."
