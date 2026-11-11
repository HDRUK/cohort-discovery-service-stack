# Getting started

Later tickets fill this in. Today the repo has the scaffold only: nothing runs yet.

## You need

- A local Kubernetes cluster: Rancher Desktop (with the Docker runtime), Docker Desktop, OrbStack, minikube, or kind/k3d with a cluster named `cohort-discovery`.
- `kubectl`, `helm` 3 and `tilt`.
- Access to HDR UK's private `hdruk/*` composer packages, to build the API image (until A1).

## Clone

```bash
git clone --recurse-submodules https://github.com/HDRUK/cohort-discovery-service-stack.git
cd cohort-discovery-service-stack
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`.

`services/web`, `services/api` and `services/nlp` are pinned to release tags. `git submodule status` shows which.

## Run

```bash
tilt up
```

The Tiltfile refuses to run against any context that isn't a known local cluster.

To install without Tilt, use `helm install cohort-discovery charts/cohort-discovery`.

## Layout

| Path | What |
|---|---|
| `services/` | web, API and NLP submodules |
| `charts/cohort-discovery/` | the Helm chart: the one definition of the stack |
| `config/nlp/` | NLP `rules.json` and `mappings.json`, copied from the NLP defaults |
| `config/keycloak/` | Keycloak realm (S2) |
| `config/branding/` | branding overlay (W3) |
| `config/synthetic/` | somop configs (S5) |
| `scripts/` | secrets, build and provisioning scripts |
| `Tiltfile` | local development |

`config/claims-mapping.json` arrives with A3 and `config/provision.json` with S4.
