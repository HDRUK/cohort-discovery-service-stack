# S1. Stack: Compose core

**Repo:** this one · **Depends on:** S0, A2 · **Decisions:** D4, D12, D15

## Goal
`make up` brings up a working standalone install on localhost with the minimal vocabulary, so the admin from `.env` can sign in.

## Context
- Start from `cohort-discovery-service-evaluator/compose.yaml`: mysql with an OMOP init SQL, `api-init` and standalone env. Its `init/api-init.sh` is the model for the init step.
- Start order (`cohort-discovery-service-docs/.../running.md`): MySQL and Redis, then API migrations, then NLP, then API, then web.

## Services
| Service | Image | Notes |
|---|---|---|
| mysql | `mysql:8` | `local_infile=1` for S3. App and `omop` databases created by an init SQL. Volume. |
| redis | `redis:7` | Horizon needs it. |
| api-init | api | `php artisan app:bootstrap`, run once. Everything else waits on `service_completed_successfully`. |
| api | api | `APP_OPERATION_MODE=standalone`, `REBUILD_DB=0`. Mounts `config/claims-mapping.json` (`CLAIMS_MAPPING_PATH`) and the Passport keys volume. |
| queue | api | Horizon on its own (`START_HORIZON` off in `api`) or `queue:work`. Pick whichever start-up allows without changing `start.sh`. |
| scheduler | small cron image | Calls `/api/v1/services/caller/*` with the bootstrap service account (D15). Mirror the intervals in `cohort-discovery-infrastructure`'s Cloud Scheduler config. |
| nlp | nlp | `DB_NAME` set to the app DB, `OMOP_DB_NAME` to the vocab DB. Mounts `config/nlp/`. |
| web | web | Built with `scripts/build-web.sh` (W3) or a GHCR tag. `API_BASE_URL=http://api:8080`. |

All variables come from `.env`. Pin every image tag; don't use `latest`.

## Done when
- From a clean clone: `cp .env.example .env`, edit it, `make up`.
- All services are healthy, the admin can sign in at `http://localhost:3000`, and the NLP `/health/ready` returns 200.
- `make down && make up` keeps the data.

## Verification
- Run the above twice: from clean, then restarted.
- `docker compose ps` shows everything healthy.
- `curl` the API login.
