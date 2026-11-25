# Open-source standalone stack: plan of work

> **AI disclosure:** Drafted with Claude Code on 2026-11-11 from a read of `project-daphne-web`, `project-daphne-api`, `project-daphne-nlp`, `somop`, `project-daphne-bunny-config`, `cohort-discovery-service-evaluator` and `cohort-discovery-service-docs`.

**Status:** plan written. Decisions D1–D6, D8–D17 and D20–D22 are agreed; the rest are open. S0–S6, S8–S10, S12 and S13 are done; S7 is not needed. A4, A8, W1 and W2 are done.

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
| [web-variables.md](web-variables.md) | Which web variables are fixed at build time, and what a generic image needs (W2) |
| [alternatives/](alternatives/) | Other ways to run the service, such as [Docker Compose](alternatives/docker-compose.md) |
| [data-protection/](data-protection/) | What the service holds about people, for data protection review ([inventory](data-protection/personal-data-inventory.md)) |

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
| [H1](tickets/H1-open-source-hygiene.md) | all | Open-source hygiene: secrets, personal paths, licence, GDPR review | – | in progress |
| [A1](tickets/A1-api-buildable-image.md) | api | Image anyone can build: public composer packages, `.dockerignore`, production defaults | D13 | todo |
| [A2](tickets/A2-api-bootstrap-command.md) | api | Idempotent first-boot `app:bootstrap` with initial admin from env | A1 | todo |
| [A3](tickets/A3-api-claims-mapping-file.md) | api | ~~Claims mapping from a mounted file~~ Not needed: D9 mounts a replacement config file instead, in S2 | D9 | not needed |
| [A4](tickets/A4-api-externally-managed-access.md) | api | Externally managed access: deployment and per-user policy exposed to the web, advisory with activity-log warnings. Merged to `dev` (DP-1261, #367) | – | done |
| A5 | api | Stop logging request bodies (passwords reach the logs), and enforce retention on `request_audits`, `activity_log` and `nlp_query_logs`. Found in H1, see [personal data inventory](data-protection/personal-data-inventory.md) | – | on hold |
| [A10](tickets/A10-api-feature-flag-defaults-file.md) | api | Feature flag defaults from `config/features.php`, so the stack sets them in `customisations/api/features.php`. DP-1277 (api #377, open) adds `config/features.php` | – | in progress (DP-1277) |
| [A6](tickets/A6-api-sso-custodian-provisioning.md) | api | Create custodians from SSO claims, behind a setting, as integrated mode already does. Found in S2 | – | todo |
| [A7](tickets/A7-api-missing-claim-authoritative.md) | api | Under an authoritative sync, treat a missing groups claim as empty, so removing a user's last group removes their workgroups (D20). Found in S2 | – | todo |
| [A8](tickets/A8-api-many-to-one-claim-mapping.md) | api | Map several IdP groups or roles to one workgroup or role, e.g. `ukri`, `breathe` and `ncs` to `UK-RESEARCH`. Found in S2. Merged to `dev` (DP-1254, #364) with `config/workgroups.php` | – | done |
| [A9](tickets/A9-api-collection-workgroup-authorisation.md) | api | Authorise adding and removing a collection's workgroups; today any signed-in user can. Found in S4, may be DP-354 | – | todo |
| [W1](tickets/W1-web-workgroups-read-only.md) | web | IdP-managed memberships read-only or warned, per user; retire `manage-workgroups-internally`. Merged to `dev` (DP-1262, #628, #629) | A4 | done |
| [W2](tickets/W2-web-build-and-runtime-variables.md) | web | **Research:** build-time vs run-time variables and their knock-on effects ([findings](web-variables.md)) | – | done |
| W4 | web | Optional: task URL at run time through `ServerDefaultProvider`, falling back to `NEXT_PUBLIC_TASK_URL`, so the published image needs no rebuild at another URL. See [web-variables.md](web-variables.md#if-w4-is-done) | D7 | todo |
| W5 | web | `Custom403.tsx` reads `APPLICATION_MODE` in the browser, where it's `undefined`, so standalone installs may send "sign in again" to the organisation site instead of `/login`. Check in a browser, then fix upstream. Found in W2 | – | on hold |
| [W3](tickets/W3-web-branding-completeness.md) | web | Close the gaps where the web ignores `branding/` (copyright text, favicons, leftover HDR UK strings). The neutral default and build script moved to S8 | D6 | on hold |
| [N1](tickets/N1-nlp-image-and-config.md) | nlp | Publish the image, document the mounts | D2 | todo |
| [S0](tickets/S0-stack-scaffold.md) | stack | Scaffold: submodules, chart and Tiltfile skeletons, `config/` layout | D5 | done |
| [S1](tickets/S1-stack-helm-core.md) | stack | Helm core and Tilt: data stores, services, init, scheduler | S0 | done |
| [S2](tickets/S2-stack-keycloak.md) | stack | Throwaway Keycloak in the chart, wired as SSO, with the claims mapping mounted (D9) | S1 | done |
| [S3](tickets/S3-stack-omop-vocabulary.md) | stack | OMOP vocabulary: minimal default and optional Athena import Job | S1 | done |
| [S4](tickets/S4-stack-provisioner.md) | stack | Provisioner: custodians, hosts and collections through the API, shared with workgroups and made active | S1, S2, D22 | done |
| [S5](tickets/S5-stack-synthetic-bunnies.md) | stack | A synthetic database and BUNNY for each synthetic collection in `provision.json`, set up automatically | S4, D16 | done |
| [S6](tickets/S6-stack-non-local-installs.md) | stack | Non-local installs: ingress, external stores, example values | S1–S5 | done |
| [S7](tickets/S7-stack-ci-build-and-deploy.md) | stack | ~~CI: build from any ref, push to GHCR, deploy~~ Not needed: deployers run their own stacks and the docs show how (D14) | – | not needed |
| [S8](tickets/S8-stack-branding-overlay.md) | stack | "Feasibility Tool" neutral branding in `config/branding/`, and the D6 build script used by Tilt | D6 | done |
| [S9](tickets/S9-stack-user-docs.md) | stack | User docs: a short README, sectioned docs, an MkDocs site | S6 | done |
| [S10](tickets/S10-stack-docs-restructure.md) | stack | Restructure the user docs after review: one place to read, deploy order, connecting real BUNNYs, one diagram, links to the service docs | S9 | done |
| [S11](tickets/S11-stack-cluster-readiness.md) | stack | Chart gaps for real clusters: Keycloak `start-dev`, `imagePullSecrets`, vocabulary import from a volume, volumes on uninstall. Found in S10 | S6 | in progress |
| [S12](tickets/S12-stack-tilt-settings.md) | stack | Tilt settings (host ports, Keycloak on or off) in a git-ignored `tilt_config.json` or flags, instead of exported env vars | S1 | done |
| [S13](tickets/S13-stack-deploy-docs-by-component.md) | stack | Split "Deploy to a cluster" into a page per part: how to build and override the API, web and NLP images, sign-in, the database and vocabulary, and the supporting services | S10 | done |
| [SD1](tickets/SD1-service-docs-link-to-stack.md) | service docs | Link the general service docs to the stack, and fix their out-of-date pages. Found in S10 | S10 | todo |

## Suggested order

- **In parallel from the start:** W2, N1, S0.
- **Then:** S1. It starts with its own init Job, so it doesn't wait for A1 and A2; it switches to `app:bootstrap` when A2 lands. S1 is the first point where the stack runs end to end.
- **After S1:** S2, S3, S4 → S5, S8, and A4 → W1.
- **Last:** S6, then close H1 (rotation, licence files, data protection hand-over). It blocks nothing.
