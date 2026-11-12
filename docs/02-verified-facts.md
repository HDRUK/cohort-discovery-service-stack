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

- **Building it needs a GitHub token.** `composer.json` pulls five VCS packages: `hdruk/claims-based-access-control`, `laravel-search-and-filter`, `laravel-plugin-core`, `laravel-workflow-states` and `laravel-messenger`. All five were public on 2026-11-12 (H1), but the Dockerfile still reads a `github_token` BuildKit secret unconditionally (line 74), so a build without one fails. Any GitHub token should work now that the packages are public; not tested.
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
- **SSO** (checked 2026-11-12 at `v1.17.0`): `OidcDiscoveryService::assertUrlBelongsToIssuer` rejects any discovered `authorization_endpoint`, `token_endpoint`, `jwks_uri`, `userinfo_endpoint` or `end_session_endpoint` whose scheme, host or port differs from `SSO_DEFAULT_ISSUER`. `SSO_DEFAULT_DISCOVERY_URL` only moves the discovery document itself. So the API pod must reach the IdP at the same URL as the browser.
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
  - With `SYNTHETIC=true` it loads its own bundled synthetic data, with no CSVs from somop. `AndyRae/cd-build` uses `omop-lite:0.9.4` this way, behind `hutch/bunny:1.9.9` availability (`TASK_API_TYPE=a`) and distribution (`b`) daemons.
- **Service repos were renamed** to `HDRUK/cohort-discovery-service-{api,web,nlp}`. The `project-daphne-*` names still redirect.
- **Visibility on 2026-11-12 (H1):** web, API, NLP, somop and the five `hdruk/*` composer packages are already public. `project-daphne-bunny-config` and this repo are private. Anything committed to the public repos, including their history, has already been published.
- `project-daphne-bunny-config/omop/` has a MySQL Athena loader (`Dockerfile` on `mysql`, `loader.sh`), but its compose file mounts a hard-coded personal path.
- **Local secrets and paths:** `somop/docker-compose.multi.yaml` and `somop/out/*/docker-compose.run.yaml` in a local checkout contain BUNNY task API credentials and absolute `/Users/...` paths, but neither has ever been committed: `out/` is git-ignored and the multi file is generated. Committed credentials were in `docker/run-bunny.yaml` and `configs/multi_example.yaml` (H1).

## This repo (S0)

- Submodule pins: web `v1.12.0`, api `v1.17.0`, nlp `v1.9.1`, the latest tags on 2026-11-11.
- `charts/cohort-discovery/files/nlp/` is copied from nlp `v1.9.1` (in `config/nlp/` until S1 moved it, D17).
- `cohort-discovery-service-evaluator/init/api-init.sh` runs `migrate:fresh`, so it can't be reused as-is for an idempotent init Job.

## Learnt running the stack (S1, 2026-11-11)

Checked against api `v1.17.0`, web `v1.12.0` and nlp `v1.9.1` on Rancher Desktop (k3s 1.31, Docker 26.1.5), Tilt 0.33.14 and Helm 3.17.1.

- **API**
  - Passport keys can come from env: `PASSPORT_PRIVATE_KEY` and `PASSPORT_PUBLIC_KEY` (`config/passport.php`). `LocalPersonalAccessTokenService.php` and `DecodeJwt.php` use them before falling back to `storage/oauth-*.key`. Production sets them from Secret Manager (`cohortdiscovery*/locals.tf`).
  - `docker/start.sh` defaults `PORT` to 8080; the Dockerfile's `EXPOSE 8100` is misleading. The stack sets `PORT=8100`.
  - `START_HORIZON` (default 1) runs Horizon in the background of the API container. The stack sets `START_HORIZON=0` and runs `php artisan horizon` in its own `queue` Deployment. `config/horizon.php` has supervisors for `APP_ENV` `production`, `preprod`, `dev` and `local`. In `production`, the Horizon dashboard is closed unless `HORIZON_SECRET` is set (`HorizonServiceProvider.php`).
  - The image's `php.development.ini` has `display_errors` on. Any PHP CLI script prints a deprecation notice from `vendor/darkaonline/l5-swagger/src/helpers.php:15` to **stdout** before its own output, so scripts that parse output must send errors to stderr (`ini_set('display_errors', 'stderr')`).
  - Seeder repeat behaviour:
    - `WorkgroupSeeder` and `RolesAndPermissionsSeeder` create rows without checking, so they can't run twice.
    - `StateSeeder` (`firstOrCreate`), `FeatureSeeder` (skips existing flags, purges retired ones) and `PersonalAccessClientSeeder` (exists check) can.
    - `MinimalOmopSeeder` upserts 3,886 concept rows (3,884 distinct) and 4,031 `concept_ancestor` rows.
    - `StandaloneDemoSeeder` truncates `custodians`, `users`, `user_has_roles`, `user_has_workgroups` and `custodian_has_users`. It then creates "Demo Custodian", "Demo Network", an admin from `DEMO_USER_*` (role `admin`, workgroup `ADMIN`) and a researcher from `DEMO_RESEARCHER_*` (role `user`, workgroup `UK-RESEARCH`). If those are unset, `config/system.php` falls back to `demo.user@domain.com`, `demo.researcher@domain.com` and a fixed weak password.
  - `deploy:run` on a fresh database runs nine steps, which materialise `latest_distributions` and run `FeatureSeeder`.
  - `ServiceAccount` (`app/Models/ServiceAccount.php`) has `client_id` fillable and `client_secret` cast to `hashed`, so an account can be created with credentials chosen in advance.
  - `POST /api/v1/services/caller/{command}` returns 200 `{"message":"success","data":{"data":null}}` for all four commands on an empty install. The `throttle:polling` limit is `API_RATE_LIMIT` per minute per IP.
  - `POST /api/auth/login` with `{email, password}` returns 200 and an `access_token` (Bearer). A wrong password returns 401. `GET /up` is the health check.
  - PHP's `pdo_mysql` and NLP's MySQL connector both work against `mysql:8.4` with its default `caching_sha2_password`.
- **Cloud Scheduler:** all four jobs run every minute (`* * * * *`, `Etc/UTC`) in dev, preprod and prod (`cloud_scheduler` in each `locals.tf`).
- **Web**
  - The Dockerfile declares `ARG`s but doesn't turn them into `ENV`. They're still visible to `RUN npm run build`, which is how `APPLICATION_MODE` reaches the build.
  - In standalone mode `NEXT_PUBLIC_LOGIN_URL` isn't needed: `getOrganisationUrl()` (`src/config/externalLinks.ts`) falls back to `branding.links.organisation`.
  - Sign-in is server side: the `standaloneSignIn` server action posts to `${API_BASE_URL}/api/auth/login` (`src/lib/apiClient.ts`, read at run time) and sets an httpOnly `token` cookie (`src/lib/authCookie.ts`). The cookie is `secure` when `NODE_ENV=production`, which the image sets. Chrome and Firefox treat `http://localhost` as secure, so they should keep the cookie; no browser was tested in S1, and Safari may refuse it.
  - Every `/login` request logs `Could not load sign-in methods: … During prerendering, fetch() rejects when the prerender is complete`. The page still renders the password method, so it's log noise from the runtime prerender. The stack's probes use `/favicon.ico` to avoid it.
  - The `Secure` flag is upstream issue [cohort-discovery-service-web#245](https://github.com/HDRUK/cohort-discovery-service-web/issues/245), open on 2026-11-12. It also blocks sign-in over plain `http` on any host other than `localhost`.
  - The cookie name comes from `COOKIE_TOKEN_NAME` at run time (`src/config/internals.ts`, default `token`). The stack sets `cds_stack_token` (`web.cookieTokenName`) so it doesn't share a sign-in with a development web app on `localhost`, whose token the stack's API rejects with `Token signature mismatch`.
  - SSO logout (`src/app/api/auth/logout/route.ts`) redirects the browser to `${API_BASE_URL}/api/auth/sso/<provider>/logout`, using the run-time `API_BASE_URL`, so under SSO that value must work in the browser.
  - Production also sets `SESSION_SECRET` for the web, but nothing in `src/` reads it at `v1.12.0`.
- **NLP:** it reaches `/health/ready` 200 with every capability loaded, even when `latest_distributions` is empty.
- **Tilt**
  - `docker_build(..., secret=['id=github_token,env=GITHUB_TOKEN'])` works in 0.33.14, so the token never touches disk.
  - CronJobs are Tilt workloads: each gets its own resource and can't be grouped with `objects=`.
  - `helm()` renders Helm hook Jobs as ordinary resources.
  - `kubectl create job --from=cronjob/…` copies Tilt's labels, so `tilt down` deletes such Jobs too.
  - Built images are identical to plain `docker build` with the same arguments: the commands in `getting-started.md` hit the same cache.
- **Local port clash:** a developer machine may already run the web, API and NLP dev servers on `*:3000`, `*:8100` and `*:5001`, with somop BUNNY containers polling the host's 8100. Tilt's forwards bind `127.0.0.1`, so while the stack runs, some of that traffic reaches the cluster (the API logged `GET /api/v1/task/nextjob/<uuid>` from `127.0.0.1`: "Client cannot be found").

## Prior art to reuse

- `cohort-discovery-service-evaluator/compose.yaml`: mysql (with `init/mysql/01-omop.sql`), `api-init` (`init/api-init.sh`), nlp and api in standalone mode, with mounted Passport keys. It has no web and no Keycloak.
- `cohort-discovery-service-docs/docs/developers/deploying/`:
  - `running.md`: start order, required env, and the named seeders to use instead of a bare `db:seed`.
  - `examples/keycloak.md`: realm `cohort-discovery-service`; groups named after the `workgroup_mappings` values; realm roles `GENERAL_ACCESS`, `SYSTEM_ADMIN` and `CUSTODIAN`; a confidential client with PKCE; flat `groups` and `roles` mappers on the ID token; and `KC_HOSTNAME` resolvable from both the browser and the API container.
  - `claim-mapping.md` and `limitations.md`: only Keycloak is tested end to end, and Entra and Google are blocked by API issue #350.
  - `carrying-changes.md`: how upgrades carry local changes is left open, and this repo answers it.
- `cohort-discovery-infrastructure/cohortdiscovery*/locals.tf` (`env_vars`, around line 629): the env set production actually uses.
