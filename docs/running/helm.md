# Running with Helm

The chart in `charts/cohort-discovery/` is the whole definition of the stack. Tilt only builds images, runs two scripts and forwards ports, so you can do the same by hand.

## 1. Build the images

Build them under the repositories and tags in `charts/cohort-discovery/values.yaml` (`images.api`, `images.nlp`, `images.web`), so the chart finds them without overrides:

```bash
export GITHUB_TOKEN=$(gh auth token)
tag() { yq ".images.$1.tag" charts/cohort-discovery/values.yaml; }

docker build --secret id=github_token,env=GITHUB_TOKEN \
  -t ghcr.io/hdruk/cohort-discovery-api:$(tag api) services/api
docker build -t ghcr.io/hdruk/cohort-discovery-nlp:$(tag nlp) services/nlp
scripts/build-web.sh ghcr.io/hdruk/cohort-discovery-web:$(tag web) \
  --build-arg APPLICATION_MODE=standalone \
  --build-arg API_BASE_URL=http://localhost:8100 \
  --build-arg NEXT_PUBLIC_TASK_URL=http://localhost:8100/api/v1 \
  --build-arg NEXT_PUBLIC_USE_EXAMPLE_QUERY=false \
  --build-arg NEXT_PUBLIC_USE_DEBUG_LOGS=false
```

Without `yq`, read the three tags from `values.yaml` and type them in.

The web is built through `scripts/build-web.sh` so that it carries the branding in `customisations/web/branding/` (see [Branding](../customising/branding.md)). Its build arguments are fixed into the image:

| Build argument | What |
|---|---|
| `APPLICATION_MODE` | Always `standalone` for this stack |
| `API_BASE_URL` | The API URL as the browser sees it. Must match `api.appUrl` |
| `NEXT_PUBLIC_TASK_URL` | The task URL shown to custodians for their BUNNY: `api.appUrl` plus `/api/v1` |
| `NEXT_PUBLIC_USE_EXAMPLE_QUERY` | `true` starts the query builder with an example query |
| `NEXT_PUBLIC_USE_DEBUG_LOGS` | `true` turns on the web's debug logging in the browser |

Rancher Desktop (with the Docker runtime), Docker Desktop and OrbStack share Docker's image store, so the cluster sees the images straight away. Otherwise load them in:

| Cluster | Command, for each image |
|---|---|
| kind | `kind load docker-image <image> --name cohort-discovery` |
| k3d | `k3d image import <image> --cluster cohort-discovery` |
| minikube | `minikube image load <image>` |

## 2. Generate the values files

```bash
scripts/local-secrets.sh            # generated/secrets.values.yaml, once
scripts/customisations-values.sh    # generated/customisations.values.yaml, after every change to customisations/
```

Helm can only read files inside the chart, so the second script copies the files in `customisations/` into a values file. To keep your customisations in another folder, pass it: `scripts/customisations-values.sh <folder>`.

## 3. Install

```bash
helm install cohort-discovery charts/cohort-discovery \
  --namespace cohort-discovery --create-namespace \
  -f generated/secrets.values.yaml -f generated/customisations.values.yaml \
  --timeout 15m
```

`helm install` waits for the setup Jobs (`api-init`, then `provision`), which run as post-install hooks. The other pods wait in init containers until the Jobs they need have finished.

## 4. Forward the ports

Each command holds its terminal, so run each in its own, or add `&`:

```bash
kubectl -n cohort-discovery port-forward svc/cohort-discovery-web 3000:3000
kubectl -n cohort-discovery port-forward svc/cohort-discovery-api 8100:8100
kubectl -n cohort-discovery port-forward svc/cohort-discovery-keycloak 8180:8180
kubectl -n cohort-discovery port-forward svc/cohort-discovery-nlp 5001:5001   # optional; only the API calls it
```

Then sign in as in [Getting started](../getting-started.md#sign-in).

If you forward the web or API to other host ports, set `web.appUrl` and `api.appUrl` to match and rebuild the web with the new API URL. Keycloak's forward must use the same port on both sides, set as `keycloak.port`, because the browser and the API must reach it at the same URL.

## Upgrade and uninstall

After changing values or `customisations/`, run `scripts/customisations-values.sh` again, then the same command with `helm upgrade` in place of `helm install`. Pods whose configuration changed restart by themselves, and the setup Jobs run again. See [Maintaining](../operations/maintaining.md) for what each change needs.

`helm uninstall cohort-discovery -n cohort-discovery` deletes the MySQL, Keycloak and synthetic data volumes with everything else, but leaves the setup Jobs (`cohort-discovery-api-init`, `-provision`, `-vocab-import`) and the `bunny-<host>` Secrets. Delete those by hand, or the namespace, before installing again. Under Tilt, `tilt down` keeps the volumes.
