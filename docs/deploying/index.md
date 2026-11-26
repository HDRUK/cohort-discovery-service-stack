# Install with Helm

This section installs the stack on a shared Kubernetes cluster with the Helm chart in `charts/cohort-discovery/`. This page is the walkthrough; the pages after it explain each part: how its image is built, how to use your own, and what to configure. To run the stack on your own machine first, see [Run locally](../getting-started.md).

!!! warning "Before real people sign in"
    The service stores researchers' email addresses, identity-provider claims and activity logs. Read the [personal data inventory](../data-protection/personal-data-inventory.md) and the [known limitations](#known-limitations) below, and replace the placeholder legal pages (see [Branding](../customising/branding.md)). For how custodians' data is protected, see the service docs on [data governance](https://hdruk.github.io/cohort-discovery-service-docs/architecture/governance/).

## What you deploy

| Part | Image | Configured by | Page |
|---|---|---|---|
| API, queue worker, `api-init` Job | Built from `services/api` | `api.*`, `customisations/api/` | [The API](api.md) |
| Web app | Built from `services/web` with your branding | Build arguments, `web.*`, `customisations/web/branding/` | [The web app](web.md) |
| NLP query parser | Built from `services/nlp` | `nlp.*`, `customisations/nlp/` | [The NLP](nlp.md) |
| MySQL: the app database and the OMOP vocabulary | `mysql`, or your own server | `mysql.*`, `vocab.*` | [Database and vocabulary](database.md) |
| Sign-in: the bundled Keycloak, your own OIDC provider, or passwords | `keycloak`, or none | `keycloak.*`, `sso.*`, `customisations/api/auth.php` | [Sign-in](sign-in.md) |
| Redis, the scheduled jobs, the setup Jobs, ingress | Third-party images | `redis.*`, `scheduler.*`, `provision.*`, `ingress.*` | [Supporting services](services.md) |
| Collections' BUNNYs | Run by each custodian | The app, or `customisations/provision.json` | [Connect a collection](connect-a-collection.md) |

## 1. Choose a starting point

Two example values files in `charts/cohort-discovery/` show the ends of the range:

| File | What | Good for |
|---|---|---|
| `values.evaluation.yaml` | Everything bundled (MySQL, Redis, Keycloak, synthetic collections), behind an ingress with TLS | A shared trial with fictional users. Not for real users: the bundled Keycloak runs in development mode |
| `values.production-like.yaml` | External MySQL, Redis and identity provider, secrets and a registry pull secret you create, the full vocabulary from a volume, no synthetic collections or provisioning | A real service |

Copy one to `my-values.yaml` and choose your hostnames now, because the other pages use them. The examples use three: `cds.example.org` (web), `api.cds.example.org` (API) and `auth.cds.example.org` (Keycloak). Set them as described in [URLs and ingress](services.md#urls-and-ingress).

## 2. Build and push the images

The stack doesn't publish images. Build the API, web and NLP images as their pages describe, push them to a registry your cluster can pull from, and set `images.api`, `images.web` and `images.nlp` in `my-values.yaml`:

```yaml
images:
  api: { repository: registry.example.org/cohort-discovery/api, tag: "1" }
  nlp: { repository: registry.example.org/cohort-discovery/nlp, tag: "1" }
  web: { repository: registry.example.org/cohort-discovery/web, tag: "1" }
```

If the registry needs credentials, name a pull secret in `imagePullSecrets`; see [Third-party images](services.md#third-party-images).

## 3. Decide each part's settings

Work through the pages for the parts you're changing: [sign-in](sign-in.md) and the [database](database.md) above all, because they decide which secrets you need.

## 4. Create the secrets

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

    The chart doesn't check your Secret's keys. If one is missing, pods wait in `CreateContainerConfigError` and `helm install` times out waiting for `api-init`; `kubectl -n cohort-discovery describe pod` names the key.

| Key | Needed when | Used by |
|---|---|---|
| `app-key`, `jwt-secret`, `passport-private-key`, `passport-public-key` | Always | The API. The Passport keys sign sign-in tokens |
| `collection-hosts-key-salt-1`, `collection-hosts-key-salt-2` | Always | The API: BUNNY credentials |
| `admin-password` | Always | The first admin's password sign-in |
| `scheduler-client-id`, `scheduler-client-secret` | Always | The [scheduled jobs](services.md#scheduled-jobs) |
| `mysql-password` | Always | MySQL, the API, queue worker, `api-init`, `vocab-import` and NLP |
| `mysql-root-password` | Bundled MySQL | MySQL |
| `redis-password` | `redis.auth: true` | The API and queue worker |
| `keycloak-admin-password`, `keycloak-client-secret`, and `keycloak-user-<passwordKey in kebab case>` for each `keycloak.users` entry | Bundled Keycloak | Keycloak and the API |
| `sso-client-secret` | Your own identity provider | The API |
| `synthetic-db-password` | Synthetic collections | The synthetic Postgres and BUNNYs |

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

`helm install` waits for the [setup Jobs](services.md#setup-jobs). Then:

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

The setup Jobs run again and are safe to repeat. Pods restart by themselves when their configuration changes, but not when the Secret does: after changing a secret, run `kubectl -n cohort-discovery rollout restart deployment`.

## Back up

Back up MySQL, the bundled Keycloak's volume if you use it, the `bunny-<host>` Secrets and your own Secret; see [Back up](database.md#back-up).

## Uninstall

```bash
helm uninstall cohort-discovery -n cohort-discovery
```

This keeps the bundled MySQL, Keycloak and synthetic data volumes, so installing again under the same release name picks up the same data. It also leaves the setup Jobs and the `bunny-<host>` Secrets.

!!! danger
    To remove everything, delete the release's volumes too. This deletes the data, so back up first.

```bash
kubectl -n cohort-discovery delete pvc -l app.kubernetes.io/instance=cohort-discovery
kubectl delete namespace cohort-discovery
```

The first command deletes only the chart's volumes, not a volume you made for the Athena files. Deleting the namespace removes everything else in it.

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
| The API image keeps the GitHub token used to build it, and the API and NLP images take in any local `.env` file | Use a read-only token, build from clean checkouts, and push only to a private registry |
| The bundled Keycloak runs in development mode, and `helm install` warns when it's served beyond `localhost` | Use it for trials only; use your own identity provider for real users |
| Every part runs as one replica | Expect short outages during upgrades |

Fixing the chart's limitations is on the [tracker](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/README.md). For limitations of the service itself, such as which identity providers work, see the service docs' [known limitations](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/limitations/).
