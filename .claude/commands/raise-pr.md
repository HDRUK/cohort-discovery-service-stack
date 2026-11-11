---
description: Write a PR description for the current branch into pr-descriptions/
argument-hint: "[ticket id, e.g. S1] [optional notes]"
allowed-tools: Bash(git *), Bash(gh *), Read, Write, Edit, Glob, Grep
---

Write a PR description for the changes on the current branch.

## Ticket

Take the ticket from `$ARGUMENTS` if it's given; otherwise read it from the branch name (`feat/S1-compose-core` → `S1`). Link the ticket plan: `docs/tickets/<ID>-*.md`. If there's also a Jira ticket, link it too: `https://hdruk.atlassian.net/browse/DP-1234`.

## Steps

1. Run `git fetch origin main`, then review the changes with `git log --oneline origin/main..HEAD` and `git diff origin/main...HEAD --stat`. Read the diff for anything you need to describe accurately. Never guess at what changed.
2. Write to `pr-descriptions/<ID>.md`. If that file already exists, ask before overwriting it.

## Template

Use exactly this shape. Omit a section only when it has nothing in it.

```markdown
_Written with Claude Code._

## What
One or two sentences. What this PR changes. Link the ticket.

## Why
One or two sentences. The problem it solves.

## Testing
How it was verified. Commands run, and the result.

## Notes
Bullets: a deliberate behaviour change, a follow-up deferred, a risk, anything a reviewer must know.
```

## Rules

- Put `_Written with Claude Code._` first only when Claude Code wrote some or all of the change.
- Never hard-wrap prose. One paragraph or bullet is one line.
- Don't restate the diff. Don't describe the stack or branch topology.
- Under Testing, list only what you actually ran. Say if a manual browser check is still outstanding.
- British spelling. Keep it under roughly 40 lines.
- Propose a PR title: `feat(S1): short description`, `fix(S4): …`, or `docs: …`.

Don't push or create the PR unless asked.
