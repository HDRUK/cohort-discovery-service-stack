# Getting started

The stack runs MySQL, Redis, the API (with its Horizon queue worker and scheduled jobs), NLP, the web app and a throwaway Keycloak for single sign-on, in standalone mode with the minimal OMOP vocabulary, a seeded admin and two Keycloak users. It provisions the collections in `customisations/provision.json` and serves each synthetic one from its own BUNNY. The full vocabulary (S3) comes later.

No local Kubernetes cluster? See [Running with Docker Compose](alternatives/docker-compose.md) for a community alternative.

## You need

- A local Kubernetes cluster: Rancher Desktop (with the Docker runtime), Docker Desktop, OrbStack, minikube, or kind/k3d with a cluster named `cohort-discovery`. Allow it about 4 CPUs and 8 GB of memory.
- `kubectl`, `helm` 3, `tilt` and `openssl`.
- Access to HDR UK's private `hdruk/*` composer packages, to build the API image (until A1). The build reads a GitHub token from `GITHUB_TOKEN`; the GitHub CLI can supply it.
- Ports 3000, 8100, 5001 and 8180 free on the host, or other ports chosen as in [Host ports](#host-ports). Tilt forwards to them, and if a local dev server of the web, API or NLP is listening on `*:<port>`, `localhost` can reach either one, depending on whether it resolves to IPv4 or IPv6. Stop local dev servers first, or move the stack to other ports, and stop anything that polls them, such as BUNNY containers from `somop run`.

## Clone

```bash
git clone --recurse-submodules https://github.com/HDRUK/cohort-discovery-service-stack.git
cd cohort-discovery-service-stack
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`.

`services/web`, `services/api` and `services/nlp` are pinned to release tags. `git submodule status` shows which. For now `services/api` is the exception: it's pinned to an unreleased commit of the API that adds list-valued claim mappings and a configurable workgroup list (D5).

## Run with Tilt

```bash
export GITHUB_TOKEN=$(gh auth token)
tilt up
```

On load, the Tiltfile:

1. refuses any context that isn't a known local cluster;
2. runs `scripts/local-secrets.sh`, which writes random credentials to `generated/secrets.values.yaml` (mode 0600, git-ignored) the first time. After that it only adds keys the file is missing, such as the Keycloak ones for a file written before S2, and never changes or prints existing values;
3. creates the `cohort-discovery` namespace;
4. builds the API, NLP and web images from `services/`, the web with the stack's branding (see [Branding](#branding)), and installs the chart.

The first build takes a while: the API and web images each take several minutes. The token reaches the API build only as a BuildKit secret, never on disk or in an image layer.

Resources start in this order: `mysql`, `redis` and `keycloak`, then `api-init`, then `api`, `queue` and `nlp`, then `web` and the `scheduler-*` CronJobs. The chart enforces the same order on its own with init containers, so a plain `helm install` behaves the same.

When everything is green:

| URL | What |
|---|---|
| http://localhost:3000 | web |
| http://localhost:8100 | API (`/up` is its health check) |
| http://localhost:5001/health/ready | NLP readiness |
| http://localhost:8180 | Keycloak (admin console at `/admin`, user `admin`) |

### Host ports

To run alongside a development stack that already uses 3000, 8100 and 5001, choose other host ports before `tilt up`:

```bash
export CDS_WEB_PORT=13000 CDS_API_PORT=18100 CDS_NLP_PORT=15001 CDS_KEYCLOAK_PORT=18180
tilt up
```

The web, API and NLP containers keep their own ports; only the forwards change. Keycloak is the exception: it listens inside the cluster on the same port as its forward (see [Single sign-on](#single-sign-on-keycloak)). `CDS_API_PORT` also sets the API's `APP_URL` and the web image's `API_BASE_URL` and `NEXT_PUBLIC_TASK_URL`, because the browser calls the API directly. Changing it rebuilds the web image. Use the same values for the URLs above and below.

Browsers share cookies across ports on the same host, so the web app names its session cookie `cds_stack_token` (`web.cookieTokenName`) rather than the default `token`. Without that, a development web app on `localhost` and the stack would overwrite each other's sign-in, and the stack's API would reject the other's token with `Token signature mismatch`.

### Sign in

Everyone signs in through "Single Sign-On" with Keycloak. Email and password sign-in is off (`password_login` in `customisations/api/auth.php`): the login page doesn't offer it, and the API refuses `POST /api/auth/login` with 403. With Keycloak turned off there's no SSO, so the API offers password sign-in again and nobody is locked out.

The admin is `admin@example.com`. The init Job seeds it in the app, and it's also a Keycloak user with the same email, so its first SSO sign-in links to the seeded account (Keycloak marks the email verified). Its Keycloak password is the admin password from the stack's Secret:

```bash
kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

To turn password sign-in back on, set `'enabled' => true` under `password_login` in `customisations/api/auth.php`. Then, to check the API directly:

```bash
curl -s -X POST http://localhost:8100/api/auth/login \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d "{\"email\":\"admin@example.com\",\"password\":\"$(kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.admin-password}' | base64 -d)\"}"
```

### Single sign-on (Keycloak)

Keycloak runs by default, with the realm `cohort-discovery-service` imported on its first start. The login page offers "Single Sign-On" only (see [Sign in](#sign-in)). The realm's client and settings come from `customisations/keycloak/realm.json`; its groups, realm roles and users come from `keycloak.groups`, `keycloak.roles` and `keycloak.users` in the values (see [Customising users, groups and roles](#customising-users-groups-and-roles)). By default there are three fictional users:

| User | Keycloak groups | Realm role | Becomes in the app on first sign-in |
|---|---|---|---|
| `admin@example.com` (Demo Admin) | `Demo Custodian`, `default` | `platform-admin` | the seeded admin: role `admin` (and `user`); custodian "Demo Custodian" |
| `researcher@example.com` (Jane Doe) | `breathe`, `default` | `researcher` | workgroup `UK-RESEARCH`; role `user` |
| `custodian@example.com` (John Smith) | `Demo Custodian`, `default` | `data-custodian` | no workgroups; roles `custodian`, `user`; custodian "Demo Custodian" |

The admin is in `Demo Custodian` because custodian sync is authoritative: without the group, its first sign-in would remove it from the custodian the init Job gave it. The researcher and custodian aren't accounts the stack seeds, so the API creates each one the first time it signs in through Keycloak. The custodian user joins "Demo Custodian" only because the init Job seeded a custodian with exactly that name (`bootstrap.custodianName`): in standalone mode the API links SSO users to existing custodians by name and never creates one (A6).

Each user names a `passwordKey`. The password is that key in `generated/secrets.values.yaml` (`adminPassword`, `researcherPassword` and `custodianPassword` by default; the admin shares the init Job's admin password), and in the Secret as `keycloak-user-<key in kebab case>`:

```bash
kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.keycloak-user-researcher-password}' | base64 -d; echo
```

The client secret (`keycloakClientSecret`) and the Keycloak console's `admin` password (`keycloakAdminPassword`) are in the same file; no password is in `values.yaml`. The realm reads them, and the URLs, from `${CDS_*}` placeholders that Keycloak fills from its environment at import.

Keycloak is authoritative for access (D4): on every SSO sign-in, the API replaces the user's workgroups, roles and custodians with what the ID token's `groups` and `roles` claims say. Change membership in the Keycloak console, then sign in again. One exception: a user with no groups at all gets no `groups` claim, and the API reads a missing claim as "no information", so their workgroups stay as they were. To keep the claim present, the chart puts every user in `keycloak.groups` into `keycloak.defaultGroup` (`default`, which maps to the `DEFAULT` workgroup every user has anyway) and makes it the realm's default group for users created in the console (D20). If someone removes that group too, removing their last other group won't take effect until A7 lands.

The browser and the API must reach Keycloak at the same URL, `http://localhost:<CDS_KEYCLOAK_PORT>`. Keycloak listens on that port inside the cluster, and the API pod has a small `socat` container forwarding its own `localhost:<port>` to the Keycloak Service. In the same way, the web pod forwards `localhost:<CDS_API_PORT>` to the API, because the web passes the API URL to the browser for the SSO button and the sign-out redirect.

The realm is imported only when Keycloak's volume is new, so changes to `realm.json`, the ports or the passwords don't reach an existing realm. To re-import it:

```bash
tilt down
kubectl -n cohort-discovery delete pvc cohort-discovery-keycloak-data
tilt up
```

Users keep the same Keycloak IDs across re-imports, because the chart derives each ID from the realm name and the username, so the API's links to them still match. Changing a user's username (by default its email) gives it a new ID.

To run without Keycloak, set `CDS_KEYCLOAK_ENABLED=false` before `tilt up`, or pass `--set keycloak.enabled=false` to Helm. SSO is then off and only email and password sign-in is offered.

### Customising users, groups and roles

`keycloak.groups` and `keycloak.roles` list the realm's groups and realm roles; `keycloak.users` lists its users. Each user's `groups` and `realmRoles` must be in those lists, or the render fails and names the user. `username` defaults to `email`. For example, in a values file passed with `-f`:

```yaml
bootstrap:
  custodianName: Example Health Board
keycloak:
  roles: [researcher, data-custodian]
  groups: [default, ukri, Example Health Board]
  users:
    - email: alex.taylor@example.com
      firstName: Alex
      lastName: Taylor
      groups: [Example Health Board]
      realmRoles: [data-custodian]
      passwordKey: alexTaylorPassword
    - email: sam.jones@example.com
      firstName: Sam
      lastName: Jones
      groups: [ukri]
      realmRoles: [researcher]
      passwordKey: samJonesPassword
```

Every user is also put in `keycloak.defaultGroup` (`default`), which must be in `keycloak.groups`. Set it to `""` to turn that off.

Then add each new `passwordKey` to `generated/secrets.values.yaml`, under `secrets:`, with a password of your choosing. `scripts/local-secrets.sh` generates only the default users' keys; a user whose key is missing fails the render with a message that names the key.

A Keycloak name only has an effect in the app if the API maps it:

- A group becomes a workgroup only if `workgroup_mappings` in `customisations/api/claimsaccesscontrol.php` maps a workgroup to it. A workgroup can take one group or a list: `'uk-research' => ['ukri', 'ncs', 'breathe']` gives `UK-RESEARCH` to anyone in any of the three. One group can also give several workgroups (`gsk` gives `UK-INDUSTRY` and `NON-UK-INDUSTRY`). Other groups, including `default`, give no workgroup. The stack's file names its Keycloak groups and roles differently from the app's on purpose, to show the mapping.
- The workgroup itself must already exist in the app. Signing in never creates one, however much the claims are trusted. The workgroups are listed in `customisations/api/workgroups.php`: the stack seeds `UK-RESEARCH`, `UK-INDUSTRY`, `NON-UK-RESEARCH`, `NON-UK-INDUSTRY` and `NHS-SDE`, and leaves out the API's `ADMIN`, `CUSTODIAN`, `DEFAULT` and `OTHER` (the file says why). To add one, list it there. The init Job creates any that are missing on every run, matching names case-insensitively, and never deletes or renames one, so removing a name from the list doesn't remove the workgroup.
- A realm role takes effect only if `role_mappings` maps one of the API's roles (`admin`, `user`, `custodian`) to it. The stack maps them to `platform-admin`, `researcher` and `data-custodian`.
- A group also links the user to a custodian with exactly the same name, if one exists. Above, `Example Health Board` does both jobs only because `bootstrap.custodianName` creates that custodian.

To change the mappings, edit that file (see [Claims mapping](#claims-mapping)).

To change the realm's client or settings, edit `customisations/keycloak/realm.json`. The chart always replaces its `groups`, `roles`, `users` and `defaultGroups` with `keycloak.groups`, `keycloak.roles`, `keycloak.users` and `keycloak.defaultGroup`, so set those in the values, not in the file. Keep the realm name `cohort-discovery-service` and the client ID `cohort-discovery-service-api`.

Changes reach Keycloak only on a fresh import; see above.

### Claims mapping

`customisations/api/claimsaccesscontrol.php` is mounted over the API's `config/claimsaccesscontrol.php` in the API, queue and init containers (D9). It's based on the API's own file at the pinned tag. Its `workgroup_mappings` and `role_mappings` values are the Keycloak group and role names, and its `sync` section sets how each sign-in applies them: workgroups, roles and custodians are synced on every sign-in and replace what the user had. Every value is written into the file rather than read from env, and the comments list the other options. To change names or policy, edit it (see [Customisations](#customisations)).

The API's own copy reads the same settings from `CLAIM_SYNC_*` and similar env variables. They have no effect while this file is mounted, and the chart doesn't set them. When the API submodule moves to a new tag, diff the file against the new upstream one.

To check what the API sees:

```bash
kubectl -n cohort-discovery exec deploy/cohort-discovery-api -c api -- \
  php artisan tinker --execute="dump(config('claimsaccesscontrol.workgroup_mappings'))"
```

### Stop and restart

`tilt down` removes everything except the namespace and the MySQL and Keycloak volumes (`tilt.dev/down-policy: keep`), so the next `tilt up` finds the same data. The init Job runs again and changes nothing.

To start from scratch, delete the volume as well:

```bash
tilt down
kubectl -n cohort-discovery delete pvc cohort-discovery-mysql-data cohort-discovery-keycloak-data
```

Keep `generated/secrets.values.yaml` while the volume exists. MySQL sets its passwords only when it first initialises the volume, so new credentials won't match old data. The same goes for Keycloak, which keeps the client secret and passwords it imported. Delete the file and both volumes together, or none of them.

## Run with Helm alone

The chart is the whole definition; Tilt only builds images and forwards ports. Without Tilt, build the images under the tags `values.yaml` expects, so a local cluster that shares Docker's image store (Rancher Desktop with the Docker runtime, Docker Desktop, OrbStack) can use them:

```bash
export GITHUB_TOKEN=$(gh auth token)
docker build --secret id=github_token,env=GITHUB_TOKEN -t ghcr.io/hdruk/cohort-discovery-api:b257363 services/api
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
scripts/customisations-values.sh
helm install cohort-discovery charts/cohort-discovery \
  --namespace cohort-discovery --create-namespace \
  -f generated/secrets.values.yaml -f generated/customisations.values.yaml --timeout 15m
kubectl -n cohort-discovery port-forward svc/cohort-discovery-web 3000:3000
kubectl -n cohort-discovery port-forward svc/cohort-discovery-api 8100:8100
kubectl -n cohort-discovery port-forward svc/cohort-discovery-keycloak 8180:8180
```

If you forward the API or the web to other host ports, set `api.appUrl` and `web.appUrl` to match, and set `keycloak.port` to the Keycloak host port; Keycloak's forward must use the same port on both sides.

`api-init` is a `post-install,post-upgrade` hook, so `helm install` waits for it. The API, queue and NLP pods wait in their `wait-for-api-init` init containers until it has finished.

`helm uninstall` deletes the MySQL and Keycloak volumes with everything else.

## What the init Job does

`api-init` runs `charts/cohort-discovery/files/api-init/api-init.sh` in the API image. Each step is safe to repeat:

| Step | Repeat behaviour |
|---|---|
| `migrate --force`, the `omop` migrations, `deploy:run` | Only pending migrations and steps run |
| `WorkgroupSeeder` | Always runs; creates the workgroups in `customisations/api/workgroups.php` that are missing, and never deletes one |
| `RolesAndPermissionsSeeder` | Runs only when `roles` is empty; it inserts unconditionally |
| `StateSeeder`, `FeatureSeeder`, `PersonalAccessClientSeeder` | Always run; they create only what's missing |
| `MinimalOmopSeeder` | Runs only when the `omop.concept` table is empty, so it never touches a full import |
| `ensure-admin.php`: the custodian `bootstrap.custodianName` in "Demo Network", and the admin (`bootstrap.adminEmail`, role `admin`, member of that custodian, and workgroup `ADMIN` if it exists, which it doesn't by default) | Runs only when `users` is empty, so an install with users is never rewritten. It finds each record before creating it, so a run that failed part-way can be repeated |
| Scheduler service account | Created from the Secret's `scheduler-client-id` and `scheduler-client-secret`; left alone when it matches, updated when it doesn't |

The Passport keys come from the Secret through `PASSPORT_PRIVATE_KEY` and `PASSPORT_PUBLIC_KEY`, so tokens survive pod restarts. A2's `app:bootstrap` will replace the script.

## Collections: the provision Job

`provision` creates the custodians, collection hosts and collections in `customisations/provision.json` through the API, shares each collection with its `workgroups` and makes it active, so a researcher in one of those workgroups sees it straight away. It runs after the API and Keycloak are up, as a Helm `post-install`/`post-upgrade` hook, and under Tilt again whenever the file changes. It signs in as `bootstrap.adminEmail` through Keycloak (D22), so it's off when Keycloak is.

```json
{
  "custodians": [
    {
      "name": "Demo Custodian",
      "hosts": [
        {
          "name": "Synthetic Host",
          "collections": [
            {
              "name": "Synthetic Collection A",
              "description": "Synthetic OMOP data for trying the service.",
              "synthetic": true,
              "workgroups": ["UK-RESEARCH", "UK-INDUSTRY"]
            }
          ]
        }
      ]
    }
  ]
}
```

Records are matched by name, so running it again changes nothing. It never deletes or renames anything, and never removes a workgroup from a collection. A workgroup that doesn't exist (see `customisations/api/workgroups.php`) stops the run before anything is created.

For each host it writes a Secret `bunny-<host>` with the BUNNY's `TASK_API_BASE_URL`, `TASK_API_USERNAME` and `TASK_API_PASSWORD`, and a `collection-<collection>` key holding each collection's ID. The API shows a host's credentials only once, when it's created, so the Secret is the only copy: if the host exists and its Secret doesn't, the Job stops and asks you to delete the host in the app or restore the Secret. To see what it did:

```bash
kubectl -n cohort-discovery logs job/cohort-discovery-provision
```

Each collection also gets two distribution schedules, the same ones the API's `CollectionSeeder` creates: `GENERIC` (concept counts) weekly and `DEMOGRAPHICS` monthly, at 23:59 London time. Without them the `distributions-collector` job creates no type-b tasks, and the term directory and the "Last Distribution" columns stay empty. When the Job adds a schedule it also runs it once straight away, so the distributions arrive within a minute or so. A collection that already has a schedule of that type is left alone, so a schedule changed in the app stays changed.

When the Job creates a host or a collection, it restarts that host's BUNNY Deployments so they read the new IDs from the Secret.

## Synthetic collections

Each collection marked `"synthetic": true` in `provision.json` gets a BUNNY, `bunny-<collection>`, serving synthetic OMOP data, so queries return results without any real data. They describe no real people.

- One Postgres, `synthetic-db`, holds a database per synthetic collection. Its volume is kept by `tilt down`.
- On start, the BUNNY's init containers create the collection's database if it's missing and load omop-lite's bundled synthetic data into schema `omop`. omop-lite loads a schema only once, so restarts don't reload it.
- `syntheticSize` on a collection picks the bundle: 100, 1000 or 1001 people. The default is `synthetic.defaultSize` (100). Any other value fails the render. Collections of the same size return the same counts.
- Each Deployment runs two BUNNY containers: type `a` answers availability queries and type `b` collects distributions. Credentials and the collection ID come from the provision Job's `bunny-<host>` Secret, so they start once the Job has run.

To reload a collection's data, drop its database and restart its BUNNY:

```bash
kubectl -n cohort-discovery exec cohort-discovery-synthetic-db-0 -- dropdb --username=postgres synthetic_collection_a
kubectl -n cohort-discovery rollout restart deployment/cohort-discovery-bunny-synthetic-collection-a
```

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
| `bootstrap.adminEmail`, `bootstrap.custodianName` | The seeded admin and custodian, used only when `users` is empty. The admin signs in through Keycloak, so it must also be in `keycloak.users` |
| `api.appUrl`, `web.appUrl` | The API and web URLs as the browser sees them; SSO redirects are built from them |
| `keycloak.enabled`, `keycloak.port` | Keycloak and SSO on or off, and its port (inside the cluster and on the host) |
| `keycloak.groups`, `keycloak.roles`, `keycloak.users` | The realm's groups, realm roles and users; passwords are named by `passwordKey` and live in the secrets file |
| `keycloak.realmJson`, `api.claimsAccessControlPhp`, `nlp.rulesJson`, `nlp.mappingsJson`, `provision.json` | Set only by `generated/customisations.values.yaml`, from `customisations/` (see [Customisations](#customisations)) |
| `api.extraEnv`, `nlp.extraEnv`, `web.extraEnv` | Extra non-secret environment variables |
| `provision.enabled` | The provision Job on or off; it's off when `provision.json` isn't supplied |
| `synthetic.enabled`, `synthetic.defaultSize` | Synthetic BUNNYs on or off, and the default omop-lite bundle |
| `synthetic.bunny.*` | BUNNY polling interval, low-number suppression and rounding |
| `synthetic.storageSize`, `synthetic.storageClassName`, `synthetic.resources`, `synthetic.bunnyResources` | The synthetic Postgres's volume, and resources |
| `scheduler.*` | Scheduled jobs |
| `secrets.*` | Set only by `generated/secrets.values.yaml`; never in `values.yaml` |

## Customisations

Everything a deployer is expected to change lives in `customisations/`, one folder per service:

| Path | What | How it's used |
|---|---|---|
| `customisations/api/auth.php` | Authentication settings: password sign-in is off (see [Sign in](#sign-in)) | Mounted over the API's own |
| `customisations/api/claimsaccesscontrol.php` | The claims mapping (see [Claims mapping](#claims-mapping)) | Mounted over the API's own |
| `customisations/api/workgroups.php` | The workgroups the app has (see [Customising users, groups and roles](#customising-users-groups-and-roles)) | Mounted over the API's own; the init Job seeds it |
| `customisations/keycloak/realm.json` | The Keycloak realm's client and settings | Imported by Keycloak, with the groups, roles and users from the values |
| `customisations/keycloak/theme/` | The Keycloak sign-in page's look (see [Keycloak sign-in page](#keycloak-sign-in-page)) | Mounted into Keycloak as the `cohort-discovery` theme |
| `customisations/nlp/rules.json`, `mappings.json` | The NLP rules and mappings | Mounted into the NLP |
| `customisations/provision.json` | Custodians, hosts and collections, and the workgroups each collection is shared with (see [Collections](#collections-the-provision-job)) | Created through the API by the provision Job |
| `customisations/web/branding/` | The web's branding (see [Branding](#branding)) | Built into the web image |

Helm can only read files inside the chart, so `scripts/customisations-values.sh` copies the `api`, `keycloak` and `nlp` files and `provision.json` into `generated/customisations.values.yaml` (as `api.authPhp`, `api.claimsAccessControlPhp`, `api.workgroupsPhp`, `keycloak.realmJson`, `keycloak.themeFiles`, `nlp.rulesJson`, `nlp.mappingsJson` and `provision.json`), which is passed to Helm with `-f`. Tilt runs it on every start and when those folders change. The branding is used when the web image is built, not by the chart.

You can delete files you don't want to change. Without an NLP file, nothing is mounted and the NLP uses its own copy, which is identical at the pinned tag. Without the claims mapping, the API uses its own copy, which syncs workgroups only on first sign-in and never removes them, so Keycloak is no longer the source of truth for access. Without `workgroups.php`, the API seeds its own nine workgroups. Without `auth.php`, password sign-in is back on. Without `provision.json`, no collections are created. Keycloak has no default, so the chart fails with a message if it's on and there's no realm. To keep your customisations somewhere else, pass that folder: `scripts/customisations-values.sh <folder>`.

## Branding

The web is branded at build time, so changing the branding means rebuilding the web image. The stack ships a neutral brand, "Feasibility Tool", in `customisations/web/branding/`:

| File | What |
|---|---|
| `branding.config.ts` | Product name, sign-in page text, organisation name and link, legal page titles |
| `theme.ts` | Colours and font, merged over the web's base theme. Set `primary` and `secondary`, or the web's own defaults show through |
| `assets/logo.svg` | The header logo, shown on the `secondary` colour at 30px high, so it needs light artwork. Also the Keycloak sign-in page's logo |
| `assets/icon.svg` | The favicon, a square version of the logo's mark. Used as the Keycloak sign-in page's favicon. The web doesn't use it yet (W3) |
| `legal/termsAndConditions.mdx`, `legal/privacyPolicy.mdx` | Placeholders that say they must be replaced before anyone signs in |

`scripts/build-web.sh <image> [docker build options]` copies `services/web` to a temporary folder, copies `customisations/web/branding/` over its `branding/`, and runs the web's own Dockerfile (D6). Any file you leave out of `customisations/web/branding/` falls back to the web's own. Tilt rebuilds the web when anything in it changes.

Before a real deployment, replace the legal pages and set `organisationName`, `copyrightHolder` and `links.organisation` in `branding.config.ts`. Footer links such as the cookie notice are built from `links.organisation` unless `links.cookieNotice` and `links.accessibilityStatement` are set.

Some HDR UK branding still comes from the web itself rather than `branding/`, for example the copyright text and the favicon. W3 tracks fixing that upstream. Until then, the web's tab shows its own favicon from `src/app/`, and `assets/icon.svg` is only used by Keycloak.

### Keycloak sign-in page

`customisations/keycloak/theme/` is a Keycloak login theme. It extends Keycloak's own `keycloak.v2` theme and restyles it to match the web: the ink background, the petrol buttons, an amber bar on the card, and the logo in place of the realm name. `realm.json` selects it with `"loginTheme": "cohort-discovery"`.

| File | What |
|---|---|
| `login/theme.properties` | The parent theme, the stylesheets and the favicon |
| `login/resources/css/customisations.css` | The colours and layout, mostly as PatternFly variables. Keep the colours in step with `customisations/web/branding/theme.ts` |

The logo and favicon aren't copied into the theme: `scripts/customisations-values.sh` takes `customisations/web/branding/assets/logo.svg` and `icon.svg` and serves them as the theme's `img/logo.svg` and `img/icon.svg`, so the web and Keycloak share one copy. Other files you add under `theme/` are mounted at the same path in `/opt/keycloak/themes/cohort-discovery/`, for example a `login/messages/messages_en.properties` to change the page's wording.

Theme changes reach a running Keycloak without a re-import: Tilt restarts it when the files change. Turning the theme on for a realm imported before it existed needs a re-import, because `loginTheme` is part of `realm.json` (see [Single sign-on](#single-sign-on-keycloak)). Without the `theme/` folder, Keycloak logs `Failed to find LOGIN theme cohort-discovery` and uses its own look.

## Layout

| Path | What |
|---|---|
| `services/` | web, API and NLP submodules |
| `charts/cohort-discovery/` | the Helm chart: the one definition of the stack |
| `charts/cohort-discovery/files/api-init/` | the init Job's scripts |
| `customisations/` | everything a deployer changes: claims mapping, Keycloak realm, NLP rules and mappings, web branding (D21) |
| `scripts/` | `local-secrets.sh`, `customisations-values.sh`, `build-web.sh` |
| `generated/` | git-ignored: local secrets and the customisations values file |
| `Tiltfile` | local development |

`customisations/provision.json` arrives with S4.
