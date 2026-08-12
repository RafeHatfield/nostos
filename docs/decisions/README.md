# Decisions

One file per decision that **closed an option**. Not every choice — only the ones
where picking A meant B is now expensive or impossible: the engine, the save
format, the timestep, min-spec, a platform commitment, a dependency that reaches
into gameplay.

Named `NNN-short-slug.md`, numbered in the order they were taken.

## Format

```markdown
# 001: <the decision, as a statement>

- **Date**: YYYY-MM-DD
- **Status**: accepted | superseded by NNN

## What was decided
One or two sentences. The decision, not the discussion.

## What it closed off
The options rejected, each with why. **This is the part that earns the file.**
A decision record listing only the winner tells a future reader nothing they
could not get from the code.

## What would reopen it
The observation that would make this the wrong call. If nothing would, say so —
"this is load-bearing and reversing it means a rewrite" is a useful thing for
the next person to know.
```

## Why this exists

The failure mode it prevents: someone re-litigates a settled decision because
the reasoning lived in a chat log, or — worse — quietly works around it because
they assume it was arbitrary. `CLAUDE.md` says what the project does; these say
why it does not do the other thing.

A decision taken as a side effect of an unrelated change does not get a file
here, because it does not get taken at all. `CLAUDE.md` §Agent rules: name it and
stop.
