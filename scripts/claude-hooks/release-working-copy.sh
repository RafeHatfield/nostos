#!/usr/bin/env bash
# SessionEnd hook. Releases this session's claim on the working copy.
#
# Without this the lock is only ever written, never removed, and
# LOCK_STALE_SECONDS decides when the next session may work. That made the most
# ordinary sequence fail closed: finish a session, start another in the same
# checkout, and every state-changing git command is blocked until the stale
# window elapses — with a message saying the copy is "contested" by a session
# that has already exited.
#
# Only removes a lock this session owns, so it cannot free a copy another live
# session is holding.

set -u

# Without jq this hook cannot read the payload or emit its warning, so say so
# rather than exiting silently.
# systemMessage, not stderr: on exit 0 stderr is not surfaced to the user, so
# the session that most needs to know tracking is off would not be told.
command -v jq >/dev/null 2>&1 || {
  printf '%s\n' '{"systemMessage":"release-working-copy: jq not found — working-copy tracking is DISABLED"}'
  exit 0
}

payload=$(cat)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // "."')
sid=$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')

cd "$cwd" 2>/dev/null || exit 0
git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0

lock="${git_dir}/claude-session.lock"
[ -f "$lock" ] || exit 0

holder=$(head -n1 "$lock" 2>/dev/null | cut -d' ' -f1)
if [ "$holder" = "$sid" ]; then
  rm -f "$lock"
fi

exit 0
