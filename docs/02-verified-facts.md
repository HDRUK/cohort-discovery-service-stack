# Verified facts (2026-11-11)

The state of each repo when the plan was written. Paths are relative to `~/Software/Daphne/`. Add to this file when a ticket finds something new. If you find an entry is wrong, correct it here.

## Web (`project-daphne-web`)

- **Dockerfile**
  - Single stage on `node:24-alpine`; runs `npm install`, `npm run build`, `next start`.
  - No `output: 'standalone'` and no non-root user.
- **Build args** (`.github/workflows/build-args.yaml`, values from GitHub environment vars): `API_BASE_URL`, `APPLICATION_MODE`, `NEXT_PUBLIC_LOGIN_URL`, `NEXT_PUBLIC_TASK_URL`, `NEXT_PUBLIC_USE_DEBUG_LOGS`, `NEXT_PUBLIC_USE_EXAMPLE_QUERY`. Integrated mode uses the `INT_*` copies.
- **`NEXT_PUBLIC_SUPPORT_URL`** is read in `SupportPopOut.tsx` but is not passed as a build arg.
- **Effectively build-time:** `APPLICATION_MODE` is read into module-level consts, e.g. `src/app/layout.tsx` and `admin/(tabs)/layout.tsx` (`ADMIN_TABS`). With `cacheComponents`, prerendered output keeps the value from build time.
- **Read at runtime (server):** `API_BASE_URL` (`src/server/api.ts`), `HIDE_NAV`, `COOKIE_TOKEN_NAME`, `DEFAULT_*` and `CONFIG_*` (`src/providers/ServerDefaultProvider.tsx`).
- **Branding**
  - The `@branding/*` alias points at `branding/`, which holds `branding.config.ts`, `theme.ts`, `assets/logo.svg` and `legal/*.mdx`. It's resolved at build time.
  - The defaults are HDR UK's.
  - Gaps:
    - `src/utils/getCopyrightText.ts:10` hard-codes "HDR UK" and ignores `branding.copyrightHolder`.
    - Favicons are in `src/app/favicon.ico` and `src/app/icon.svg`, not in `branding/`.
    - `@hdruk/ui` is a hard dependency.
    - The HDR UK chrome is controlled by `useHdrukChrome` (the `hdruk-uk-theme` flag plus `hdrukChromeInStandalone`).
- **Workgroups**
  - Actions in `src/actions/workgroup/`: `createWorkgroup`, `updateWorkgroupMembers`, `removeUsersFromWorkgroup`, `addCollectionsToWorkgroup`, `removeCollectionsFromWorkgroup`.
  - UI in `src/app/(protected)/(admin)/admin/(tabs)/components/Workgroups{Left,Middle,Right}Panel.tsx`, using `src/modules/CreateWorkgroup` and `src/modules/UpdateWorkgroup`. Only the users table in the middle panel is gated, on `manageWorkgroupsInternal`.
  - `src/hooks/useFeatures.ts:45`: `manageWorkgroupsInternal = isStandalone || flags.ManageWorkgroupsInternally`, so standalone mode is always editable.
- **Feature flags** come from the API (`src/server/data/features.ts`) and are merged with `DEFAULT_FLAGS` in `useFeatures`. They only load on protected pages.
- **CI**
  - `dev_deployment.yaml`: a push to `dev` builds and deploys integrated. `workflow_dispatch` (any branch) or `[deploy-standalone]` in the commit message deploys to `dev-standalone`.
  - Building, pushing and deploying run in the external `HDRUK/github-actions-templates`, which pushes to GCP Artifact Registry.
  - `chart/cohort-web/` contains only `Chart.yaml`.

## API (`project-daphne-api`)

- **Outsiders can't build it.** `composer.json` pulls five private VCS packages: `hdruk/claims-based-access-control`, `laravel-search-and-filter`, `laravel-plugin-core`, `laravel-workflow-states` and `laravel-messenger`. The build needs a `github_token` BuildKit secret.
- **Dockerfile**
  - Built on `dunglas/frankenphp:php8.4`.
  - `ENV REBUILD_DB=1`, and it copies `init/php.development.ini` as `php.ini`.
  - `COPY .` with no `.dockerignore`, so a local build bakes in `.env`, `storage/oauth-*.key`, `vendor` and `node_modules`.
  - Octane listens on `$PORT`, default 8080.
- **`docker/start.sh`**
  - In `local`/`dev` with `REBUILD_DB=1`, it runs `migrate:fresh --seed --seeder=DevDatabaseSeeder`, which wipes the database. Otherwise it runs `migrate` (`--force` outside dev).
  - Then `deploy:run` (the steps in `database/deployment-steps/`), the caches and `config:cache`, Horizon when `START_HORIZON=1`, and Octane.
  - It doesn't create Passport keys, the personal access client or an admin, and doesn't load OMOP.
- **Mode:** `APP_OPERATION_MODE` (`config/system.php`), default `standalone`. Standalone means a local login (`POST /api/auth/login`, RS256 JWT signed with the Passport keys), plus OIDC SSO through `config/sso.php` with one env-wired provider `default` (`SSO_DEFAULT_*`).
- **Claims**
  - `config/claimsaccesscontrol.php`: `workgroup_mappings` and `role_mappings` are hard-coded arrays (`local => IdP value`). The sync policy is set by env: `CLAIM_SYNC_{WORKGROUPS,ROLES,CUSTODIANS}` (`never`, `first_login` or `always`), `*_AUTHORITATIVE`, `CLAIM_SYNC_ENSURE_DEFAULT_*` and `CLAIM_PROVISION_DEFAULTS_ON_CREATE`.
  - The claim names are set in `config/sso.php` (`SSO_DEFAULT_{WORKGROUPS,ROLES,CUSTODIANS}_CLAIM`).
  - `app/Services/Sso/ClaimMapper.php` syncs on SSO login. It only maps to existing workgroup and role rows, and matches custodians by name.
  - There's no "managed externally" flag.
- **Seeders**
  - `DatabaseSeeder` includes `CustodianSeeder`, which truncates the table and creates 10 fake custodians.
  - `StandaloneDemoSeeder` creates demo users from `DEMO_USER_*`.
  - `admin-user:import` (`app/Console/Commands/ImportAdminUsers.php:54`) hard-codes the "Health Data Research UK" custodian.
  - `custodian:create {name}` is idempotent. `service-account:create {name}` prints the credentials once.
  - Nothing creates an admin from env.
- **Hosts and collections** (all under `decode.jwt`, authorised by policy)
  - `POST /api/v1/collection_hosts` `{name, query_context_type: "bunny", custodian_id}`. The response is the only time `client_id` and `client_secret` are returned. They are the stored hashed values, and BUNNY uses them as-is for `TASK_API_USERNAME` and `TASK_API_PASSWORD`.
  - `POST /api/v1/custodians/{custodianPid}/collections` `{name, description, type, host_id, …}`. The collection `pid` is BUNNY's `COLLECTION_ID`. `PUT /v1/collections/{id}/transition_to` changes its state.
  - BUNNY polls `/api/v1/task/*` with `CollectionHostBasicAuth`.
- **Scheduled work** is external: `POST /api/v1/services/caller/{command}` with service-account basic auth. The commands are `distributions-collector`, `task-cleanup-job`, `collection-no-activity-monitor` and `collection-task-backlog-monitor`. Production triggers them from Cloud Scheduler (`cohort-discovery-infrastructure`).
- **Vocabulary**
  - The `omop` connection uses `DB_OMOP_*` and falls back to `DB_*`. It's MySQL only.
  - Full set: `app:import-omop-vocabs {path} --create-schema --bulk --truncate` (`ImportOmopVocabs.php`), which needs `local_infile=1`. Then `concepts:populate-ancestors`.
  - Minimal set: `migrate --database=omop --path=database/migrations_omop`, then `db:seed --class=MinimalOmopSeeder`. The CSVs ship in the repo.
- **Settings to look at before release:**
  - `JWT_SECRET` defaults to an insecure value (`config/api.php`).
  - The mail default is `log`.
  - Slack alerts and activity logs are on by default.

## NLP (`project-daphne-nlp`)

- Dockerfile on `python:3.11-slim`, uvicorn on `${PORT:-5001}`, `/health/ready` returns 503 while concepts load.
- **Env**
  - `DB_HOST/PORT/NAME/USER/PASS`: `DB_NAME` is the **app** DB, because it reads `latest_distributions`.
  - `OMOP_DB_NAME`: the vocabulary DB (`concept_synonym`, `concept_ancestor`).
  - `RULES_PATH`, `MAPPINGS_PATH` (mountable), `RESOLVER_BACKEND`, `MEDCAT_URL`.
- The docs mention `OMOP_VIEW`, which the code doesn't use.

## somop and BUNNY

- **somop** is a pip CLI with no Dockerfile.
  - `somop run` writes `<out_dir>/docker-compose.run.yaml` (`somop/compose.py`) with `postgres:16`, `omop-lite` (loader) and `ghcr.io/health-informatics-uon/hutch/bunny:edge`, then runs `docker compose up`.
  - `somop multi run` does the same for several datasets.
  - It needs `--collection-id`, `--api-url` and the host's `--api-username`/`--api-password`.
- **omop-lite** loads Postgres or MSSQL only. It can't load the API's MySQL vocabulary.
- `project-daphne-bunny-config/omop/` has a MySQL Athena loader (`Dockerfile` on `mysql`, `loader.sh`), but its compose file mounts a hard-coded personal path.
- **Committed secrets and paths:** `somop/docker-compose.multi.yaml` and `somop/out/*/docker-compose.run.yaml` contain BUNNY task API credentials and absolute `/Users/...` paths (see H1).

## This repo (S0)

- Submodule pins: web `v1.12.0`, api `v1.17.0`, nlp `v1.9.1`, the latest tags on 2026-11-11.
- `config/nlp/` is copied from nlp `v1.9.1`.
- `cohort-discovery-service-evaluator/init/api-init.sh` runs `migrate:fresh`, so it can't be reused as-is for an idempotent init Job.

## Prior art to reuse

- `cohort-discovery-service-evaluator/compose.yaml`: mysql (with `init/mysql/01-omop.sql`), `api-init` (`init/api-init.sh`), nlp and api in standalone mode, with mounted Passport keys. It has no web and no Keycloak.
- `cohort-discovery-service-docs/docs/developers/deploying/`:
  - `running.md`: start order, required env, and the named seeders to use instead of a bare `db:seed`.
  - `examples/keycloak.md`: realm `cohort-discovery-service`; groups named after the `workgroup_mappings` values; realm roles `GENERAL_ACCESS`, `SYSTEM_ADMIN` and `CUSTODIAN`; a confidential client with PKCE; flat `groups` and `roles` mappers on the ID token; and `KC_HOSTNAME` resolvable from both the browser and the API container.
  - `claim-mapping.md` and `limitations.md`: only Keycloak is tested end to end, and Entra and Google are blocked by API issue #350.
  - `carrying-changes.md`: how upgrades carry local changes is left open, and this repo answers it.
- `cohort-discovery-infrastructure/cohortdiscovery*/locals.tf` (`env_vars`, around line 629): the env set production actually uses.
