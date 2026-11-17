# Installing beyond a laptop

The same chart runs on a shared cluster. Read [Running with Helm](../running/helm.md) first: building the images and the two scripts work the same way.

!!! warning "Before real people sign in"
    The service stores researchers' email addresses, identity-provider claims and activity logs. Read the [personal data inventory](../data-protection/personal-data-inventory.md), replace the placeholder legal pages (see [Branding](../customising/branding.md)), and don't use the example users or synthetic collections in a live service.

## Start from an example

Two example values files show the ends of the range. Pass one with `-f` on top of the chart's defaults:

| File | What |
|---|---|
| `charts/cohort-discovery/values.evaluation.yaml` | Everything bundled (MySQL, Redis, Keycloak, synthetic collections), behind an ingress with TLS. For a shared trial |
| `charts/cohort-discovery/values.production-like.yaml` | External MySQL, Redis and identity provider, secrets from a Secret you create, no synthetic collections or provisioning |

Copy one, replace the `example.org` hosts, and install:

```bash
scripts/customisations-values.sh
helm install cohort-discovery charts/cohort-discovery \
  --namespace cohort-discovery --create-namespace \
  -f my-values.yaml -f generated/customisations.values.yaml --timeout 15m
```

Images: until images are published, build them as in [Running with Helm](../running/helm.md), push them to a registry your cluster can pull from, and set `images.<name>.repository` and `.tag`.

## URLs and ingress

`web.appUrl`, `api.appUrl` and, with the bundled Keycloak, `keycloak.url` are the URLs people's browsers use. Single sign-on redirects are built from them.

`ingress.enabled: true` routes each URL's host to its Service, with `ingress.className`, `ingress.annotations` and the usual `ingress.tls` list. An ingress with a bare `localhost` URL fails the render, but `*.localhost` hosts work, which is how to try the ingress on a laptop: `http://cds.localhost` and so on reach a local ingress controller on port 80 without any DNS.

**Serve the stack over HTTPS.** The web sets its sign-in cookie with `Secure`, which browsers only accept over HTTPS or on `localhost`. Behind an ingress, Keycloak trusts the `X-Forwarded-*` headers.

The API, the web server and the provision Job call these URLs from inside the cluster too, so their hosts must resolve there. With `localhost` and `*.localhost` URLs the chart handles this itself. Other hosts need DNS that works inside the cluster, or `hostAliases` pointing them at the ingress controller:

```yaml
hostAliases:
  - ip: 10.43.0.10
    hostnames: [cds.example.org, api.cds.example.org, auth.cds.example.org]
```

**The web image is built for one API URL.** Build it with `scripts/build-web.sh`, passing your `api.appUrl` as `API_BASE_URL` and `api.appUrl` plus `/api/v1` as `NEXT_PUBLIC_TASK_URL`. Making the API URL a run-time setting is on the [tracker](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/README.md).

## External MySQL and Redis

With `mysql.enabled: false`, set `mysql.host` and `mysql.port`. The user `mysql.username`, with the `mysql-password` secret, needs all privileges on both `mysql.appDatabase` and `mysql.omopDatabase`, which must already exist. For the full vocabulary import, the server needs `local_infile=1`.

With `redis.enabled: false`, set `redis.host` and `redis.port`. If it needs a password, set `redis.auth: true` and add the `redis-password` secret.

## Uploaded files

The API saves the files BUNNYs upload (distribution results) and the queue worker reads them back. They run as separate Deployments, so they share a volume, `cohort-discovery-api-storage`, set by `api.storageSize`, `api.storageClassName` and `api.storageAccessMode`.

`ReadWriteOnce`, the default, only works while both pods run on the same node, which is always true on a one-node cluster. On a cluster with more nodes, set `api.storageAccessMode: ReadWriteMany` and a storage class that supports it, such as NFS, EFS or Filestore.

## External identity provider

With `keycloak.enabled: false`, set `sso.issuer` (the OIDC issuer URL), `sso.clientId` and the `sso-client-secret` secret. In the provider:

- register `<api.appUrl>/api/auth/sso/default/callback` as the client's redirect URI;
- register `<web.appUrl>/login` as its post-logout redirect;
- make sure the ID token carries `groups` and `roles` claims, and that [the claims mapping](../customising/identity-and-access.md#map-keycloak-names-to-the-app) matches their values;
- create `bootstrap.adminEmail` as a user, with a verified email.

The provision Job signs in by filling in Keycloak's login form, so it works with an external Keycloak (using the `admin-password` secret as the admin's password there) but not with other providers. With another provider, set `provision.enabled: false` and create collections in the app.

## Secrets

Locally, `scripts/local-secrets.sh` writes every secret to `generated/secrets.values.yaml` and the chart turns them into a Secret. Elsewhere, create the Secret yourself, with your own tooling, and name it in `secrets.existingSecret`. The chart then renders no Secret. It needs these keys:

| Key | When |
|---|---|
| `app-key` (`base64:` followed by 32 random bytes, base64-encoded), `jwt-secret`, `collection-hosts-key-salt-1`, `collection-hosts-key-salt-2` | Always |
| `passport-private-key`, `passport-public-key` | Always: an RSA key pair, PEM |
| `admin-password`, `scheduler-client-id` (a UUID), `scheduler-client-secret` | Always |
| `mysql-password` | Always |
| `mysql-root-password` | Bundled MySQL |
| `redis-password` | `redis.auth: true` |
| `keycloak-admin-password`, `keycloak-client-secret`, and `keycloak-user-<passwordKey in kebab case>` for each `keycloak.users` entry | Bundled Keycloak |
| `sso-client-secret` | External identity provider |
| `synthetic-db-password` | Synthetic collections |

## Resources

Every container has CPU and memory requests and a memory limit, set in the values (`*.resources`, plus `waitResources` for the init containers). There are no CPU limits: throttling slows the API's and NLP's start-up without protecting the node, and the requests already reserve CPU. The `vocab-import` Job allows 4Gi of memory for large vocabulary tables. See [Chart values](../reference/values.md) for each one.
