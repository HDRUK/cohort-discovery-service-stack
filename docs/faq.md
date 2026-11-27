# FAQ

## Where are the logs?

Under Tilt, click a resource in the Tilt UI (http://localhost:10350). With kubectl:

| Part | Command |
|---|---|
| API | `kubectl -n cohort-discovery logs deploy/cohort-discovery-api -c api` |
| Queue worker | `kubectl -n cohort-discovery logs deploy/cohort-discovery-queue -c horizon` |
| NLP | `kubectl -n cohort-discovery logs deploy/cohort-discovery-nlp -c nlp` |
| Web | `kubectl -n cohort-discovery logs deploy/cohort-discovery-web -c web` |
| Keycloak | `kubectl -n cohort-discovery logs deploy/cohort-discovery-keycloak -c keycloak` |
| A synthetic collection's BUNNYs | `kubectl -n cohort-discovery logs deploy/cohort-discovery-bunny-<collection> --all-containers` |
| Setup Jobs | `kubectl -n cohort-discovery logs job/cohort-discovery-<api-init, provision or vocab-import>` |

`kubectl -n cohort-discovery describe pod <pod>` says why a pod is waiting or restarting. `api.logLevel` and `nlp.logLevel` set how much the API and NLP log.

## On your laptop

### Tilt says `GITHUB_TOKEN is not set`

The API image build needs a GitHub token. The `Tiltfile` checks for it every time it loads, so `tilt down` needs it too. Run `export GITHUB_TOKEN=$(gh auth token)` in the same shell.

### Tilt says `Refusing to run against context "…"`

Tilt only runs against a local cluster, so it can't deploy to a shared one by mistake. Switch with `kubectl config use-context rancher-desktop` (or `docker-desktop`, `orbstack`, `minikube`, `kind-cohort-discovery`, `k3d-cohort-discovery`). A kind or k3d cluster must be named `cohort-discovery`.

### A port is already in use

Something else is on 3000, 8100, 5001 or 8180. Stop it, or move the stack to other ports in `tilt_config.json`, as in [Host ports](getting-started.md#host-ports).

### Pods are `OOMKilled` or evicted

Give your cluster more memory: about 8 GB. The vocabulary import alone can use 4 GB.

### I deleted `generated/secrets.values.yaml` and now nothing can connect

MySQL, Keycloak and the synthetic Postgres keep the passwords they were first given. Delete their volumes too; see [Stop, restart and reset](getting-started.md#stop-restart-and-reset).

## On a cluster

### The install fails with a message

The chart checks its values and stops with a message naming the problem:

| Message mentions | Fix |
|---|---|
| `secrets.… is not set` | Pass `-f generated/secrets.values.yaml`, or create a Secret and set `secrets.existingSecret`. See [Deploy to a cluster](deploying/index.md#4-create-the-secrets) |
| `the passwordKey of a keycloak.users entry, is not set` | Add that key under `secrets:`. See [Add a user](customising/identity-and-access.md#add-a-user) |
| `is in group …, which is not in keycloak.groups`, or `has realm role …` | Add the group or role to `keycloak.groups` or `keycloak.roles` |
| `ingress.enabled needs a hostname other than localhost` | Set `web.appUrl`, `api.appUrl` and `keycloak.url` to real hosts, or `*.localhost` names on a laptop |
| `syntheticSize` | Use 100, 1000 or 1001 in `provision.json` |

### Pods are stuck in `ImagePullBackOff`

The cluster can't pull the images. Check the repositories and tags in your values, and, if the registry needs credentials, that `imagePullSecrets` names a pull secret in the namespace. See [Third-party images](deploying/services.md#third-party-images).

### Pods wait in `wait-for-api-init`

The API, queue and NLP wait until `api-init` has finished. Check its log (above). It usually waits on MySQL, which can take a minute the first time.

## Signing in

### "Single Sign-On" fails or loops

The browser and the API must reach the identity provider at the same URL. Under Tilt, change ports only through the [Tilt settings](getting-started.md#host-ports), so everything moves together. Changes to Keycloak's ports, users or passwords need a [realm re-import](customising/identity-and-access.md#re-import-the-realm). The service docs list what each [sign-in error](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/reference/login-errors/) means.

### Sign-in works locally but not on the cluster

Serve it over HTTPS. The web's sign-in cookie is `Secure`, and browsers drop it over plain HTTP anywhere but `localhost`.

### `Token signature mismatch`, or I get signed out of another app

Another copy of the web app on the same host is sharing the sign-in cookie. Sign out of both, or use a private window. The stack's cookie is named `cds_stack_token` (`web.cookieTokenName`) to avoid this.

### A user signs in but has the wrong access

Access is replaced from the identity provider on every sign-in. Check the user's groups and roles there, the mappings in `claimsaccesscontrol.php`, and that the workgroup exists. See [Identity and access](customising/identity-and-access.md).

## Collections and queries

### A researcher sees no collections

The collection must be shared with one of their workgroups (`workgroups` in `provision.json`, or in the app) and be active. Check the provision Job's log.

### The provision Job fails with "host … exists but Secret … doesn't"

The API shows a host's credentials only once, and the Secret that held them is gone. Delete the host in the app so the Job can create it again, or restore the Secret.

### Queries never finish

No type A BUNNY is answering for that collection. Check its logs. The synthetic BUNNYs start only after the provision Job has written their host's Secret. For a real collection, see [Connect a collection](deploying/connect-a-collection.md#3-check-its-working).

### A collection was suspended

Its type A BUNNY stopped polling for 30 minutes or, with the API's backlog feature flag on, too many of its tasks were pending. It becomes active again by itself on the type A BUNNY's next poll, once the backlog has drained. See [If a collection is suspended](deploying/connect-a-collection.md#if-a-collection-is-suspended).

### Counts are 0 or round numbers

That's on purpose. BUNNY reports counts below 10 as 0 and rounds the rest to the nearest 10, so no small group can be singled out. For synthetic collections these are `synthetic.bunny.*`; for real ones, the custodian sets them.

### The term directory and "Last Distribution" are empty

Distributions come from type B BUNNYs, when a collection's distribution schedule is due (weekly for concept counts, monthly for demographics). The provision Job adds the schedules and runs them once straight away, so its collections fill in within a minute or so. A collection created in the app needs its schedules set there. Check the type B BUNNY's logs and the `cohort-discovery-distributions-collector` CronJob.

### A concept can't be found

The minimal vocabulary has only about 3,900 concepts. Import the [full vocabulary](customising/vocabulary.md).
