# Decisions

Agreed decisions are fixed unless reopened here. Each open decision has a recommendation. A ticket that depends on an open decision waits for it to be agreed.

## Agreed (2026-11-11)

### D1. The plan lives in this repo
The stack repo holds the plan and tracker. Changes to web, API and NLP are tickets in this tracker that are delivered as PRs in those repos.

### D2. Images are published publicly to GHCR
`ghcr.io/hdruk/<service>`, public packages.

### D3. Web build-time and run-time variables stay as they are unless a change is necessary
Moving variables between build time and run time changes HDR UK's own pipelines and Terraform. That only happens if W2 shows it is necessary, and then together with a list of the changes HDR UK's stack would need.

### D4. Default: standalone, with the IdP as the source of truth for access
The default stack runs `APP_OPERATION_MODE=standalone` / `APPLICATION_MODE=standalone`. Roles, custodians and workgroups come from IdP claims (synced `always`, authoritative, set in `customisations/api/claimsaccesscontrol.php`), and seeding adds to that.

### D5. web, api and nlp are git submodules of this repo
Each is pinned to a release tag.

**Exception, 2026-11-25:** all three are pinned to `dev` commits so the stack has DP-1254 (A8), DP-1261 (A4) and DP-1262 (W1) before they are released: api `1911d5e`, web `cd5687e1`, nlp `cdc8887`. The default tags in `images` (api `b257363`, web `v1.12.0`, nlp `v1.9.1`) don't match these pins. Tilt builds from the submodules, so it isn't affected; a cluster install sets its own tags (see the deploy docs). When these are in a release, re-pin to the release tags and set the image tags to match.

### D11. Repo name: `cohort-discovery-service-stack`
Agreed 2026-11-11. The repo is `HDRUK/cohort-discovery-service-stack` (private for now).

### D12. Helm and Tilt, no Compose
Agreed 2026-11-11, replacing the earlier "Compose first" recommendation. The stack is one Helm umbrella chart, `charts/cohort-discovery/`. Tilt drives it locally, with images built from the submodules. Anyone else runs `helm install` on a local cluster (Rancher Desktop, kind, k3s). There is no Compose file and no `Makefile`.

Everything a local install needs runs in the cluster and can be thrown away: MySQL, Redis, Keycloak, the vocabulary import and, later, the synthetic BUNNYs and their Postgres.

### D10. Where the vocabulary is built
Agreed 2026-11-11.
- The API and NLP vocabulary DB stays MySQL. The minimal set (`migrations_omop` + `MinimalOmopSeeder`) is the default.
- The full set is an optional Job that imports an Athena download the deployer supplies from a host path: `php artisan app:import-omop-vocabs /vocab --create-schema --bulk`, then `concepts:populate-ancestors`. Athena licensing means the stack never ships vocabulary files.
- BUNNY's Postgres databases are loaded by omop-lite (S5).

### D15. Scheduled jobs
Agreed 2026-11-11. Production uses Cloud Scheduler to call `POST /api/v1/services/caller/{command}`. The stack uses Kubernetes CronJobs (a small pinned image running `curl`) that call the same endpoints with a seeded service account. The API doesn't change.

### D17. Config files live in the chart
**Replaced by D21 (2026-11-12) for the files a deployer changes.** Only the chart's own scripts (`files/api-init/`) still live in the chart.

Agreed 2026-11-11. Helm's `.Files` can only read inside the chart, so the files the chart consumes (NLP rules and mappings, the Keycloak realm, the claims mapping, `provision.json`, somop configs) are defaults under `charts/cohort-discovery/files/`, each overridable through values. `helm install` needs no extra flags. `config/branding/` stays at the repo root, because it's a web build input, not something the chart reads.

### D6. How a deployer overrides web branding
Agreed 2026-11-12. `scripts/build-web.sh` copies the web submodule into a temporary build context, copies `config/branding/` (now `customisations/web/branding/`, D21) over its `branding/`, then runs the web's own Dockerfile. Files missing from the overlay fall back to the submodule's. The web Dockerfile and variables don't change (D3), and HDR UK's pipeline isn't affected. Tilt builds the web through the same script. The gaps where the web ignores `branding/` (W3) are on hold and get fixed upstream later; the overlay picks up those fixes without changing.

### D9. How a deployer supplies the claims mapping
Agreed 2026-11-12. A whole replacement `config/claimsaccesscontrol.php`, mounted by the chart over `/var/www/config/claimsaccesscontrol.php` in the API containers. It's a plain Laravel config file, and `start.sh` runs `config:cache` at start, so the mounted file is what the API uses. The API doesn't change, so A3 isn't needed. The default copy is `customisations/api/claimsaccesscontrol.php` (D21; it was `charts/cohort-discovery/files/api/` under D17).
Points to keep in mind:
- The file replaces the whole config, including the `sync` section. The stack's copy hard-codes every value instead of reading `CLAIM_SYNC_*` and the other env variables, so the file alone shows the policy in use, and the chart doesn't set those variables (changed 2026-11-13). Without the file, the API falls back to its own copy and env defaults: workgroups synced on first login only, not authoritatively.
- It started as a copy of upstream. When the API submodule's pin moves, diff it against the new `config/claimsaccesscontrol.php`.
- It's PHP, so it runs in the API. Only the deployer supplies it, the same as the image.
- Since 2026-11-13 the same goes for `config/workgroups.php` (from DP-1254, A8): `customisations/api/workgroups.php` is mounted over it in the same containers, and the init Job runs `WorkgroupSeeder` on every start, so the list decides which workgroups exist. It replaced the stack's own `bootstrap.workgroups` and `ensure-workgroups.php`.
- Since 2026-11-13 `config/auth.php` too: `customisations/api/auth.php` turns `password_login` off, so everyone signs in through Keycloak, and the admin is also a Keycloak user (`keycloak.users`, linked by verified email). It's the whole Laravel auth config, with upstream's defaults written out, so diff it on every API bump. The API falls back to password sign-in when SSO isn't available (`LoginMethods::passwordEnabled`), so turning Keycloak off doesn't lock anyone out. The stack seeds only `UK-RESEARCH`, `UK-INDUSTRY`, `NON-UK-RESEARCH`, `NON-UK-INDUSTRY` and `NHS-SDE`: the admin role sees every collection without `ADMIN`, custodians see theirs through their custodian rather than `CUSTODIAN`, `DEFAULT` is only an automatic extra (`ensure_default` is off) and `OTHER` was unused.

### D13. Licence
Agreed 2026-11-12: MIT, matching everything already published (the services, somop and the five `hdruk/*` packages). This repo and `project-daphne-bunny-config` will be MIT, and the four packages without a `LICENSE` file can have one added. No action is needed now.

### D20. Removing a user's last Keycloak group doesn't remove the workgroup
Agreed 2026-11-12: (a) and (b). Found during S2. When a user has no groups, Keycloak leaves out the `groups` claim instead of sending `[]`. The API reads a missing claim as "the IdP says nothing" and keeps the user's workgroups and custodians, even under `always` + authoritative sync (D4). Removing one of several groups works.
Options:
- (a) Put every realm user in the `default` group, which maps to the `DEFAULT` workgroup every user gets anyway, so the claim is always present. A realm-only change, but it breaks again if someone removes `default`.
- (b) An API ticket: under an authoritative sync, treat a missing claim as empty, possibly behind a setting.
- (c) Document it only. S2 does this in `getting-started.md` and `02-verified-facts.md`.

**Done:** (a) is `keycloak.defaultGroup` (default `default`): the chart adds that group to every user in `keycloak.users` and makes it the realm's default group, so users created in the console get it too. (b) is ticket A7. Since 2026-11-13 the stack seeds no `DEFAULT` workgroup, so the `default` group maps to nothing; it's still there to keep the claim present.

### D21. Deployer customisations live in `customisations/`
Agreed 2026-11-12, during S2. Every file a deployer is expected to change sits under `customisations/<service>/`, so it's clear what is theirs to edit: `api/claimsaccesscontrol.php`, `keycloak/realm.json`, `nlp/rules.json` and `mappings.json`, and `web/branding/`. Later ones follow the same pattern (`provision.json` in S4, somop configs in S5). The chart's own scripts stay in `charts/cohort-discovery/files/`.
- Helm can't read files outside the chart, so `scripts/customisations-values.sh` writes them into `generated/customisations.values.yaml`, under the values that already existed for overriding them. Tilt runs it and watches the folders. `helm install` needs `-f generated/customisations.values.yaml` as well as the secrets file, which reverses D17's "no extra flags".
- With no claims mapping or NLP file supplied, the chart mounts nothing and the service uses its own copy, which is byte-identical at the pinned tags (api `v1.17.0`, nlp `v1.9.1`; no longer true for the API's claims mapping, see D9). Keycloak has no fallback: with it on and no realm, the render fails with a message saying what to pass.
- `keycloak.realmJson` is now always the base realm, with the values' groups, roles and users set on it. It's no longer used verbatim.
- The rendered chart is byte-identical to before when the customisations are passed.

### D16. How BUNNYs are added to a running stack
Agreed 2026-11-13: automatically, from `customisations/provision.json`, with omop-lite's bundled synthetic data. This replaces the earlier plan of adding a BUNNY by hand per collection.
- Each collection marked `"synthetic": true` gets its own database in one shared `postgres:16`, loaded by omop-lite with `SYNTHETIC=true`, and a pinned `hutch/bunny` Deployment whose credentials and `COLLECTION_ID` come from the Secret S4 writes. The chart owns every container; somop's own `docker compose` isn't used.
- Every synthetic collection returns the same counts. somop can be added later for distinct data per collection; it needs a Dockerfile in `somop` first.

### D22. How the provisioner authenticates
Agreed 2026-11-13, during S4. The host, collection and workgroup endpoints need a signed-in user's JWT, service accounts only reach `/api/v1/services/caller/*`, and password sign-in is off (D9, `customisations/api/auth.php`). So the provisioner signs in as `bootstrap.adminEmail` through Keycloak the way a browser does: the API's SSO redirect, Keycloak's login form, the API's callback, then `POST /api/auth/sso/exchange`. It needs no API change and uses the same path as everyone else, at the cost of depending on Keycloak's login form (`#kc-form-login`). Rejected: PHP in an API container (skips the API's validation and couples to its models), turning password sign-in back on, and an API ticket for service-account access (blocks S4).

### D8. Where "access managed externally" is enforced
Agreed 2026-11-18, in API ticket DP-1261 (A4). The API **tells** the web, per deployment and per user, which memberships an identity provider manages. It does not reject writes, for now; the web hides or warns, and the API records an activity-log warning when a managed membership is edited anyway.
- **Per user, not one deployment flag.** Claims only reach a user through an SSO identity at an enabled provider that maps that claim, or through a Gateway token. A password-only user, or a user of a provider that doesn't map roles, is unmanaged even when the deployment is authoritative. `first_login` also depends on each user's `claims_synced_at`.
- **Advisory, not 403.** Removing access must never be blocked: it's the incident lever, and lasts until the user's next sign-in. The per-user answer is a prediction (an IdP can leave a claim out, and nothing syncs). Roles and custodians have no edit endpoints to guard. Enforcement can be added later without changing the contract.
- Rejected: a single deployment-level 403 guard, the earlier recommendation here, because it is wrong for mixed deployments (password plus SSO, or several providers).

### D14. No CI deploy of the stack
Agreed 2026-11-25. The stack is a guide for deployers to build and run their own, not a service HDR UK deploys from CI, so S7 is dropped. Building images and deploying them is the deployer's job, as the deploy docs describe. Rejected: a self-hosted runner with kind or k3s, an existing namespace through Helm, and a VM running Compose.

## Open

### D7. What the published web image is
**Recommendation:** one generic standalone image with neutral branding (W3), built with `NEXT_PUBLIC_*` values for `http://localhost:3000`. Changing URLs or branding means rebuilding through the stack's build script.
**After W2 (2026-11-12):** the recommendation stands. Of the web's variables, only `NEXT_PUBLIC_TASK_URL` is wrong in a generic image served away from `localhost`, and only in what custodians are shown (the URL to give their BUNNY, and the footer's "API docs" link); no request uses it. Everything else is either read at run time already or doesn't apply to standalone. `NEXT_PUBLIC_LOGIN_URL` must stay unset. No HDR UK pipeline changes (D3). W4 makes the task URL a run-time setting without touching HDR UK's pipelines, if a no-rebuild image matters more later. See [web-variables.md](web-variables.md).

### D18. Which Redis the stack runs
Found during S1. Redis 7.4 and later aren't under an OSI licence: 7.4 is RSALv2/SSPL, and 8.x adds AGPL. 7.2 is the last BSD-licensed line. The API only needs a Redis-protocol server for its queue, cache and sessions.
**Recommendation:** the official `redis:7.2.x` image for now (S1 pins `7.2.13`). Review it in H1, together with the licence decision (D13), and move to Valkey (`valkey/valkey`, BSD) if 7.2 reaches end of life first.

### D19. How `app:bootstrap` gets the scheduler's credentials
Found during S1. `service-account:create` prints the secret once, and A2 plans to write it to `BOOTSTRAP_SERVICE_ACCOUNT_FILE`. On Kubernetes, that file then has to become a Secret, which needs RBAC for the bootstrap Job or a second step. S1 avoids this: `scripts/local-secrets.sh` generates the client ID and secret, they live in the stack's Secret, and the init Job finds the account by name, then creates it, leaves it alone, or updates it to match. The `ServiceAccount` model allows this, because `client_id` is fillable and `client_secret` is cast to `hashed`.
**Recommendation:** A2 accepts the credentials from env (for example `BOOTSTRAP_SERVICE_ACCOUNT_CLIENT_ID` and `BOOTSTRAP_SERVICE_ACCOUNT_CLIENT_SECRET`) with the same find-then-converge behaviour, and keeps the file option for installs that let the API generate them.
