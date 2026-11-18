# CLAUDE.md

Guidance for Claude Code in the `cohort-discovery-service-stack` repo (`HDRUK/cohort-discovery-service-stack`).

## What this repo is

The open-source deployment of the Cohort Discovery Service (Daphne). It runs the three services in **standalone mode** on Kubernetes, configured by Helm values and mounted files:
- web (`project-daphne-web`, Next.js)
- API (`project-daphne-api`, Laravel)
- NLP (`project-daphne-nlp`, FastAPI)

On top of the core it adds:
- a Helm umbrella chart, driven locally by Tilt (D12), with throwaway MySQL, Redis and Keycloak;
- Keycloak as the identity provider, authoritative for roles, custodians and workgroups;
- an OMOP vocabulary build, minimal by default or a full Athena import;
- a bootstrap that seeds an admin and provisions custodians, collection hosts and collections through the API;
- synthetic collections, served by somop-generated data and BUNNY daemons;
- CI that builds images from any branch, pushes them to GHCR and deploys.

HDR UK's own dev, preprod and prod deployments are separate and must keep working unchanged.

## Status

Planning, S0 (scaffold), S1 (Helm core and Tilt), S2 (Keycloak), S3 (vocabulary), S4 (provisioner), S5 (synthetic BUNNYs), S6 (non-local installs), S8 (branding), S9 (user docs and MkDocs site), S10 (docs restructure), S12 (Tilt settings) and S13 (deploy docs by component) are done. The site is published at https://hdruk.github.io/cohort-discovery-service-stack/ and links to the general service docs (https://hdruk.github.io/cohort-discovery-service-docs/) instead of repeating them. The user docs are the sectioned pages under `docs/` listed in `mkdocs.yml`; the planning files below are left out of the site. The plan is in `docs/`:

| File | What |
|---|---|
| `docs/README.md` | Aims, ticket tracker (status, repo, dependencies), suggested order |
| `docs/01-decisions.md` | Agreed decisions and open ones, each with a recommendation |
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

The layout:

```
services/{web,api,nlp}/   git submodules pinned to release tags (D5)
charts/cohort-discovery/  Helm umbrella chart: the one definition of the stack (D12)
  files/                  the chart's own scripts: api-init/, provision/, synthetic/
customisations/           everything a deployer changes, one folder per service (D21):
                          api/claimsaccesscontrol.php, keycloak/realm.json, nlp/,
                          athena/ (git-ignored Athena download, Tilt only, S3),
                          web/branding/ (a web build input, D6), provision.json (S4)
scripts/                  local-secrets.sh, customisations-values.sh, build-web.sh (D6)
Tiltfile                  local development on Rancher Desktop, kind or k3s
generated/                git-ignored: local secrets, customisations values file
```

## Rules

- **Secrets never enter the repo.**
  - Never read or print `.env` files, including the service repos' local ones, or anything in `generated/`.
  - No secret has a value in `values.yaml`. Generated credentials go to `generated/` or Kubernetes Secrets, and are never logged.
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
| `stack-platform-engineer` | Helm, Tilt, Keycloak, init/provision jobs, CI. Defined in this repo |
| `docker-expert` | Dockerfiles and image hardening (A1, N1) |
| `laravel-senior-backend` | API tickets A1–A4 |
| `senior-python-developer` | NLP ticket N1, somop changes in S5 |
| `omop-specialist` | Vocabulary build (S3), synthetic data (S5) |
| `cohort-discovery-specialist` | BUNNY, collections and federated-query questions |
| `code-reviewer`, `web-appsec-senior`, `qa-tester` | Reviews, security review (H1, A4, S2) and testing |

`bunny-expert` isn't copied, because it hard-codes local paths. Install it globally from `tech-team-claude-skills` if you need it.

## Commands

```bash
git submodule update --init           # services at their pinned tags
scripts/local-secrets.sh              # writes generated/secrets.values.yaml once; Tilt runs it too
scripts/customisations-values.sh      # customisations/ -> generated/customisations.values.yaml; Tilt runs it too
helm lint charts/cohort-discovery -f generated/secrets.values.yaml -f generated/customisations.values.yaml
python3 -m unittest discover -s tests/provision   # provisioner tests, standard library only
export GITHUB_TOKEN=$(gh auth token)  # the API image build needs it until A1
tilt up                               # the whole stack, local contexts only
tilt up -- --api-port=18100           # other host ports or --keycloak=false; or set them in tilt_config.json (git-ignored)
tilt down                             # keeps the MySQL, Keycloak and synthetic volumes
mkdocs build --strict -d /tmp/site    # the docs site; pip install -r requirements-docs.txt first
```

`helm template` output contains the secrets, so don't print it. To inspect a render, pass a placeholder secrets file instead of `generated/secrets.values.yaml`.

Later tickets add to this section. For the services' own commands, see their `CLAUDE.md`.

## Shared context

@../cohort-discovery-service-claude-helpers/CLAUDE.md
