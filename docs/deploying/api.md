# The API

The API is the Laravel service at the centre of the stack (`services/api`, from [`HDRUK/project-daphne-api`](https://github.com/HDRUK/project-daphne-api)). The service docs' [API developer guide](https://hdruk.github.io/cohort-discovery-service-docs/developers/api/) explains the code; this page explains how the stack builds and configures it.

## What it runs

One image runs four things, all with the same configuration:

| Runs as | What |
|---|---|
| The `cohort-discovery-api` Deployment | The HTTP API, on `api.port` (8100) |
| The `cohort-discovery-queue` Deployment | The queue worker (`php artisan horizon`), which runs jobs from Redis, such as processing the files BUNNYs upload |
| The `api-init` Job | Migrations, seeding and the first admin, on every install and upgrade. See [Internals](../reference/internals.md#api-init) |
| The `vocab-import` Job | The full vocabulary import, when you set `vocab.athena.hostPath` or `vocab.athena.existingClaim`. See [Database and vocabulary](database.md) |

## Build the image

```bash
REGISTRY=registry.example.org/cohort-discovery
export GITHUB_TOKEN=$(gh auth token)
docker build --secret id=github_token,env=GITHUB_TOKEN -t $REGISTRY/api:1 services/api
docker push $REGISTRY/api:1
```

- **The build needs a GitHub token.** The Dockerfile writes it to `/tmp/composer/auth.json` and doesn't delete it, so **the token stays in the image**. Use a token with read-only access, and push the image only to a private registry.
- **Build from a clean checkout.** The API has no `.dockerignore`, so a local `.env` or key file in `services/api` is copied into the image and read at run time.
- **Build for your cluster's CPU architecture**: add `--platform linux/amd64` on an Apple Silicon Mac.
- **The chart supplies the settings.** Built from a clean checkout, one image works for any URL, database or identity provider, so you rebuild only to change the code.

## Use your own image

To run another build, such as a fork or a newer release, point the chart at it:

```yaml
images:
  api: { repository: registry.example.org/cohort-discovery/api, tag: "1" }
```

The API, queue worker, `api-init` and `vocab-import` all use it. Your image must keep the release's layout: the chart runs `php artisan` in `/var/www`, mounts config files over `/var/www/config/`, and mounts the file store at `/var/www/storage/app/private`.

## Configure it

The chart configures the API in three ways.

### Values

| Value | Default | What |
|---|---|---|
| `api.appUrl` | `http://localhost:8100` | The API's URL as the browser sees it. Single sign-on redirects are built from it |
| `api.appEnv` | `production` | Laravel's `APP_ENV` |
| `api.logLevel` | `info` | Laravel's log level. Logs go to stderr |
| `api.standaloneJwtTtlMinutes` | `120` | How long a sign-in lasts, in minutes |
| `api.port` | `8100` | The container and Service port |
| `api.resources`, `queue.resources` | | Requests and memory limits for the API and the queue worker |

From these and the other parts' values, the chart writes the environment to the `cohort-discovery-api-env` ConfigMap:

| Settings | Set from |
|---|---|
| `APP_URL`, `APP_ENV`, `LOG_LEVEL`, `PORT`, `STANDALONE_JWT_TTL_MINUTES` | The `api.*` values above. `APP_OPERATION_MODE` is always `standalone` |
| `DB_*`, `DB_OMOP_DATABASE` | `mysql.*`. See [Database and vocabulary](database.md) |
| `REDIS_*`; the queue, cache and sessions use Redis | `redis.*`. See [Supporting services](services.md#redis) |
| `COHORT_DISCOVER_NLP_SERVICE_BASE_URI` | The NLP's in-cluster Service |
| `SSO_*` | `keycloak.*`, `sso.*`, `api.appUrl` and `web.appUrl`. See [Sign-in](sign-in.md) |
| `AUTH_PASSWORD_LOGIN_ENABLED` | Always `true`, but the stack's `auth.php` (below) overrides it. See [Password sign-in](sign-in.md#password-sign-in) |

### Config files

Three of the API's Laravel config files are replaced by your copies in `customisations/api/`. `scripts/customisations-values.sh` puts them in `api.authPhp`, `api.claimsAccessControlPhp` and `api.workgroupsPhp`, and the chart mounts each one over the file of the same name in `/var/www/config/`:

| File | What |
|---|---|
| `auth.php` | Whether password sign-in is offered alongside single sign-on. See [Sign-in](sign-in.md#password-sign-in) |
| `claimsaccesscontrol.php` | How identity-provider groups and roles map to the app's roles, custodians and workgroups. See [Identity and access](../customising/identity-and-access.md#map-keycloak-names-to-the-app) |
| `workgroups.php` | The workgroups `api-init` creates |

Each file replaces the service's whole file, so start from the release's copy. After an upgrade, compare yours with the new release's.

### Anything else: `api.extraEnv`

Any other setting the API reads from its environment goes in `api.extraEnv`, for example:

```yaml
api:
  extraEnv:
    COLLECTION_INACTIVITY_MINUTES: "60"
```

It's added to the same ConfigMap, so the API, queue worker and setup Jobs all get it. Use it only for settings the chart doesn't set: a key from the tables above would appear twice in the ConfigMap, which may fail the install, so change those through their values instead. It isn't for secrets, because ConfigMaps aren't encrypted. The service docs list the [API's environment variables](https://hdruk.github.io/cohort-discovery-service-docs/developers/api/#environment-variables), and the files in `services/api/config/` show every setting the API reads (`env('…')`), with its default.

## Secrets it reads

`app-key`, `jwt-secret`, `passport-private-key`, `passport-public-key`, `collection-hosts-key-salt-1`, `collection-hosts-key-salt-2` and `mysql-password`, always. Also `redis-password` with `redis.auth: true`, and the client secret with single sign-on on. `api-init` also reads `admin-password` and the scheduler's credentials. See [Create the secrets](index.md#4-create-the-secrets).

## File storage

The API saves files BUNNYs upload, and the queue worker reads them back, through a shared volume (`api.storageSize`, `api.storageClassName`, `api.storageAccessMode`). The default, `ReadWriteOnce`, only works while both pods are on the same node. On a cluster with more nodes, set `api.storageAccessMode: ReadWriteMany` and a storage class that supports it, such as NFS, EFS or Filestore.
