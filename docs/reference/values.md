# Chart values

Every setting in `charts/cohort-discovery/values.yaml`. Override them in a values file of your own, passed with `-f`. Values marked *generated* are set from `customisations/` by `scripts/customisations-values.sh`; don't set them by hand.

No secret has a value here. Secrets go in `generated/secrets.values.yaml` under `secrets:`, or in a Secret you create; see [Secrets](../deploying/index.md#3-create-the-secrets).

## General

| Value | Default | What |
|---|---|---|
| `imagePullPolicy` | `IfNotPresent` | For every container |
| `hostAliases` | `[]` | Host entries added to pods, for clusters that can't resolve the public hostnames. See [URLs and ingress](../deploying/index.md#urls-and-ingress) |
| `waitResources` | small | Resources for the init containers that wait for other parts |
| `images.<name>.repository`, `.tag` | pinned | The image for each part: `api`, `nlp`, `web`, `mysql`, `redis`, `curl`, `keycloak`, `socat`, `python`, `postgres`, `omopLite`, `bunny`. Every tag is pinned |

## Bootstrap

| Value | Default | What |
|---|---|---|
| `bootstrap.adminEmail` | `admin@example.com` | The admin `api-init` creates when the app has no users, and the user the provision Job signs in as. Must also be in `keycloak.users`. See [Change the admin](../customising/identity-and-access.md#change-the-admin) |
| `bootstrap.custodianName` | `Demo Custodian` | The custodian `api-init` creates with the admin |

## API

| Value | Default | What |
|---|---|---|
| `api.port` | `8100` | The container and Service port |
| `api.appUrl` | `http://localhost:8100` | The API's URL as the browser sees it. Single sign-on redirects are built from it |
| `api.appEnv` | `production` | Laravel's `APP_ENV` |
| `api.logLevel` | `info` | Laravel's log level |
| `api.standaloneJwtTtlMinutes` | `120` | How long a sign-in lasts, in minutes |
| `api.authPhp`, `api.claimsAccessControlPhp`, `api.workgroupsPhp` | *generated* | From `customisations/api/` |
| `api.extraEnv` | `{}` | Extra non-secret environment variables for the API, queue, `api-init` and `vocab-import` containers |
| `api.storageSize`, `api.storageClassName`, `api.storageAccessMode` | `5Gi`, cluster default, `ReadWriteOnce` | The volume the API and queue share for uploaded files. See [Storage](../deploying/index.md#storage) |
| `api.resources`, `queue.resources` | | Requests and memory limits |

## NLP

| Value | Default | What |
|---|---|---|
| `nlp.port` | `5001` | The container and Service port |
| `nlp.appEnv` | `production` | The NLP's `APP_ENV` |
| `nlp.logLevel` | `INFO` | `INFO` or `DEBUG` |
| `nlp.rulesJson`, `nlp.mappingsJson` | *generated* | From `customisations/nlp/`. See [NLP rules](../customising/nlp.md) |
| `nlp.extraEnv`, `nlp.resources` | | Extra environment variables; requests and memory limit |

## Web

| Value | Default | What |
|---|---|---|
| `web.port` | `3000` | The container and Service port |
| `web.appUrl` | `http://localhost:3000` | The web's URL as the browser sees it |
| `web.cookieTokenName` | `cds_stack_token` | The sign-in cookie's name, so the stack doesn't share a sign-in with other copies of the web app on the same host |
| `web.extraEnv`, `web.resources` | | Extra environment variables; requests and memory limit |

The web's server reads `API_BASE_URL` at run time: the chart sets it from `api.appUrl` when sign-in is on, otherwise to the API's in-cluster address. Which web settings are built into the image is in the service docs' [web page](https://hdruk.github.io/cohort-discovery-service-docs/developers/web/).

## Keycloak

| Value | Default | What |
|---|---|---|
| `keycloak.enabled` | `true` | Run the bundled Keycloak. Off, set `sso.*` for another provider, or nobody can sign in with single sign-on |
| `keycloak.port` | `8180` | Its port, both inside the cluster and on the host |
| `keycloak.url` | `http://localhost:<port>` | Its URL as the browser sees it |
| `keycloak.realmJson`, `keycloak.themeFiles` | *generated* | From `customisations/keycloak/` |
| `keycloak.roles`, `keycloak.groups`, `keycloak.users`, `keycloak.defaultGroup` | three fictional users | The realm's roles, groups and users. See [Identity and access](../customising/identity-and-access.md#add-a-user) |
| `keycloak.storageSize`, `keycloak.storageClassName` | `1Gi`, cluster default | Its volume |
| `keycloak.resources` | | Requests and memory limit |
| `sso.issuer`, `sso.clientId` | empty | Another OIDC provider, used when `keycloak.enabled` is `false`. See [Identity provider](../deploying/index.md#identity-provider) |

## Data stores

| Value | Default | What |
|---|---|---|
| `mysql.enabled` | `true` | Run the bundled MySQL. Off, set `mysql.host` |
| `mysql.host`, `mysql.port` | empty, `3306` | An external MySQL |
| `mysql.appDatabase`, `mysql.omopDatabase` | `cohort_discovery`, `omop` | The two databases |
| `mysql.username` | `cohort_discovery` | The app's MySQL user |
| `mysql.storageSize`, `mysql.storageClassName` | `10Gi`, cluster default | The bundled MySQL's volume. A full vocabulary needs more |
| `redis.enabled` | `true` | Run the bundled Redis. Off, set `redis.host` |
| `redis.host`, `redis.port`, `redis.auth` | empty, `6379`, `false` | An external Redis, and whether it needs the `redis-password` secret |
| `mysql.resources`, `redis.resources` | | Requests and memory limits |

## Ingress

| Value | Default | What |
|---|---|---|
| `ingress.enabled` | `false` | Route the web, API and Keycloak hosts through an Ingress |
| `ingress.className`, `ingress.annotations`, `ingress.tls` | empty | The usual Ingress settings |

## Setup Jobs

| Value | Default | What |
|---|---|---|
| `init.resources` | | The `api-init` Job |
| `provision.enabled` | `true` | Run the provision Job. It also needs `provision.json` and Keycloak |
| `provision.json` | *generated* | From `customisations/provision.json` |
| `provision.resources` | | |
| `vocab.athena.hostPath` | empty | The node folder holding an Athena download. Setting it turns on the `vocab-import` Job. See [Vocabulary](../customising/vocabulary.md) |
| `vocab.resources` | 4Gi memory limit | |
| `socat.resources` | small | The small forwarding containers that let pods reach `localhost` URLs |

## Synthetic collections

| Value | Default | What |
|---|---|---|
| `synthetic.enabled` | `true` | Run a BUNNY for each synthetic collection in `provision.json` |
| `synthetic.defaultSize` | `100` | The synthetic bundle when a collection has no `syntheticSize` |
| `synthetic.bunny.pollingInterval`, `.lowNumberSuppressionThreshold`, `.roundingTarget` | `5`, `10`, `10` | See [Collections](../customising/collections.md#synthetic-collections) |
| `synthetic.storageSize`, `synthetic.storageClassName` | `5Gi`, cluster default | The synthetic Postgres's volume |
| `synthetic.resources`, `synthetic.bunnyResources`, `synthetic.loadResources` | | The Postgres, the BUNNYs, and the init containers that load the data |

## Scheduled jobs

| Value | Default | What |
|---|---|---|
| `scheduler.enabled` | `true` | Run the four CronJobs |
| `scheduler.jobs.<name>` | every minute | Each job's cron schedule. See [Scheduled jobs](scheduled-jobs.md) |
| `scheduler.timeZone` | `Etc/UTC` | The time zone for the schedules |
| `scheduler.serviceAccountName` | `scheduler` | The name of the API service account the jobs call it as |
| `scheduler.resources` | | |

## Secrets

| Value | What |
|---|---|
| `secrets.*` | Set only by `generated/secrets.values.yaml` |
| `secrets.existingSecret` | The name of a Secret you created, used instead. See [Secrets](../deploying/index.md#3-create-the-secrets) |
