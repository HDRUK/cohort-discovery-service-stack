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

### D10. Where the vocabulary is built
**Recommendation:**
- The API and NLP vocabulary DB stays MySQL. The minimal set (`migrations_omop` + `MinimalOmopSeeder`) is the default.
- The full set is a one-off job running `php artisan app:import-omop-vocabs /vocab --create-schema --bulk`, followed by `concepts:populate-ancestors`, from an Athena download the deployer supplies. Athena licensing means the stack never ships vocabulary files.
- BUNNY's Postgres databases are loaded by omop-lite (S5).

### D12. Compose or Helm first
**Recommendation:** Compose first (S1–S5), then a Helm umbrella chart that mirrors it (S6). Compose is quicker to iterate on and is what most evaluators will run.

### D13. Licence
Which licence the stack and the three service repos are released under. It has to be settled before A1 makes the `hdruk/*` composer packages public. Not a technical decision: it needs whoever owns open-sourcing at HDR UK.

### D14. Where CI deploys a custom-built stack
Options:
- a self-hosted runner with kind or k3s;
- an existing Kubernetes namespace through Helm;
- a VM running Compose.

**Recommendation:** an existing namespace through Helm, because it matches how `dev-standalone` is deployed today. That means S7 can't deploy until S6 is done. Until then it builds and pushes only.

### D15. Scheduled jobs
Production uses Cloud Scheduler to call `POST /api/v1/services/caller/{command}`.
**Recommendation:** a small scheduler container (a cron image running `curl`) that calls the same endpoints with a service account created by `app:bootstrap`. The API doesn't change.
