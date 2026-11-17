# Deploy to a cluster

This page installs the stack on a shared Kubernetes cluster with Helm, in the order you'll need to do things. To run it on your own machine first, see [Run locally](../getting-started.md).

!!! warning "Before real people sign in"
    The service stores researchers' email addresses, identity-provider claims and activity logs. Read the [personal data inventory](../data-protection/personal-data-inventory.md) and the [known limitations](#known-limitations) below, and replace the placeholder legal pages (see [Branding](../customising/branding.md)). For how custodians' data is protected, see the service docs on [data governance](https://hdruk.github.io/cohort-discovery-service-docs/architecture/governance/).

## 1. Choose a starting point

Two example values files in `charts/cohort-discovery/` show the ends of the range:

| File | What | Good for |
|---|---|---|
| `values.evaluation.yaml` | Everything bundled (MySQL, Redis, Keycloak, synthetic collections), behind an ingress with TLS | A shared trial with fictional users. Not for real users: the bundled Keycloak runs in development mode |
| `values.production-like.yaml` | External MySQL, Redis and identity provider, secrets from a Secret you create, no synthetic collections or provisioning | A real service |

Copy one to `my-values.yaml` and choose your hostnames now, because the steps below use them. The examples use three: `cds.example.org` (web), `api.cds.example.org` (API) and `auth.cds.example.org` (Keycloak).

## 2. Build and push the images

Images aren't published yet, so build them from `services/` and push them to a registry your cluster can pull from.

!!! note
    The API build needs a GitHub token that can read HDR UK's private `hdruk/*` composer packages, for now.

```bash
REGISTRY=registry.example.org/cohort-discovery
API_URL=https://api.cds.example.org
export GITHUB_TOKEN=$(gh auth token)

docker build --secret id=github_token,env=GITHUB_TOKEN -t $REGISTRY/api:1 services/api
docker build -t $REGISTRY/nlp:1 services/nlp
scripts/build-web.sh $REGISTRY/web:1 \
  --build-arg APPLICATION_MODE=standalone \
  --build-arg API_BASE_URL=$API_URL \
  --build-arg NEXT_PUBLIC_TASK_URL=$API_URL/api/v1 \
  --build-arg NEXT_PUBLIC_USE_EXAMPLE_QUERY=false \
  --build-arg NEXT_PUBLIC_USE_DEBUG_LOGS=false
docker push $REGISTRY/api:1 && docker push $REGISTRY/nlp:1 && docker push $REGISTRY/web:1
```

Build for your cluster's CPU architecture (add `--platform linux/amd64` on an Apple Silicon Mac). `scripts/build-web.sh` builds the web with your branding from `customisations/web/branding/`.

The web's build arguments are fixed into the image:

| Build argument | What |
|---|---|
| `APPLICATION_MODE` | Always `standalone` for this stack |
| `NEXT_PUBLIC_TASK_URL` | Your API's URL plus `/api/v1`. The web shows it to custodians as the URL for their BUNNY, and builds the footer's "API docs" link from it. No request uses it |
| `API_BASE_URL` | Has no effect in the browser: the chart sets it at run time, from `api.appUrl` with sign-in on, otherwise the API's in-cluster address |
| `NEXT_PUBLIC_USE_EXAMPLE_QUERY` | `true` starts the query builder with an example query |
| `NEXT_PUBLIC_USE_DEBUG_LOGS` | `true` turns on the web's debug logging in the browser |

Then point the chart at your images in `my-values.yaml`:

```yaml
images:
  api: { repository: registry.example.org/cohort-discovery/api, tag: "1" }
  nlp: { repository: registry.example.org/cohort-discovery/nlp, tag: "1" }
  web: { repository: registry.example.org/cohort-discovery/web, tag: "1" }
```

If the registry needs credentials, see [known limitations](#known-limitations).

## 3. Create the secrets

=== "Evaluation: a generated values file"

    `scripts/local-secrets.sh` writes random credentials to `generated/secrets.values.yaml`, and the chart turns them into a Secret. Pass the file to every `helm install` and `helm upgrade`, and keep it: MySQL, Keycloak and the synthetic Postgres keep the passwords they were first given.

    ```bash
    scripts/local-secrets.sh
    ```

=== "Production: a Secret you create"

    Create the Secret yourself and set `secrets.existingSecret` to its name; the chart then renders none. This example has an external MySQL, Redis with a password, and an external identity provider, as in `values.production-like.yaml`:

    ```bash
    kubectl create namespace cohort-discovery
    openssl genrsa -out passport-private.key 4096
    openssl rsa -in passport-private.key -pubout -out passport-public.key

    kubectl -n cohort-discovery create secret generic cohort-discovery-secrets \
      --from-literal=app-key="base64:$(openssl rand -base64 32)" \
      --from-literal=jwt-secret="$(openssl rand -hex 32)" \
      --from-literal=collection-hosts-key-salt-1="$(openssl rand -hex 32)" \
      --from-literal=collection-hosts-key-salt-2="$(openssl rand -hex 32)" \
      --from-literal=admin-password="$(openssl rand -hex 12)" \
      --from-literal=scheduler-client-id="$(uuidgen | tr 'A-Z' 'a-z')" \
      --from-literal=scheduler-client-secret="$(openssl rand -hex 32)" \
      --from-file=passport-private-key=passport-private.key \
      --from-file=passport-public-key=passport-public.key \
      --from-literal=mysql-password='<your MySQL password>' \
      --from-literal=redis-password='<your Redis password>' \
      --from-literal=sso-client-secret='<your client secret>'

    rm passport-private.key passport-public.key
    ```

    Or create it with your own secrets tooling, with the same keys. Never change `app-key`, the Passport keys or the salts afterwards: sign-ins and BUNNY credentials depend on them.

    | Key | Needed when |
    |---|---|
    | `app-key`, `jwt-secret`, `collection-hosts-key-salt-1`, `collection-hosts-key-salt-2`, `passport-private-key`, `passport-public-key`, `admin-password`, `scheduler-client-id`, `scheduler-client-secret`, `mysql-password` | Always |
    | `mysql-root-password` | Bundled MySQL |
    | `redis-password` | `redis.auth: true` |
    | `keycloak-admin-password`, `keycloak-client-secret`, and `keycloak-user-<passwordKey in kebab case>` for each `keycloak.users` entry | Bundled Keycloak |
    | `sso-client-secret` | External identity provider |
    | `synthetic-db-password` | Synthetic collections |

## 4. Write the values file

### URLs and ingress

`web.appUrl`, `api.appUrl` and, with the bundled Keycloak, `keycloak.url` are the URLs people's browsers use. Single sign-on redirects are built from them. `ingress.enabled: true` routes each URL's host to its Service, with `ingress.className`, `ingress.annotations` and the usual `ingress.tls` list.

**Serve the stack over HTTPS.** The web sets its sign-in cookie with `Secure`, which browsers only accept over HTTPS or on `localhost`.

The API, the web server and the provision Job also call these URLs from inside the cluster, so the hosts must resolve there. Use DNS that works inside the cluster, or `hostAliases` pointing them at the ingress controller:

```yaml
hostAliases:
  - ip: 10.43.0.10
    hostnames: [cds.example.org, api.cds.example.org, auth.cds.example.org]
```

To try the ingress on a laptop, use `*.localhost` hosts (`http://cds.localhost` and so on): they reach a local ingress controller on port 80 with no DNS, and the chart handles them inside the cluster. A bare `localhost` URL with the ingress on fails the install.

### External MySQL and Redis

With `mysql.enabled: false`, set `mysql.host` and `mysql.port`. The user `mysql.username` needs all privileges on both `mysql.appDatabase` and `mysql.omopDatabase`, which must already exist. For the full vocabulary import, the server needs `local_infile=1`.

With `redis.enabled: false`, set `redis.host` and `redis.port`, and `redis.auth: true` if it needs a password.

### Identity provider

The bundled Keycloak is for trials. For real users, use your organisation's identity provider: set `keycloak.enabled: false`, `sso.issuer` (the OIDC issuer URL) and `sso.clientId`, then in the provider:

- register `<api.appUrl>/api/auth/sso/default/callback` as the redirect URI, and `<web.appUrl>/login` as the post-logout redirect;
- send `groups` and `roles` claims in the ID token, and match them in [the claims mapping](../customising/identity-and-access.md#map-keycloak-names-to-the-app);
- create `bootstrap.adminEmail` as a user, with a verified email.

The service docs explain the [sign-in flow and what the provider must support](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/identity-provider/); only some providers work today.

The provision Job signs in through Keycloak's login form, so with any other provider set `provision.enabled: false` and [create collections in the app](connect-a-collection.md).

### Storage

The API saves files BUNNYs upload, and the queue worker reads them back, through a shared volume (`api.storageSize`, `api.storageClassName`, `api.storageAccessMode`). The default, `ReadWriteOnce`, only works while both pods are on the same node. On a cluster with more nodes, set `api.storageAccessMode: ReadWriteMany` and a storage class that supports it, such as NFS, EFS or Filestore.

The bundled MySQL, Keycloak and synthetic Postgres have their own volumes (`*.storageSize`, `*.storageClassName`). A full OMOP vocabulary needs more than the default 10Gi for MySQL.

### Resources

Every container has CPU and memory requests and a memory limit (`*.resources`), and no CPU limit. See [Chart values](../reference/values.md).

## 5. Install

```bash
scripts/customisations-values.sh
helm install cohort-discovery charts/cohort-discovery \
  --namespace cohort-discovery --create-namespace \
  -f my-values.yaml -f generated/customisations.values.yaml \
  -f generated/secrets.values.yaml \
  --timeout 15m
```

Leave out `-f generated/secrets.values.yaml` if you created your own Secret. `scripts/customisations-values.sh` turns the files in `customisations/` into chart values; see [Customise](../customising/index.md).

`helm install` waits for the setup Jobs: `api-init`, then `provision` and, if you set `vocab.athena.hostPath`, `vocab-import`. The other pods wait for what they need. Then:

```bash
kubectl -n cohort-discovery get pods
curl -s https://api.cds.example.org/up
```

and sign in at your web URL as `bootstrap.adminEmail`. `helm install` prints how.

## 6. Connect collections

Register each custodian's collection host and run its BUNNYs: see [Connect a collection](connect-a-collection.md).

## Upgrade

1. Pull this repo and run `git submodule update --init` to move `services/` to the new releases.
2. Rebuild and push the images with new tags, and set them in `my-values.yaml`.
3. Compare `customisations/api/` and `customisations/nlp/` with the services' own copies at the new release. They replace the services' files, so new settings upstream won't appear until you add them.
4. Run `scripts/customisations-values.sh`, then the install command with `helm upgrade` in place of `helm install`.

The setup Jobs run again and are safe to repeat: `api-init` runs only pending migrations, `provision` only adds what's missing, and `vocab-import` does nothing unless the vocabulary release changed. Pods whose configuration changed restart by themselves.

## Back up

Everything worth keeping is in MySQL: the app database (`cohort_discovery`) and the vocabulary (`omop`), which you can import again instead. With an external MySQL, use your usual backups. With the bundled one:

```bash
kubectl -n cohort-discovery exec cohort-discovery-mysql-0 -- sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction cohort_discovery' > cohort_discovery.sql
```

Keep the Secret too. The dump holds personal data (researchers' emails and activity), so store and delete it accordingly.

## Uninstall

!!! danger
    `helm uninstall` deletes the bundled MySQL, Keycloak and synthetic data volumes with everything else. Back up first.

```bash
helm uninstall cohort-discovery -n cohort-discovery
kubectl delete namespace cohort-discovery
```

Deleting the namespace also removes what `helm uninstall` leaves: the setup Jobs and the `bunny-<host>` Secrets.

## Try the chart on a local cluster

To run the chart without Tilt on your laptop, build the images under the tags in `charts/cohort-discovery/values.yaml` instead of pushing them. Rancher Desktop, Docker Desktop and OrbStack see them straight away; otherwise load them in (`kind load docker-image <image> --name cohort-discovery`, `k3d image import <image> --cluster cohort-discovery` or `minikube image load <image>`). Install as in step 5 with the generated secrets, then forward the ports, each in its own terminal:

```bash
kubectl -n cohort-discovery port-forward svc/cohort-discovery-web 3000:3000
kubectl -n cohort-discovery port-forward svc/cohort-discovery-api 8100:8100
kubectl -n cohort-discovery port-forward svc/cohort-discovery-keycloak 8180:8180
```

Keycloak's forward must use the same port on both sides (`keycloak.port`), because the browser and the API must reach it at the same URL.

## Known limitations

| Limitation | What to do |
|---|---|
| Images aren't published, and the API build needs access to HDR UK's private composer packages | Build them yourself (step 2) |
| The chart has no `imagePullSecrets`, so it can't pull from a registry that needs credentials | Use a registry your nodes can pull from without them, or give the nodes' service account access |
| The bundled Keycloak runs in development mode | Use it for trials only; use your own identity provider for real users |
| The full vocabulary import reads from a folder on the node (`hostPath`), which many managed clusters don't allow | Import on a cluster that allows it, or load the vocabulary into MySQL yourself |
| Every part runs as one replica | Expect short outages during upgrades |
| `helm uninstall` deletes the data volumes | Back up first; keep data in an external MySQL |

Fixing the chart's limitations is on the [tracker](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/README.md). For limitations of the service itself, such as which identity providers work, see the service docs' [known limitations](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/limitations/).
