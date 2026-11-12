# S1. Stack: Helm core and Tilt

**Repo:** this one · **Depends on:** S0 (A2 when it lands) · **Decisions:** D4, D12, D15

## Goal
`tilt up` brings up a working standalone install on a local cluster with the minimal vocabulary, so a seeded admin can sign in at `http://localhost:3000`. `helm install` with the same chart gives the same result without Tilt.

## Context
- The service repos' `chart/` folders contain only `Chart.yaml`, so the umbrella chart writes its own templates.
- `cohort-discovery-service-evaluator/init/api-init.sh` shows the init commands, but it uses `migrate:fresh`, which isn't idempotent. Use `migrate --force` and the named seeders from `cohort-discovery-service-docs/.../running.md`, never the bare `db:seed`.
- Until A2's `app:bootstrap` exists, the init Job runs those commands itself, plus Passport keys and the personal access client. Swap to `app:bootstrap` when A2 lands.
- The API image needs a GitHub token to build (private composer packages, until A1). Tilt passes it as a BuildKit secret from the environment (e.g. `GITHUB_TOKEN=$(gh auth token)`). It is never written to disk or into values.
- Start order: MySQL and Redis, then the init Job, then NLP and API, then web.
- Config files the chart reads live in `charts/cohort-discovery/files/`, overridable through values (D17). Move `config/nlp/` there, and `config/keycloak/` and `config/synthetic/` placeholders with it. Update the layout in `CLAUDE.md`, `docs/getting-started.md` and the S0 ticket to match.
- S0's Tiltfile skips `k8s_yaml` while the chart renders nothing. Remove that guard once the chart has resources.

## In the chart
| Component | Kind | Notes |
|---|---|---|
| mysql | StatefulSet + PVC | Official `mysql:8.x` image, pinned. `local_infile=1` for S3. The app and `omop` databases are created by an init SQL in a ConfigMap. Not a Bitnami chart. |
| redis | StatefulSet | Official `redis:7.x` image, pinned. |
| api-init | Job (Helm hook post-install/post-upgrade) | Migrations, seeders, Passport keys into a Secret, minimal vocabulary. Idempotent. |
| api | Deployment | `APP_OPERATION_MODE=standalone`, `REBUILD_DB=0`. Passport keys from the Secret. |
| queue | Deployment | Horizon or `queue:work`, whichever `start.sh` allows without changing it. |
| scheduler | CronJobs | Call `/api/v1/services/caller/*` with the bootstrap service account (D15). Intervals from `cohort-discovery-infrastructure`'s Cloud Scheduler config. |
| nlp | Deployment | `DB_NAME` set to the app DB, `OMOP_DB_NAME` to `omop`. `files/nlp/` mounted from a ConfigMap. Readiness on `/health/ready`. |
| web | Deployment | Built from `services/web` by Tilt. `API_BASE_URL` is the in-cluster API service. |

## Secrets
- No secret has a value in `values.yaml`.
- `scripts/local-secrets.sh` writes random values to `generated/secrets.values.yaml` (git-ignored) if the file doesn't exist, and never prints them. Tilt runs it on load and passes the file to Helm. Someone without Tilt runs it once and passes `-f generated/secrets.values.yaml`.
- Helm's `lookup` can't be used for this, because Tilt renders with `helm template`, which has no cluster access.

## Tilt
- `docker_build` for web, API and NLP from `services/*`. Rancher Desktop's Docker runtime means no registry is needed.
- Port-forwards: web 3000, API 8100, NLP 5001.
- PVCs carry `tilt.dev/down-policy: keep`, so `tilt down` keeps the data.

## Done when
- `tilt up` from a clean clone: every resource goes green, the admin can sign in at `http://localhost:3000`, and the NLP `/health/ready` returns 200.
- `tilt down && tilt up` keeps the data.
- `helm install` with `generated/secrets.values.yaml` gives the same result.

## Verification
- Run it twice: from clean, then restarted.
- `curl` the API login.
- `helm lint` and `helm template | kubeconform`.
