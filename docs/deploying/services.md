# Supporting services

Besides the API, web, NLP, MySQL and sign-in, the chart runs a few smaller parts. Most need no configuration, but each can be changed or replaced.

## Redis

The API keeps its queue, cache and sessions in Redis.

=== "Bundled (the default)"

    `redis.enabled: true` runs Redis 7.2 with no password and no persistence, so a restart loses whatever is queued or cached.

=== "External"

    ```yaml
    redis:
      enabled: false
      host: redis.example.org
      port: 6379
      auth: true
    ```

    With `auth: true`, put the password in `redis-password`. `redis.auth` is for an external Redis only: the bundled one has no password. Likewise leave `redis.port` at 6379 with the bundled one.

## Queue worker

The `cohort-discovery-queue` Deployment runs the API image as the queue worker (`php artisan horizon`). It has the API's configuration and file store, so there's nothing to set apart from `queue.resources`. See [The API](api.md).

## Scheduled jobs

Four CronJobs call the API every minute, as a cloud scheduler does in HDR UK's own deployments. Each runs `curl` (the `images.curl` image) to `POST /api/v1/services/caller/<job>`, signed in with the `scheduler-client-id` and `scheduler-client-secret` secrets. `api-init` creates the matching service account in the API, and updates it when the secrets change.

| Value | Default | What |
|---|---|---|
| `scheduler.enabled` | `true` | `false` turns all four off. Distributions then stop, and inactive collections are never suspended |
| `scheduler.jobs.<job>` | every minute | Each job's cron schedule |
| `scheduler.timeZone` | `Etc/UTC` | The time zone the schedules are read in |
| `scheduler.resources` | | Requests and memory limit for each run |

To use your own scheduler instead, set `scheduler.enabled: false` and have it make the same calls. [Scheduled jobs](../reference/scheduled-jobs.md) says what each job does.

## Setup Jobs

Helm runs these after every install and upgrade, and waits for them. Each is safe to run again.

| Job | Image | What | Turn off with |
|---|---|---|---|
| `api-init` | The API | Migrations, seeding, the first admin, the scheduler's account | Always runs |
| `vocab-import` | The API | The full vocabulary import. See [Database and vocabulary](database.md#the-vocabulary) | Runs only with `vocab.athena.hostPath` or `vocab.athena.existingClaim` |
| `provision` | `images.python` | Custodians, collection hosts and collections from `customisations/provision.json`. See [Collections](../customising/collections.md) | `provision.enabled: false` |

With provisioning on, `synthetic.enabled` adds one Postgres (`images.postgres`) holding a synthetic database for each synthetic collection in `provision.json`, loaded with `images.omopLite`, and a BUNNY pod (`images.bunny`, type A and type B) for each. Turn it off for a real service. [Internals](../reference/internals.md) has the details.

## URLs and ingress

`web.appUrl`, `api.appUrl` and, with the bundled Keycloak, `keycloak.url` are the URLs people's browsers use. Single sign-on redirects are built from them. `ingress.enabled: true` routes each URL's host to its Service, with `ingress.className`, `ingress.annotations` and the usual `ingress.tls` list.

**Serve the stack over HTTPS.** The web sets its sign-in cookie with `Secure`, which browsers only accept over HTTPS or on `localhost`.

The API, the web server and the provision Job also call these URLs from inside the cluster, so the hosts must resolve there. Use DNS that works inside the cluster, or `hostAliases` pointing them at the ingress controller:

```yaml
hostAliases:
  - ip: 10.43.0.10
    hostnames: [cds.example.org, api.cds.example.org, auth.cds.example.org]
```

To try the ingress on a laptop, use `*.localhost` hosts (`http://cds.localhost` and so on): they reach a local ingress controller on port 80 with no DNS, and the chart handles them inside the cluster. A bare `localhost` URL with the ingress on fails the install.

## Third-party images

Every image the chart runs is in `images.*`, pinned to a tag: `mysql`, `redis`, `keycloak`, `curl`, `socat`, `python`, `postgres`, `omopLite` and `bunny`, as well as `api`, `web` and `nlp`. To pull from a mirror, set the repository and keep the tag:

```yaml
images:
  redis: { repository: mirror.example.org/library/redis, tag: 7.2.13 }
```

`imagePullPolicy` applies to all of them.

If a registry needs credentials, create a pull secret in the namespace and name it in `imagePullSecrets`. Every pod uses it:

```bash
kubectl -n cohort-discovery create secret docker-registry registry-credentials \
  --docker-server=registry.example.org --docker-username='<user>' --docker-password='<token>'
```

```yaml
imagePullSecrets:
  - name: registry-credentials
```

## Resources

Every container has CPU and memory requests and a memory limit (`*.resources`), and no CPU limit. See [Chart values](../reference/values.md).
