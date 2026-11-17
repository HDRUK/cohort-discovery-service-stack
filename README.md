# cohort-discovery-service-stack

Runs the Cohort Discovery Service (web, API and NLP) in standalone mode on Kubernetes, with a Helm chart driven locally by Tilt, a throwaway Keycloak for single sign-on, an OMOP vocabulary and, later, synthetic BUNNY collections.

## Quick start

You need a local Kubernetes cluster (Rancher Desktop, Docker Desktop, OrbStack, minikube, kind or k3d), `kubectl`, `helm` 3, `tilt` and `openssl`. Until A1 lands, building the API image also needs access to HDR UK's private composer packages through a GitHub token.

```bash
git clone --recurse-submodules https://github.com/HDRUK/cohort-discovery-service-stack.git
cd cohort-discovery-service-stack
export GITHUB_TOKEN=$(gh auth token)
tilt up
```

Then open http://localhost:3000 and sign in through "Single Sign-On" as one of the fictional Keycloak users: `admin@example.com`, `researcher@example.com` or `custodian@example.com`. Email and password sign-in is turned off. The passwords are generated into `generated/secrets.values.yaml` and the cluster Secret:

```bash
kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.keycloak-user-researcher-password}' | base64 -d; echo
```

To run without Tilt, other host ports, stopping and restarting, and how sign-in and access work, see [Getting started](docs/getting-started.md).

## Customising

Everything you're expected to change is in `customisations/`, one folder per service:

| Path | What |
|---|---|
| `customisations/api/auth.php` | Authentication settings. Password sign-in is off, so everyone signs in through Keycloak |
| `customisations/api/claimsaccesscontrol.php` | How Keycloak groups and roles map to the app's workgroups and roles |
| `customisations/api/workgroups.php` | The workgroups the app has |
| `customisations/keycloak/realm.json` | The Keycloak realm's client and settings. Its users, groups and roles are set in the chart values (`keycloak.users`, `keycloak.groups`, `keycloak.roles`) |
| `customisations/keycloak/theme/` | The Keycloak sign-in page's look. It uses the web's logo and favicon from `customisations/web/branding/assets/` |
| `customisations/nlp/` | The NLP's rules and concept mappings |
| `customisations/web/branding/` | The web's name, theme, logo, favicon and legal pages, built into the web image. The web doesn't use the favicon yet (W3) |

Tilt picks up changes as you save. With Helm alone, run `scripts/customisations-values.sh` and pass `-f generated/customisations.values.yaml` alongside the secrets file. Chart settings such as ports, URLs, images and Keycloak users are in [`charts/cohort-discovery/values.yaml`](charts/cohort-discovery/values.yaml). See [Customisations](docs/getting-started.md#customisations) and [Configuration](docs/getting-started.md#configuration).

## Layout

| Path | What |
|---|---|
| `services/` | The web, API and NLP, as git submodules pinned to release tags (the API is temporarily on an unreleased commit) |
| `charts/cohort-discovery/` | The Helm chart: the one definition of the stack |
| `customisations/` | What a deployer changes (above) |
| `scripts/` | Secrets generation, the customisations values file, and the branded web build |
| `Tiltfile` | Local development |
| `generated/` | Git-ignored: local secrets and the customisations values file |
| `docs/` | Getting started, the plan and decisions, and the [ticket tracker](docs/README.md) |

## Status

Work in progress. The core services, Keycloak and branding run today. A full OMOP vocabulary import, provisioning of custodians and collections, synthetic collections, non-local installs and CI are still to come. The [tracker](docs/README.md) has the detail.

## Personal data

The stack stores researcher emails, identity-provider claims and activity logs. See the [personal data inventory](docs/data-protection/personal-data-inventory.md) before running it with real users.
