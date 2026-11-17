# Verified facts (2026-11-11)

The state of each repo when the plan was written. Paths are relative to `~/Software/Daphne/`. Add to this file when a ticket finds something new. If you find an entry is wrong, correct it here.

## Web (`project-daphne-web`)

- **Dockerfile**
  - Single stage on `node:24-alpine`; runs `npm install`, `npm run build`, `next start`.
  - No `output: 'standalone'` and no non-root user.
- **Build args** (`.github/workflows/build-args.yaml`, values from GitHub environment vars): `API_BASE_URL`, `APPLICATION_MODE`, `NEXT_PUBLIC_LOGIN_URL`, `NEXT_PUBLIC_TASK_URL`, `NEXT_PUBLIC_USE_DEBUG_LOGS`, `NEXT_PUBLIC_USE_EXAMPLE_QUERY`. Integrated mode uses the `INT_*` copies.
- **`NEXT_PUBLIC_SUPPORT_URL`** is read in `SupportPopOut.tsx` but is not passed as a build arg.
- **Build time and run time** (checked 2026-11-12 at `v1.12.0` by running the built image; the detail is in [web-variables.md](web-variables.md)):
  - A `NEXT_PUBLIC_*` variable set at build time is inlined into browser and server chunks, and run-time changes are ignored. One unset at build time stays `process.env.X`: the server reads the run-time value and the browser gets `undefined`.
  - Server-only variables, including the module-level `APPLICATION_MODE` consts (`src/app/layout.tsx`, `admin/[tabId]/page.tsx` `TABS`), are read at run time on every route rendered per request. Only the five fully static routes (`/403`, `/terms-and-conditions`, `/about/privacy-policy`, `/user-not-found`, not-found) keep build-time values. The earlier note that `APPLICATION_MODE` is "effectively build-time" was wrong, and `ADMIN_TABS` in `admin/(tabs)/layout.tsx` doesn't exist at `v1.12.0`.
  - `Custom403.tsx` is a client component reading `APPLICATION_MODE`, which is always `undefined` in the browser.
- **Read at runtime (server):** `API_BASE_URL` (`src/lib/apiClient.ts`, plus the download and logout route handlers), `HIDE_NAV`, `COOKIE_TOKEN_NAME`, `DEFAULT_*` and `CONFIG_*` (`src/providers/ServerDefaultProvider.tsx`).
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
  - UI in `src/app/(protected)/(admin)/admin/[tabId]/components/Workgroups{Left,Middle,Right}Panel.tsx` (path at `v1.12.0`), using `src/modules/CreateWorkgroup` and `src/modules/UpdateWorkgroup`. Only the users table in the middle panel is gated, on `manageWorkgroupsInternal`.
  - `src/hooks/useFeatures.ts:45`: `manageWorkgroupsInternal = isStandalone || flags.ManageWorkgroupsInternally`, so standalone mode is always editable.
- **Feature flags** come from the API (`src/actions/getFeatureFlags.ts` at `v1.12.0`) and are merged with `DEFAULT_FLAGS` in `useFeatures`. They only load on protected pages.
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
- `customisations/nlp/` is copied from nlp `v1.9.1`, byte-identical (in `config/nlp/` until S1 moved it to `charts/cohort-discovery/files/nlp/` under D17, then moved again under D21). The NLP falls back to the copies in its image (`rules_engine.py`: `RULES_PATH` defaults to `rules.json`, `MAPPINGS_PATH` to `mappings.json`, relative to `/app`) when the env isn't set.
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
    - `StandaloneDemoSeeder` truncates `custodians`, `users`, `user_has_roles`, `user_has_workgroups` and `custodian_has_users`. It then creates "Demo Custodian", "Demo Network", an admin from `DEMO_USER_*` (role `admin`, workgroup `ADMIN`) and a researcher from `DEMO_RESEARCHER_*` (role `user`, workgroup `UK-RESEARCH`). If those are unset, `config/system.php` falls back to `demo.user@domain.com`, `demo.researcher@domain.com` and a fixed weak password. The stack no longer runs it (see S2 below).
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

## Learnt wiring Keycloak (S2, 2026-11-12)

Checked against api `v1.17.0`, web `v1.12.0` and `quay.io/keycloak/keycloak:26.8.2` on Rancher Desktop, with the stack on host ports 13000, 18100 and 8180.

- **Hostname: what worked.** Keycloak listens on `KC_HTTP_PORT=<port>` with `KC_HOSTNAME=http://localhost:<port>`, and Tilt forwards `<port>:<port>`. The API pod has an `alpine/socat:1.8.1.3` container (`tcp-listen:<port>,fork,reuseaddr tcp-connect:<keycloak service>:<port>`), so `http://localhost:<port>` resolves to Keycloak from the browser, from `curl` in the API container and from Laravel's `Http` client. `SSO_DEFAULT_ISSUER` is that URL, and discovery, token, JWKS and logout all pass `assertUrlBelongsToIssuer`. The queue worker and init Job don't talk to Keycloak; the scheduler is `curl` only.
- **The SSO button's link** comes from `GET /api/auth/methods` (`AuthMethodsController`), which builds `redirect_url` with Laravel's `url()`, so it uses the host the request came in on, not `APP_URL`. The web calls it server-side (`src/actions/standalone/getAuthMethods.ts`) through its run-time `API_BASE_URL`, so with the in-cluster Service URL the button would point at `http://cohort-discovery-api:8100`. Under SSO the chart sets the web's `API_BASE_URL` to `api.appUrl` and adds a socat container in the web pod forwarding that port to the API Service. Node's `fetch` reaches it on `localhost`. The SSO logout redirect (`src/app/api/auth/logout/route.ts`) then also points at the browser URL.
- **Web callback.** `SSO_FRONTEND_CALLBACK_URL=<web>/auth/sso/callback` is a page (`src/app/(public)/auth/sso/callback/page.tsx`) that redirects to the route handler `/api/auth/sso/callback` through a client-side `NEXT_REDIRECT` in the RSC payload: the HTTP response is 200, not 3xx. A browser follows it; `curl` has to follow it by hand. The route handler exchanges the code server-side through `API_BASE_URL` and sets the cookie.
- **Keycloak realm import placeholders.** At 26.8.2, `--import-realm` replaces `${VAR}` (and `${VAR:default}`) with environment variables, but leaves `${env.VAR}` as literal text. The stack's realm uses `${CDS_*}` for the client secret, user passwords and the API and web URLs. Import happens only when the realm doesn't exist (`Strategy: IGNORE_EXISTING`), so on a kept volume later changes are ignored.
- **`dev-file` storage** is `/opt/keycloak/data/h2/keycloakdb.mv.db`. A PVC mounted there on k3s `local-path` works without a `securityContext`, and the realm survives a pod restart.
- **Health** is on the management port 9000 (`/health/started`, `/health/ready`, `/health/live`) with `KC_HEALTH_ENABLED=true`. The image has no `curl`; the chart probes with `httpGet`.
- **A user with no groups gets no `groups` claim.** Keycloak's group-membership mapper omits the claim rather than sending `[]`, and `ClaimMapper::claimValues` reads an absent claim as "IdP not speaking", so an authoritative sync leaves workgroups alone. Removing one of several groups does remove that workgroup (checked: `uk-industry` added, then removed). Removing the last group doesn't.
- **SSO sign-in as a seeded user** links by verified email (`SsoUserResolver`) and adds a `user_identities` row. `CLAIM_SYNC_ENSURE_DEFAULT_WORKGROUP` adds `DEFAULT`, and the role floor adds `user`, so the seeded admin ends up with `ADMIN`+`DEFAULT` and `admin`+`user`. With `SSO_DEFAULT_CUSTODIANS_CLAIM=groups` and an authoritative sync, the admin keeps "Demo Custodian" only because the realm has a group with that exact name.
- **Logout** works end to end: web `/api/auth/logout` → API `/api/auth/sso/default/logout?ticket=…` → Keycloak `end_session_endpoint` with `id_token_hint` → 302 to `<web>/login`, with `post.logout.redirect.uris` set to `<web>/login` on the client.
- **Login theme (2026-11-13).** At 26.8.2 a theme mounted at `/opt/keycloak/themes/<name>/login/` with `parent=keycloak.v2` is picked up by `start-dev` without a rebuild. Its `styles` list replaces the parent's, so it must name `css/styles.css` again; that file still resolves from the parent. `favIcon=img/icon.svg` with `favIconType=image/svg+xml` gives `<link rel="icon" type="image/svg+xml">`, so an SVG favicon needs no `.ico`. The header is `#kc-header-wrapper`, filled from `realm.displayNameHtml`. The stock `.pf-v5-c-login__container` has a fixed `34rem` column, which overflows phone screens. A realm whose `loginTheme` isn't installed logs `Failed to find LOGIN theme <name>, using built-in themes` and still renders.
- **Claims mapping is one-to-one or one-to-many, never many-to-one (2026-11-13, at `v1.17.0`; fixed by DP-1254, below).** `ClaimResolver::localNames` filters `workgroup_mappings` / `role_mappings` (`local => IdP value`) for values in the claim and returns the keys. Keys are unique, so a local workgroup or role matches exactly one IdP value, while one IdP value can map to several local names. Matching is case-insensitive. Local names must be existing workgroups or roles (`WorkgroupSeeder`: ADMIN, DEFAULT, CUSTODIAN, NON-UK-INDUSTRY, NON-UK-RESEARCH, OTHER, UK-INDUSTRY, UK-RESEARCH, NHS-SDE; roles `admin`, `custodian`, `user`).
- **API pinned to DP-1254 (`b257363`, 2026-11-13).** `v1.17.0..b257363` is four `dev` commits (Laravel 13 with PHP `^8.4`, three migrations, `TASK_A/B_TIMEOUT_SECONDS` with defaults, the private `hdruk/*` packages dropped from `composer.json`) plus DP-1254. DP-1254: `ClaimResolver::localNames` takes a string or a list per mapping, and `WorkgroupSeeder` seeds `config('workgroups.seed')`, upper-cased, skipping names that exist in any case. `config/claimsaccesscontrol.php` is unchanged from `v1.17.0`. The Dockerfile still requires the `github_token` secret. `ClaimResolver::workgroupIdsForNames` returns nothing for a missing workgroup, so `ensure_default` and `defaults_on_create` do nothing for `DEFAULT` when it isn't seeded. The admin role bypasses workgroups (`Collection::scopeVisibleToUser`), and custodian members see their collections through `custodian_id`. The web names `DEFAULT` (dataset pre-selection for default-only users) and `NHS-SDE` (access banner).
- **Password sign-in switch (2026-11-13, `b257363`).** `config('auth.password_login.enabled')` (`AUTH_PASSWORD_LOGIN_ENABLED`) is read by `App\Services\Authentication\LoginMethods::passwordEnabled`, which also returns true when SSO isn't available (not standalone, `sso.enabled` off, no frontend callback URL or no enabled provider). `AuthMethodsController` leaves the password method out when it's false, and `LocalAuthController::login` returns 403 in standalone mode. The scheduler isn't affected: it calls `/api/v1/services/caller/*` with HTTP basic client credentials. SSO links to an existing user by email only when `email_verified` is true; the chart sets `emailVerified: true` on every realm user.
- **The API logs SSO credentials.** The request logger writes the OIDC callback's `code` and `state`, the logout `ticket` (query and body) and the single-use handoff `code` in the `POST /api/auth/sso/exchange` body to stdout. They're short-lived and single-use, but they're credentials in logs; this belongs with A5.
- **Seeding and realm users.** Checked on a fresh stack by signing in through Keycloak with `curl` (API redirect, Keycloak login form, API callback): the init Job seeds only `admin@example.com`. The researcher's first sign-in creates them with `DEFAULT`+`UK-RESEARCH` and role `user`. Removing `uk-research` in Keycloak (leaving `default`) and signing in again leaves only `DEFAULT`. The custodian's first sign-in gives `CUSTODIAN`+`DEFAULT`, roles `custodian`+`user`, and membership of "Demo Custodian".
  - The init Job no longer runs `StandaloneDemoSeeder`. When `users` is empty it runs `files/api-init/ensure-admin.php`, which finds or creates the custodian `bootstrap.custodianName` (setting `external_custodian_id`/`_name` as the seeder does), the "Demo Network" link, and the admin `bootstrap.adminEmail` (role `admin`, workgroup `ADMIN`, member of the custodian, password from `admin-password`). No researcher is seeded. The admin isn't in the realm, so it signs in with email and password only.
  - The realm's groups, realm roles and users are rendered from `keycloak.groups`, `keycloak.roles` and `keycloak.users` into `keycloak.realmJson`, which comes from `customisations/keycloak/realm.json` (and has none of them) (D21). A user referencing an unlisted group or role, or with no `passwordKey`, fails the render.
  - User IDs are the first 32 hex digits of `sha256(<realm>/<username>)`, in UUID layout, so `sub` survives a re-import.
  - Each `passwordKey` is a key under `secrets` (`researcherPassword`, `custodianPassword` by default, both generated by `local-secrets.sh`), stored in the Secret as `keycloak-user-<kebab-case key>` and passed to Keycloak as `CDS_<UPPER_SNAKE key>` for the realm's `${…}` placeholder. A missing key fails the render.
  - Neither default user's email matches a seeded user, so first sign-in takes `SsoUserResolver`'s create path (local defaults `DEFAULT` and `user`, then claim sync), not link-by-email. The custodian user's `Demo Custodian` group links only to the seeded custodian of that name (A6).
  - In the API's claim mapping, the `custodian` group maps to the `CUSTODIAN` workgroup and the `CUSTODIAN` role to `custodian` (`customisations/api/claimsaccesscontrol.php`, byte-identical to the API's own at `v1.17.0`). Since 2026-11-13 the stack's copy hard-codes its settings and uses different Keycloak names (`ukri`, `gsk`, `bbmri`, `nhs-wales`; roles `researcher`, `platform-admin`, `data-custodian`) to show the mapping.
- **Activity log** gains `sso` entries (`sso_login`, `sso_claims_mapped` with attached and detached IDs, logout with `had_id_token_hint`).

## Learnt provisioning (S4, 2026-11-13)

Checked against api `b257363` and Keycloak 26.8.2 on Rancher Desktop.

- **Visibility.** A non-admin sees a collection only when it's in one of their workgroups **and** in state `active`, or when it belongs to one of their custodians (`Collection::scopeVisibleToUser`). New collections start in `draft`; `draft` → `active` is allowed directly, with no `pending` step.
- **Endpoints the provisioner uses**, all under `decode.jwt`: `GET /v1/workgroups` and `GET /v1/custodians` (plain lists, not paginated); `GET /v1/custodians/{pid}/collection_hosts` (each host with its `collections`); `POST /v1/custodians`, `POST /v1/collection_hosts`, `POST /v1/custodians/{pid}/collections` (`description` is required, `type` is `bunny` or `beacon`); `GET /v1/collections/{id}` (with `model_state.state.slug` and `workgroups`); `POST /v1/collections/{id}/workgroup`; `PUT /v1/collections/{id}/transition_to` with `{"state": "active"}`. Every response is `{"message": "success", "data": …}`, `POST /api/auth/sso/exchange` included: the token is `data.access_token`, though its docblock shows it unwrapped.
- **Every read writes an activity entry** (`viewed`), so a provisioning run that changes nothing still adds rows to `activity_log`, and its SSO sign-in adds `sso_login` entries for the admin.
- **`addToWorkgroup` and `removeFromWorkgroup` have no authorisation check**, and their route group has `cbac:admin` commented out (DP-354). Any signed-in user can share a collection with any workgroup. Ticket A9.
- **Activating a collection** calls `SlackNotifier`, which logs `no webhook URL configured` and sends nothing in the stack.
- **Scripted Keycloak sign-in.** Keycloak sets `AUTH_SESSION_ID`, `KC_AUTH_SESSION_HASH` and `KC_RESTART` with `Secure; SameSite=None` even over `http://localhost`. Browsers and curl send them back to `localhost`; Python's `http.cookiejar` doesn't, and Keycloak then answers the login POST with 400 (`cookie_not_found`). The provisioner's cookie policy treats `localhost` as secure, as browsers do. The login form is `form#kc-form-login` with `username` and `password`.
- **Reaching browser URLs from a Job** needs no socat sidecar: the provisioner maps `localhost:<port>` to the Services when it resolves names, so the `Host` header stays the browser's.
- **Adding a user to `keycloak.users` doesn't reach a running Keycloak**: the realm is imported only when it doesn't exist. Delete the realm (or the Keycloak PVC) and restart Keycloak to pick it up.
- **Host credentials** written by the provisioner pass `CollectionHostBasicAuth`: `GET /api/v1/task/nextjob/{collection pid}` returns 204 with them and 401 without. `TASK_API_BASE_URL` is `http://<api service>:<port>/api/v1`.

## Learnt running synthetic BUNNYs (S5, 2026-11-16)

Checked against api `b257363`, `omop-lite:0.9.3` and `hutch/bunny:1.9.8` on Rancher Desktop.

- **omop-lite 0.9.3** reads `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `SCHEMA_NAME` (default `public`), `SYNTHETIC`, `SYNTHETIC_NUMBER` (bundles `100`, `1000`, `1001`), `DIALECT`, `OMOP_VERSION`, `DATA_DIR`, `FTS_CREATE`, `DELIMITER` and `LOG_LEVEL`. If the schema already has tables it prints "Already Loaded" and exits 0, so it's safe as an init container. A load that crashed part-way leaves tables behind and won't be retried.
- **Type-a queries** worked end to end from the web: both BUNNYs logged "Solved availability query" and the collections show a last ping and last query.
- **Type-b tasks need `collection_config` rows.** `DistributionsCollector` (the `distributions-collector` command) selects enabled configs whose `run_time_hour` and `run_time_minute` match the current minute in `Europe/London`, then checks `frequency_mode` (`1` weekly, `2` monthly, `3` quarterly, `4` twice a year) against `run_time_frequency` (weekly: Carbon `dayOfWeek`, 0 is Sunday; monthly: week of the month). With no configs it returns `{"configs":[]}` and creates nothing. Provisioned collections had none, so the term directory and the "Last Distribution" columns stayed empty.
  - `CollectionSeeder` creates `GENERIC` weekly with `run_time_frequency` 6 (Saturday, though its comment says Sunday) and `DEMOGRAPHICS` monthly in week 1, both at 23:59.
  - `GET /v1/collection_config` is admin-only and returns every config, unfiltered and not paginated. `POST /v1/collection_config` takes `collection_id`, `run_time_hour`, `run_time_minute`, `frequency_mode`, `run_time_frequency`, `enabled` and `type` (`GENERIC` or `DEMOGRAPHICS`), all required.
  - `POST /v1/collection/{pid}/distributions/run-manually` with `{"query_type": "GENERIC"|"DEMOGRAPHICS"}` creates the query and a type-b task at once. It has no authorisation check beyond being signed in.
- **Web:** opening a collection that has no distributions threw `TypeError: n is not iterable` in the browser. Not yet checked whether it goes away once distributions exist.

## Learnt planning the vocabulary import (S3, 2026-11-16)

Read from api `b257363` and nlp `v1.9.1`; the import itself is not yet run on a real Athena download.

- **No full-text index step.** There's no `AddFullTextIndexToOmopConcepts` migration or any `FULLTEXT` index in the API at `b257363`. `database/migrations_omop/` has only the `concept` and `concept_ancestor` tables and their indexes.
- **`app:import-omop-vocabs`** reads `<TABLE>.csv` (case-insensitive) for `VOCABULARY`, `DOMAIN`, `CONCEPT_CLASS`, `RELATIONSHIP`, `CONCEPT_RELATIONSHIP`, `CONCEPT_SYNONYM`, `CONCEPT_ANCESTOR`, `CONCEPT` and `DRUG_STRENGTH`, skips missing files with a warning, and with `--bulk` runs `LOAD DATA LOCAL INFILE` (tab-separated, one header line, no column list). `--truncate` empties only the tables it has a file for. `--table=` imports one. On a bad argument it prints an error and still exits 0.
  - `--create-schema` creates only missing tables. `concept` and `concept_ancestor` already exist from `migrations_omop`, with the same column order as Athena, but `valid_*_date` is `DATETIME` there and `VARCHAR(10)` in the importer's own definition.
  - The `omop` connection sets `PDO::MYSQL_ATTR_LOCAL_INFILE`, and the chart's MySQL runs with `--local-infile=1`.
- **`concepts:populate-ancestors`** only dispatches `PopulateLocalConceptAncestors`, which fills `local_concept_ancestors` from `concept_ancestor` for concepts that already have distributions. With no distributions it does nothing.
- **NLP doesn't need a restart after an import.** It loads its concept list from `latest_distributions` in the app DB, not the vocabulary, and reloads every `STORE_REFRESH_TTL` (300 seconds) when a fingerprint changes. The fingerprint includes the row counts of `concept_synonym` and `concept_ancestor` (`min_levels_of_separation = 1`) in the vocabulary DB, so an import is picked up on the next refresh.

## Learnt installing beyond a laptop (S6, 2026-11-17)

- **curl sends `*.localhost` to loopback, whatever DNS or `/etc/hosts` say** (RFC 6761). The API's Guzzle calls and the provisioner's PHP and curl requests to `http://auth.cds.localhost` reached `127.0.0.1` inside the pod even with a `hostAliases` entry pointing elsewhere. The chart therefore treats `*.localhost` like `localhost`: socat sidecars on the URL's port, plus `127.0.0.1` host entries for clients that do use them.
- **The API and queue need shared storage for uploads.** `TaskController` stores a BUNNY's `.distribution` file on the default `local` disk (`storage/app/private`) and dispatches `ProcessDistributionFile`, which reads it back on Horizon. Since S1 put Horizon in its own Deployment, every distribution job failed with `Cannot open <uuid>-code.distribution`, leaving `distributions` empty under Tilt too. A `ReadWriteOnce` PVC mounted in both pods fixed it: on `cds-eval` the next runs produced 399 `distributions` rows. The API offers only `local` and `gcs` disks.
- **Rancher Desktop's 4 CPUs fit one stack's requests, not two.** A second install stayed `Pending` on "Insufficient cpu" until its requests were cut to 10m for the test.
- **Helm hook Jobs survive `helm uninstall`.** A leftover `api-init` Job has to be deleted by hand before installing the same release name again.
- **Traefik on Rancher Desktop serves `*.localhost` ingress hosts on port 80 of the Mac**, so an ingress test needs no DNS or `/etc/hosts` changes, and browsers treat those hosts as secure contexts, so the `Secure` sign-in cookie works over http.

## Learnt writing the user docs (S9, 2026-11-17)

- **`tilt down` keeps three volumes, not two.** The synthetic Postgres PVC (`cohort-discovery-synthetic-db-data`) has `tilt.dev/down-policy: keep` like MySQL and Keycloak, so a reset has to delete it too, along with `generated/secrets.values.yaml`.
- **The NLP applies only three mapping groups**: `normalise`, `demographic` and `bmi` (`parsing.py`, `rules_engine.py`). Entries in any other group are loaded but never used. An invalid or missing `rules.json` or `mappings.json` makes the NLP exit at start-up.
- **The NLP's endpoint is `POST /extract` with `{"query": …}`**, not `/parse`.
- **`provision.json` needs `description` only when a collection is created**: `provision.py` reads `collection_plan["description"]` without a default in its create branch.
- **`helm install --dry-run=client` still checks ownership against the live cluster.** Rendering `NOTES.txt` under the release name `cohort-discovery` failed while a Tilt stack was running, because Tilt owns the resources. Use another release name and namespace for render checks.

## Prior art to reuse

- `cohort-discovery-service-evaluator/compose.yaml`: mysql (with `init/mysql/01-omop.sql`), `api-init` (`init/api-init.sh`), nlp and api in standalone mode, with mounted Passport keys. It has no web and no Keycloak.
- `cohort-discovery-service-docs/docs/developers/deploying/`:
  - `running.md`: start order, required env, and the named seeders to use instead of a bare `db:seed`.
  - `examples/keycloak.md`: realm `cohort-discovery-service`; groups named after the `workgroup_mappings` values; realm roles `GENERAL_ACCESS`, `SYSTEM_ADMIN` and `CUSTODIAN`; a confidential client with PKCE; flat `groups` and `roles` mappers on the ID token; and `KC_HOSTNAME` resolvable from both the browser and the API container.
  - `claim-mapping.md` and `limitations.md`: only Keycloak is tested end to end, and Entra and Google are blocked by API issue #350.
  - `carrying-changes.md`: how upgrades carry local changes is left open, and this repo answers it.
- `cohort-discovery-infrastructure/cohortdiscovery*/locals.tf` (`env_vars`, around line 629): the env set production actually uses.
