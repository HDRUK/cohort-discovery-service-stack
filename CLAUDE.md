# CLAUDE.md

Guidance for Claude Code in the `cohort-discovery-service-stack` repo (`HDRUK/cohort-discovery-service-stack`).

## What this repo is

The open-source deployment of the Cohort Discovery Service (Daphne). It runs the three services in **standalone mode**, configured entirely by `.env` and mounted files:
- web (`project-daphne-web`, Next.js)
- API (`project-daphne-api`, Laravel)
- NLP (`project-daphne-nlp`, FastAPI)

On top of the core it adds:
- Docker Compose, then a Helm umbrella chart;
- an optional Keycloak profile, with the identity provider authoritative for roles, custodians and workgroups;
- an OMOP vocabulary build, minimal by default or a full Athena import;
- a bootstrap that seeds an admin and provisions custodians, collection hosts and collections through the API;
- synthetic collections, served by somop-generated data and BUNNY daemons;
- CI that builds images from any branch, pushes them to GHCR and deploys.

HDR UK's own dev, preprod and prod deployments are separate and must keep working unchanged.

## Status

Planning is done. Nothing is built yet. The plan is in `docs/`:

| File | What |
|---|---|
| `docs/README.md` | Aims, ticket tracker (status, repo, dependencies), suggested order |
| `docs/01-decisions.md` | Agreed decisions (D1–D5, D11) and open ones, each with a recommendation |
| `docs/02-verified-facts.md` | The state of every repo involved, with file paths. Read this before exploring |
| `docs/tickets/` | One self-contained plan per ticket |

Use `/stack-ticket <ID>` to pick up a ticket, `/stack-ticket next` to see what can start, and `/raise-pr` for the PR description.

## Where work happens

| Ticket | Repo | Base branch |
|---|---|---|
| `S0`–`S7` | this repo | `main` |
| `A1`–`A4` | `../project-daphne-api` | `dev` |
| `W1`–`W3` | `../project-daphne-web` | `dev` |
| `N1` | `../project-daphne-nlp` | `dev` |
| `H1` | all of them | per repo |

Service tickets are done in that service's own checkout, following its `CLAUDE.md`, and their PRs go to that repo. Don't patch a service from inside this repo's submodules: change it upstream, then bump the submodule pin.

## Layout

The planned layout, created by S0:

```
services/{web,api,nlp}/   git submodules pinned to release tags (D5)
config/                   claims-mapping.json, nlp/, branding/, keycloak/, provision.json, synthetic/
compose/                  Compose files and profiles (keycloak, vocab, synthetic)
charts/                   Helm umbrella chart (S6)
scripts/                  build-web.sh (branding overlay), provisioning
.env.example              every variable the stack reads, placeholders only
Makefile                  up, down, build, logs, vocab-import, provision
```

## Rules

- **Secrets never enter the repo.**
  - Never read or print `.env`. Use `.env.example`.
  - Generated credentials go to volumes or `generated/`, which is git-ignored, and are never logged.
- **Fictional people only** in realm exports, seeds, docs and tests, e.g. `admin@example.com`, `Jane Doe`.
- **Athena vocabulary files are licensed.** Mount them from a path the deployer supplies. Never commit them or bake them into an image.
- **Pin every image tag and every third-party action.** No `latest` or `edge`.
- **Jobs are idempotent.** Init, bootstrap, vocabulary import and provisioning can run again without changing anything.
- **Don't change how the services are built or started to suit the stack (D3).** Above all, the web build-time and run-time variables stay as they are unless W2 shows a change is necessary. Configure through env, mounted files and separate init steps.
- **Data protection.** The stack stores researcher emails, identity-provider claims and activity logs. Flag anything that adds to that, so it can be reviewed (H1).
- **British spelling** in prose, code and identifiers.

## Agents

Project agents in `.claude/agents/` are copied from `HDRUK/tech-team-claude-skills`, which is the source of truth. Update them there and copy them across again.

| Agent | Use for |
|---|---|
| `stack-platform-engineer` | Compose, Helm, Keycloak, init/provision jobs, CI. Defined in this repo |
| `docker-expert` | Dockerfiles and image hardening (A1, N1) |
| `laravel-senior-backend` | API tickets A1–A4 |
| `senior-python-developer` | NLP ticket N1, somop changes in S5 |
| `omop-specialist` | Vocabulary build (S3), synthetic data (S5) |
| `cohort-discovery-specialist` | BUNNY, collections and federated-query questions |
| `code-reviewer`, `web-appsec-senior`, `qa-tester` | Reviews, security review (H1, A4, S2) and testing |

`bunny-expert` isn't copied, because it hard-codes local paths. Install it globally from `tech-team-claude-skills` if you need it.

## Commands

None yet. S0 adds the `Makefile`, and later tickets add the stack commands to this section. For the services' own commands, see their `CLAUDE.md`.

## Shared context

@../cohort-discovery-service-claude-helpers/CLAUDE.md
