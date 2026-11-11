---
name: stack-ticket
description: Pick up, work on or close one ticket from this repo's open-source stack plan (docs/tickets/). Use when the user says "work on S1", "pick up A3", "/stack-ticket W2", "what's next", "what can I start", or asks to update the tracker after finishing a ticket.
argument-hint: "<ticket id, e.g. S1> | next | status"
---

# Working a stack ticket

The plan lives in `docs/`:
- `README.md` holds the tracker.
- `01-decisions.md` holds the decisions.
- `02-verified-facts.md` holds the state of each repo.
- `tickets/` holds one plan per ticket.

Each ticket is meant to be done in its own session.

## `status` or `next`

1. Read the tracker table in `docs/README.md`.
2. List the tickets whose status is `todo` and whose dependencies are all `done`, including any decisions they need being agreed in `01-decisions.md`.
3. For `next`, recommend one, following the README's "Suggested order". Don't start it until the user says which.

## Starting a ticket `<ID>`

1. Read `docs/tickets/<ID>-*.md`, `docs/02-verified-facts.md`, and every decision the ticket names.
2. **Check it can start.**
   - If a dependency isn't `done`, or a decision it needs is still open, stop. Tell the user which, and give the recommendation from `01-decisions.md`. Don't decide it yourself.
3. **Work out where the work happens.** The ticket's **Repo** line says which repo.

| Ticket prefix | Where | Branch from | Branch name |
|---|---|---|---|
| `S` | this repo | `main` | `feat/<ID>-<slug>` |
| `A` | `../project-daphne-api` | `dev` | `feat/<jira or ID>-<slug>` |
| `W` | `../project-daphne-web` | `dev` | `feat/<jira or ID>-<slug>` |
| `N` | `../project-daphne-nlp` | `dev` | `feat/<jira or ID>-<slug>` |
| `H` | several | – | per repo |

   For a service repo, read that repo's `CLAUDE.md` and follow its conventions and commands, which override anything general here. Ask whether a Jira ticket exists for the work. Service repos check PR titles against `feat(DP-1234): …`.
4. **Plan.** Restate the ticket's "Done when" as checks you'll run, then work through the steps.
   - For Compose, Helm, Keycloak and CI work, use the `stack-platform-engineer` agent.
   - Use `laravel-senior-backend` for the API, `senior-python-developer` for NLP, and the web repo's own agents for web.
5. In the tracker, set the ticket's status to `in progress`.

## While working

- If something in `02-verified-facts.md` turns out to be wrong, correct it there in the same change.
- If the ticket raises a new decision, add it to `01-decisions.md` as open, with a recommendation, and ask the user.
- Stay inside the ticket. Note follow-up work as a new ticket row in the tracker, marked `todo`, rather than doing it.

## Finishing

1. Run the ticket's verification steps and report what you ran and the results. If anything can only be checked by hand (a browser, a real Athena download), say it is still outstanding.
2. Set the tracker status: `in review` once a PR exists, `done` once it's merged.
3. Write the PR description with `/raise-pr`. Don't push or open a PR unless the user asks.
