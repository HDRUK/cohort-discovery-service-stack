# Getting started

S1 runs the core: MySQL, Redis, the API (with its Horizon queue worker and scheduled jobs), NLP and the web app, in standalone mode with the minimal OMOP vocabulary and a seeded admin. Keycloak (S2), the full vocabulary (S3), provisioning (S4) and synthetic collections (S5) come later.

No local Kubernetes cluster? See [Running with Docker Compose](alternatives/docker-compose.md) for a community alternative.

## You need

- A local Kubernetes cluster: Rancher Desktop (with the Docker runtime), Docker Desktop, OrbStack, minikube, or kind/k3d with a cluster named `cohort-discovery`. Allow it about 4 CPUs and 8 GB of memory.
- `kubectl`, `helm` 3, `tilt` and `openssl`.
- Access to HDR UK's private `hdruk/*` composer packages, to build the API image (until A1). The build reads a GitHub token from `GITHUB_TOKEN`; the GitHub CLI can supply it.
- Ports 3000, 8100 and 5001 free on the host, or other ports chosen as in [Host ports](#host-ports). Tilt forwards to them, and if a local dev server of the web, API or NLP is listening on `*:<port>`, `localhost` can reach either one, depending on whether it resolves to IPv4 or IPv6. Stop local dev servers first, or move the stack to other ports, and stop anything that polls them, such as BUNNY containers from `somop run`.

## Clone

```bash
git clone --recurse-submodules https://github.com/HDRUK/cohort-discovery-service-stack.git
cd cohort-discovery-service-stack
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`.

`services/web`, `services/api` and `services/nlp` are pinned to release tags. `git submodule status` shows which.

## Run with Tilt

```bash
export GITHUB_TOKEN=$(gh auth token)
tilt up
```

On load, the Tiltfile:

1. refuses any context that isn't a known local cluster;
2. runs `scripts/local-secrets.sh`, which writes random credentials to `generated/secrets.values.yaml` (mode 0600, git-ignored) the first time and leaves the file alone after that;
3. creates the `cohort-discovery` namespace;
4. builds the API, NLP and web images from `services/`, the web with the stack's branding (see [Branding](#branding)), and installs the chart.

The first build takes a while: the API and web images each take several minutes. The token reaches the API build only as a BuildKit secret, never on disk or in an image layer.

Resources start in this order: `mysql` and `redis`, then `api-init`, then `api`, `queue` and `nlp`, then `web` and the `scheduler-*` CronJobs. The chart enforces the same order on its own with init containers, so a plain `helm install` behaves the same.

When everything is green:

| URL | What |
|---|---|
| http://localhost:3000 | web |
| http://localhost:8100 | API (`/up` is its health check) |
| http://localhost:5001/health/ready | NLP readiness |

### Host ports

To run alongside a development stack that already uses 3000, 8100 and 5001, choose other host ports before `tilt up`:

```bash
export CDS_WEB_PORT=13000 CDS_API_PORT=18100 CDS_NLP_PORT=15001
tilt up
```

The containers and Services keep their own ports; only the forwards change. `CDS_API_PORT` also sets the API's `APP_URL` and the web image's `API_BASE_URL` and `NEXT_PUBLIC_TASK_URL`, because the browser calls the API directly. Changing it rebuilds the web image. Use the same values for the URLs above and below.

Browsers share cookies across ports on the same host, so the web app names its session cookie `cds_stack_token` (`web.cookieTokenName`) rather than the default `token`. Without that, a development web app on `localhost` and the stack would overwrite each other's sign-in, and the stack's API would reject the other's token with `Token signature mismatch`.

### Sign in

The admin is `admin@example.com`. Its password is in the stack's Secret:

```bash
kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

A researcher account, `researcher@example.com`, is seeded too; its password is under `researcher-password`.

To check the API directly:

```bash
curl -s -X POST http://localhost:8100/api/auth/login \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d "{\"email\":\"admin@example.com\",\"password\":\"$(kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.admin-password}' | base64 -d)\"}"
```

### Stop and restart

`tilt down` removes everything except the namespace and the MySQL volume (`tilt.dev/down-policy: keep`), so the next `tilt up` finds the same data. The init Job runs again and changes nothing.

To start from scratch, delete the volume as well:

```bash
tilt down
kubectl -n cohort-discovery delete pvc cohort-discovery-mysql-data
```

Keep `generated/secrets.values.yaml` while the volume exists. MySQL sets its passwords only when it first initialises the volume, so new credentials won't match old data. Delete the file and the volume together, or neither.

## Run with Helm alone

The chart is the whole definition; Tilt only builds images and forwards ports. Without Tilt, build the images under the tags `values.yaml` expects, so a local cluster that shares Docker's image store (Rancher Desktop with the Docker runtime, Docker Desktop, OrbStack) can use them:

```bash
export GITHUB_TOKEN=$(gh auth token)
docker build --secret id=github_token,env=GITHUB_TOKEN -t ghcr.io/hdruk/cohort-discovery-api:v1.17.0 services/api
docker build -t ghcr.io/hdruk/cohort-discovery-nlp:v1.9.1 services/nlp
scripts/build-web.sh ghcr.io/hdruk/cohort-discovery-web:v1.12.0 \
  --build-arg APPLICATION_MODE=standalone \
  --build-arg API_BASE_URL=http://localhost:8100 \
  --build-arg NEXT_PUBLIC_TASK_URL=http://localhost:8100/api/v1 \
  --build-arg NEXT_PUBLIC_USE_EXAMPLE_QUERY=false \
  --build-arg NEXT_PUBLIC_USE_DEBUG_LOGS=false
```

The web is built through `scripts/build-web.sh` so that it carries the stack's branding (see [Branding](#branding)).

For kind or k3d, load the images into the cluster afterwards (`kind load docker-image …`, `k3d image import …`).

Then:

```bash
scripts/local-secrets.sh
helm install cohort-discovery charts/cohort-discovery \
  --namespace cohort-discovery --create-namespace \
  -f generated/secrets.values.yaml --timeout 15m
kubectl -n cohort-discovery port-forward svc/cohort-discovery-web 3000:3000
kubectl -n cohort-discovery port-forward svc/cohort-discovery-api 8100:8100
```

`api-init` is a `post-install,post-upgrade` hook, so `helm install` waits for it. The API, queue and NLP pods wait in their `wait-for-api-init` init containers until it has finished.

`helm uninstall` deletes the MySQL volume with everything else.

## What the init Job does

`api-init` runs `charts/cohort-discovery/files/api-init/api-init.sh` in the API image. Each step is safe to repeat:

| Step | Repeat behaviour |
|---|---|
| `migrate --force`, the `omop` migrations, `deploy:run` | Only pending migrations and steps run |
| `WorkgroupSeeder`, `RolesAndPermissionsSeeder` | Run only when `workgroups` or `roles` is empty; they insert unconditionally |
| `StateSeeder`, `FeatureSeeder`, `PersonalAccessClientSeeder` | Always run; they create only what's missing |
| `MinimalOmopSeeder` | Runs only when the `omop.concept` table is empty, so it never touches a full import |
| `StandaloneDemoSeeder` (admin, researcher, "Demo Custodian", "Demo Network") | Runs only when `users` is empty, because it truncates users and custodians |
| Scheduler service account | Created from the Secret's `scheduler-client-id` and `scheduler-client-secret`; left alone when it matches, updated when it doesn't |

The Passport keys come from the Secret through `PASSPORT_PRIVATE_KEY` and `PASSPORT_PUBLIC_KEY`, so tokens survive pod restarts. A2's `app:bootstrap` will replace the script.

## Scheduled jobs

Four CronJobs call `POST /api/v1/services/caller/{command}` every minute with the scheduler service account, as production's Cloud Scheduler does: `distributions-collector`, `task-cleanup-job`, `collection-no-activity-monitor` and `collection-task-backlog-monitor`. Change the schedules under `scheduler.jobs`, or turn them off with `scheduler.enabled=false`. To run one now:

```bash
kubectl -n cohort-discovery create job --from=cronjob/cohort-discovery-task-cleanup-job task-cleanup-now
kubectl -n cohort-discovery logs job/task-cleanup-now
```

## Configuration

| Value | What |
|---|---|
| `images.*` | Image repositories and pinned tags |
| `bootstrap.adminEmail`, `bootstrap.researcherEmail` | The seeded accounts, used only when `users` is empty |
| `nlp.rulesJson`, `nlp.mappingsJson` | Replace the NLP rules and mappings (defaults in `files/nlp/`) |
| `api.extraEnv`, `nlp.extraEnv`, `web.extraEnv` | Extra non-secret environment variables |
| `scheduler.*` | Scheduled jobs |
| `secrets.*` | Set only by `generated/secrets.values.yaml`; never in `values.yaml` |

## Branding

The web is branded at build time, so changing the branding means rebuilding the web image. The stack ships a neutral brand, "Feasibility Tool", in `config/branding/`:

| File | What |
|---|---|
| `branding.config.ts` | Product name, sign-in page text, organisation name and link, legal page titles |
| `theme.ts` | Colours and font, merged over the web's base theme. Set `primary` and `secondary`, or the web's own defaults show through |
| `assets/logo.svg` | The header logo, shown on the dark header at 30px high |
| `legal/termsAndConditions.mdx`, `legal/privacyPolicy.mdx` | Placeholders that say they must be replaced before anyone signs in |

`scripts/build-web.sh <image> [docker build options]` copies `services/web` to a temporary folder, copies `config/branding/` over its `branding/`, and runs the web's own Dockerfile (D6). Any file you leave out of `config/branding/` falls back to the web's own. Tilt rebuilds the web when anything in `config/branding/` changes.

Before a real deployment, replace the legal pages and set `organisationName`, `copyrightHolder` and `links.organisation` in `branding.config.ts`. Footer links such as the cookie notice are built from `links.organisation` unless `links.cookieNotice` and `links.accessibilityStatement` are set.

Some HDR UK branding still comes from the web itself rather than `branding/`, for example the copyright text and the favicon. W3 tracks fixing that upstream.

## Layout

| Path | What |
|---|---|
| `services/` | web, API and NLP submodules |
| `charts/cohort-discovery/` | the Helm chart: the one definition of the stack |
| `charts/cohort-discovery/files/nlp/` | NLP `rules.json` and `mappings.json`, copied from the NLP defaults |
| `charts/cohort-discovery/files/api-init/` | the init Job's script |
| `charts/cohort-discovery/files/keycloak/` | Keycloak realm (S2) |
| `charts/cohort-discovery/files/synthetic/` | somop configs (S5) |
| `config/branding/` | branding overlay, a web build input (D6, S8) |
| `scripts/` | `local-secrets.sh`, and later build and provisioning scripts |
| `generated/` | git-ignored local secrets |
| `Tiltfile` | local development |

`files/api/claimsaccesscontrol.php` arrives with S2 (D9) and `files/provision.json` with S4.
