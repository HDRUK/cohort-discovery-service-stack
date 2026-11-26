# Run locally

This page runs the whole stack on your laptop with Tilt: the services, a throwaway Keycloak with three fictional users, the minimal OMOP vocabulary, and two synthetic collections that answer queries straight away. To run it on a shared cluster, see [Deploy to a cluster](deploying/index.md).

No local Kubernetes cluster? [Docker Compose](alternatives/docker-compose.md) describes a community alternative.

## You need

- **A local Kubernetes cluster** with about 4 CPUs and 8 GB of memory: Rancher Desktop (with the Docker runtime), Docker Desktop, OrbStack, minikube, or kind or k3d with a cluster named `cohort-discovery`. Tilt refuses any other context, so it can't touch a shared cluster by mistake.
- **`kubectl`, `helm` 3, `tilt` and `openssl`.**
- **A GitHub token.** The API image build needs one to install its `hdruk/*` composer packages. The GitHub CLI can supply it.
- **Ports 3000, 8100, 5001 and 8180 free**, or other ports chosen as in [Host ports](#host-ports). Stop local development servers of the web, API or NLP first, and anything that polls them, such as BUNNY containers from `somop run`.

## Clone

```bash
git clone --recurse-submodules https://github.com/HDRUK/cohort-discovery-service-stack.git
cd cohort-discovery-service-stack
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`. `git submodule status` shows which release of each service is pinned.

## Start it

```bash
export GITHUB_TOKEN=$(gh auth token)
tilt up
```

Press space to open the Tilt UI at http://localhost:10350. On start, Tilt:

1. refuses any context that isn't a known local cluster;
2. writes random credentials to `generated/secrets.values.yaml` the first time (git-ignored, mode 0600). Later runs only add keys the file is missing, and never change or print existing ones;
3. turns `customisations/` into chart values in `generated/customisations.values.yaml`;
4. builds the API, NLP and web images from `services/`, the web with the branding in `customisations/web/branding/`;
5. installs the chart into the `cohort-discovery` namespace.

The first build takes a while: the API and web images each take several minutes. The token reaches the API build only as a BuildKit secret, never on disk or in an image layer.

When every resource is green:

| URL | What |
|---|---|
| http://localhost:3000 | The web app |
| http://localhost:8100 | The API (`/up` is its health check) |
| http://localhost:5001/health/ready | NLP readiness |
| http://localhost:8180 | Keycloak (admin console at `/admin`) |
| http://localhost:10350 | The Tilt UI, with each resource's logs |

Tilt picks up changes as you save: to `customisations/`, to the chart and to the service source.

## Sign in

Open http://localhost:3000 and choose **Single Sign-On**. Email and password sign-in is turned off, so everyone signs in through Keycloak. The stack has three fictional users:

| User | Is | Sees |
|---|---|---|
| `admin@example.com` | An admin, and a member of "Demo Custodian" | Everything |
| `researcher@example.com` (Jane Doe) | A researcher in the `UK-RESEARCH` workgroup | Both synthetic collections |
| `custodian@example.com` (John Smith) | A custodian user of "Demo Custodian" | That custodian's hosts and collections |

### Credentials

Every password is generated for your install. They're in `generated/secrets.values.yaml` and in the cluster Secret `cohort-discovery-secrets`. To print one:

```bash
kubectl -n cohort-discovery get secret cohort-discovery-secrets -o jsonpath='{.data.<key>}' | base64 -d; echo
```

| For | `<key>` |
|---|---|
| `admin@example.com` | `admin-password` |
| `researcher@example.com` | `keycloak-user-researcher-password` |
| `custodian@example.com` | `keycloak-user-custodian-password` |
| The Keycloak admin console (user `admin`) | `keycloak-admin-password` |
| MySQL `root` | `mysql-root-password` |

The BUNNYs' API credentials are in the Secret `bunny-<host>`, written by the provision Job (see [Collections](customising/collections.md)).

## Run a first query

1. Sign in as `researcher@example.com`.
2. Build a query, for example people with a condition, or type one in plain words and let the NLP turn it into a query.
3. Run it. "Synthetic Collection A" and "Synthetic Collection B" each answer within a few seconds.

Counts are rounded to the nearest 10, and counts below 10 are reported as 0, as a real collection would do. The synthetic data describes no real people. Collection A has 1,000 synthetic people and Collection B has 100.

If no collections appear, or queries never finish, see the [FAQ](faq.md).

## Host ports

To run beside a development stack that already uses 3000, 8100 and 5001, choose other host ports in a `tilt_config.json` beside the `Tiltfile`. Git ignores the file, so your ports stay on your machine. Leave out any you don't want to change:

```json title="tilt_config.json"
{
  "web-port": "13000",
  "api-port": "18100",
  "nlp-port": "15001",
  "keycloak-port": "18180"
}
```

Ports are strings, in quotes. Tilt reloads when you save the file, so this works while the stack is running too. For a one-off, pass them as flags instead, which win over the file:

```bash
tilt up -- --api-port=18100
tilt args -- --api-port=18100    # while Tilt is already running
```

Use the same ports in the URLs above. Changing the API port also rebuilds the web image, because the task URL the web shows custodians is built in. Changing the Keycloak port on a kept volume needs a [realm re-import](customising/identity-and-access.md#re-import-the-realm).

The older `CDS_WEB_PORT`, `CDS_API_PORT`, `CDS_NLP_PORT`, `CDS_KEYCLOAK_PORT` and `CDS_KEYCLOAK_ENABLED` environment variables still work, but a flag or `tilt_config.json` wins over them.

Browsers share cookies across ports on the same host, so the stack's web app names its sign-in cookie `cds_stack_token` rather than the default `token`. A development web app on `localhost` and the stack can then both be signed in at once.

## Working on the services

The web, API and NLP source is in `services/`, pinned to releases. Make changes in each service's own repo, then move the pin here. Tilt rebuilds an image whenever its source changes: for the web that's a full production build, which takes several minutes, so it's for checking changes in the real image rather than for day-to-day development. To develop a service, follow the service docs' developer guide for the [web](https://hdruk.github.io/cohort-discovery-service-docs/developers/web/), [API](https://hdruk.github.io/cohort-discovery-service-docs/developers/api/) or [NLP](https://hdruk.github.io/cohort-discovery-service-docs/developers/nlp/).

## Without Keycloak

Add `"keycloak": false` to `tilt_config.json`, or for a one-off:

```bash
tilt up -- --keycloak=false
```

Single sign-on is then off, the API offers email and password sign-in again (as `admin@example.com` with the admin password), and the provision Job and synthetic collections are off too, because the Job signs in through Keycloak.

## Stop, restart and reset

`tilt down` removes everything except the namespace, three volumes, MySQL (`cohort-discovery-mysql-data`), Keycloak (`cohort-discovery-keycloak-data`) and the synthetic data (`cohort-discovery-synthetic-db-data`), and the BUNNY Secrets `bunny-<host>` the provision Job wrote. The next `tilt up` finds the same data, and the setup Jobs run again without changing anything. The volume for uploaded distribution files is deleted; the BUNNYs upload them again on their next schedule.

To start from scratch, delete the volumes and the generated secrets together:

```bash
tilt down
kubectl -n cohort-discovery delete pvc cohort-discovery-mysql-data cohort-discovery-keycloak-data cohort-discovery-synthetic-db-data
rm generated/secrets.values.yaml
tilt up
```

Delete the secrets file and the volumes together, or neither. MySQL, Keycloak and the synthetic Postgres keep the passwords they were first given, so new credentials won't match old data.

To remove the stack completely, run the reset above without `tilt up`, then `kubectl delete namespace cohort-discovery`.

## Next

- [Customise](customising/index.md) the users, branding, collections, vocabulary and NLP rules.
- [Deploy to a cluster](deploying/index.md) when you're ready to run it for real.
- Import the [full OMOP vocabulary](customising/vocabulary.md), so queries can use every concept.
- Read the [Overview](overview.md) for how the parts fit together.
