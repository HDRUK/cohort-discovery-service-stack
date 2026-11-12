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
The default stack runs `APP_OPERATION_MODE=standalone` / `APPLICATION_MODE=standalone`. Roles, custodians and workgroups come from IdP claims (`CLAIM_SYNC_*=always`, authoritative), and seeding adds to that.

### D5. web, api and nlp are git submodules of this repo
Each is pinned to a release tag. CI can override the pin with any ref (S7).

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
Agreed 2026-11-11. Helm's `.Files` can only read inside the chart, so the files the chart consumes (NLP rules and mappings, the Keycloak realm, the claims mapping, `provision.json`, somop configs) are defaults under `charts/cohort-discovery/files/`, each overridable through values. `helm install` needs no extra flags. `config/branding/` stays at the repo root, because it's a web build input, not something the chart reads.

## Open

### D6. How a deployer overrides web branding
**Recommendation:** the stack's build script copies a `config/branding/` overlay over the submodule's `branding/` in a temporary build context, then runs the web's existing Dockerfile. The web Dockerfile and variables don't change (D3), and HDR UK's pipeline isn't affected.
The alternative, a BuildKit named context (`--build-context branding=…`), needs a Dockerfile change that HDR UK's build would also have to accommodate.

### D7. What the published web image is
**Recommendation:** one generic standalone image with neutral branding (W3), built with `NEXT_PUBLIC_*` values for `http://localhost:3000`. Changing URLs or branding means rebuilding through the stack's build script. Revisit after W2.

### D8. Where "access managed externally" is enforced
**Recommendation:** in the API. It derives a flag from the claim-sync policy (workgroups, roles and custodians synced `always` and authoritative), rejects writes to them with 403, and exposes the flag to the web. The web only hides controls (W1). A web-only gate isn't a security boundary.

### D9. Format of the runtime claims mapping
**Recommendation:** a JSON file at `CLAIMS_MAPPING_PATH`, with the same shape as the `workgroup_mappings` and `role_mappings` arrays in `config/claimsaccesscontrol.php`. It's read when the config loads, so it is in place before `config:cache` in `start.sh`. When the variable is unset, the PHP defaults apply. JSON avoids a YAML dependency.

### D13. Licence
Which licence the stack and the three service repos are released under. It has to be settled before A1 makes the `hdruk/*` composer packages public. Not a technical decision: it needs whoever owns open-sourcing at HDR UK.
**Found 2026-11-12 (H1):** the services, somop and all five `hdruk/*` packages are already public, and all of them are MIT. Web, API, NLP, somop and `claims-based-access-control` have an MIT `LICENSE` file. `laravel-search-and-filter`, `laravel-plugin-core`, `laravel-workflow-states` and `laravel-messenger` declare `"license": "MIT"` in `composer.json` but have no `LICENSE` file. `project-daphne-bunny-config` and this repo are private, with no licence. A1's "make the packages public" step is already done.
**Recommendation:** MIT for this repo and bunny-config, to match what's already published, and add the missing `LICENSE` files to the four packages. Still needs the open-sourcing owner's sign-off.

### D14. Where CI deploys a custom-built stack
Options:
- a self-hosted runner with kind or k3s;
- an existing Kubernetes namespace through Helm;
- a VM running Compose.

**Recommendation:** an existing namespace through Helm, because it matches how `dev-standalone` is deployed today. That means S7 can't deploy until S6 is done. Until then it builds and pushes only.

### D16. How BUNNYs are added to a running stack
The user wants BUNNYs added by hand once the core is up and collections are provisioned, "via somop or something more custom".
**Recommendation:** a manual Tilt resource (and a plain script for non-Tilt installs) per collection. It runs `somop generate` as a Job, loads the result into a shared `postgres:16` with omop-lite, and installs a BUNNY Deployment that reads the host's credentials from the Kubernetes Secret S4 wrote. This uses somop for data only and lets the chart own every container, instead of somop's own `docker compose`.
**Alternative found 2026-11-12:** omop-lite's `SYNTHETIC=true` loads bundled synthetic data without somop (`AndyRae/cd-build` does this). That removes the somop Dockerfile and the generate Job, but gives every collection the same data. Decide whether distinct data per collection is worth the somop step.

### D18. Which Redis the stack runs
Found during S1. Redis 7.4 and later aren't under an OSI licence: 7.4 is RSALv2/SSPL, and 8.x adds AGPL. 7.2 is the last BSD-licensed line. The API only needs a Redis-protocol server for its queue, cache and sessions.
**Recommendation:** the official `redis:7.2.x` image for now (S1 pins `7.2.13`). Review it in H1, together with the licence decision (D13), and move to Valkey (`valkey/valkey`, BSD) if 7.2 reaches end of life first.

### D19. How `app:bootstrap` gets the scheduler's credentials
Found during S1. `service-account:create` prints the secret once, and A2 plans to write it to `BOOTSTRAP_SERVICE_ACCOUNT_FILE`. On Kubernetes, that file then has to become a Secret, which needs RBAC for the bootstrap Job or a second step. S1 avoids this: `scripts/local-secrets.sh` generates the client ID and secret, they live in the stack's Secret, and the init Job finds the account by name, then creates it, leaves it alone, or updates it to match. The `ServiceAccount` model allows this, because `client_id` is fillable and `client_secret` is cast to `hashed`.
**Recommendation:** A2 accepts the credentials from env (for example `BOOTSTRAP_SERVICE_ACCOUNT_CLIENT_ID` and `BOOTSTRAP_SERVICE_ACCOUNT_CLIENT_SECRET`) with the same find-then-converge behaviour, and keeps the file option for installs that let the API generate them.
