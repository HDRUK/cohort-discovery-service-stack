# Open-source standalone stack: plan of work

> **AI disclosure:** Drafted with Claude Code on 2026-11-11 from a read of `project-daphne-web`, `project-daphne-api`, `project-daphne-nlp`, `somop`, `project-daphne-bunny-config`, `cohort-discovery-service-evaluator` and `cohort-discovery-service-docs`.

**Status:** plan written. Decisions D1–D5 and D10–D12 are agreed; the rest are open. S0 is in progress.

## Aims

1. Others can pull public images of web, API and NLP and run them in **standalone mode** without HDR UK's pipelines.
2. Configuration is by env and mounted files (claims mapping, NLP rules, branding), not by forking.
3. By default the IdP manages roles, custodians and workgroups, with seeding on top. The web shows workgroups read-only when they are managed externally.
4. One repo (this one) brings the stack up on Kubernetes with a Helm chart, driven locally by Tilt (D12), with a throwaway Keycloak, MySQL and Redis, an OMOP vocabulary (minimal or full Athena) and synthetic collections served by somop-backed BUNNYs.
5. The bootstrap seeds a service admin, creates custodians, hosts and collections through the API, and hands the host credentials to the BUNNYs.
6. HDR UK's own build and deploy keeps working unchanged (D3).

## Files

| File | What |
|---|---|
| [01-decisions.md](01-decisions.md) | Agreed and open decisions |
| [02-verified-facts.md](02-verified-facts.md) | The current state of each repo, checked 2026-11-11 |
| [tickets/](tickets/) | One plan per ticket, written so an agent can start from that file plus `02-verified-facts.md` |

## How to pick up a ticket

In Claude Code, `/stack-ticket <ID>` runs these steps, and `/stack-ticket next` lists what can start.

1. Read the ticket, `02-verified-facts.md`, and the decisions the ticket names.
2. If a decision it depends on is still open, stop and ask. Don't settle it yourself.
3. Work in the repo the ticket names, branched from that repo's default branch.
4. When done, update the ticket's status here and add anything you learned to `02-verified-facts.md`.

## Tickets

Status: `todo`, `in progress`, `in review`, `done`, `blocked`.

| ID | Repo | Ticket | Depends on | Status |
|---|---|---|---|---|
| [H1](tickets/H1-open-source-hygiene.md) | all | Open-source hygiene: secrets, personal paths, licence, GDPR review | – | todo |
| [A1](tickets/A1-api-buildable-image.md) | api | Image anyone can build: public composer packages, `.dockerignore`, production defaults | H1, D13 | todo |
| [A2](tickets/A2-api-bootstrap-command.md) | api | Idempotent first-boot `app:bootstrap` with initial admin from env | A1 | todo |
| [A3](tickets/A3-api-claims-mapping-file.md) | api | Claims mapping from a mounted file | D9 | todo |
| [A4](tickets/A4-api-externally-managed-access.md) | api | Externally managed access: flag, write guard, exposed to web | A3, D8 | todo |
| [W1](tickets/W1-web-workgroups-read-only.md) | web | Workgroups read-only when access is managed externally | A4 | todo |
| [W2](tickets/W2-web-build-and-runtime-variables.md) | web | **Research:** build-time vs run-time variables and their knock-on effects | – | todo |
| [W3](tickets/W3-web-branding-completeness.md) | web | Branding fully overridable from `branding/`, plus a neutral default | D6 | todo |
| [N1](tickets/N1-nlp-image-and-config.md) | nlp | Publish the image, document the mounts | D2 | todo |
| [S0](tickets/S0-stack-scaffold.md) | stack | Scaffold: submodules, chart and Tiltfile skeletons, `config/` layout | D5 | in progress |
| [S1](tickets/S1-stack-helm-core.md) | stack | Helm core and Tilt: data stores, services, init, scheduler | S0 | todo |
| [S2](tickets/S2-stack-keycloak.md) | stack | Throwaway Keycloak in the chart, wired as SSO | S1, A3 | todo |
| [S3](tickets/S3-stack-omop-vocabulary.md) | stack | OMOP vocabulary: minimal default and optional Athena import Job | S1 | todo |
| [S4](tickets/S4-stack-provisioner.md) | stack | Provisioner: custodians, hosts and collections through the API | S1, A2 | todo |
| [S5](tickets/S5-stack-synthetic-bunnies.md) | stack, somop | somop-backed BUNNYs, added by hand per collection | S4, D16 | todo |
| [S6](tickets/S6-stack-non-local-installs.md) | stack | Non-local installs: ingress, external stores, example values | S1–S5 | todo |
| [S7](tickets/S7-stack-ci-build-and-deploy.md) | stack | CI: build from any ref, push to GHCR, deploy | S1, D14 | todo |

## Suggested order

- **In parallel from the start:** H1, W2, A3, N1, S0.
- **Then:** S1. It starts with its own init Job, so it doesn't wait for A1 and A2; it switches to `app:bootstrap` when A2 lands. S1 is the first point where the stack runs end to end.
- **After S1:** S2 (needs A3), S3, S4 → S5, and A4 → W1.
- **Last:** S6 and S7.
