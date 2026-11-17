# Troubleshooting

Start with the logs. Under Tilt, click the resource in the Tilt UI (http://localhost:10350). Otherwise:

```bash
kubectl -n cohort-discovery get pods
kubectl -n cohort-discovery logs deploy/cohort-discovery-api -c api
kubectl -n cohort-discovery describe pod <pod>     # why a pod is waiting or restarting
```

## Tilt won't start

**`GITHUB_TOKEN is not set`.** The API image needs a token that can read HDR UK's private `hdruk/*` composer packages. Run `export GITHUB_TOKEN=$(gh auth token)` in the same shell. If the build then fails installing `hdruk/*` packages, the token can't read them.

**`Refusing to run against context "…"`.** Tilt only runs against a local cluster, so it can't deploy to a shared one by mistake. Switch with `kubectl config use-context rancher-desktop` (or `docker-desktop`, `orbstack`, `minikube`, `kind-cohort-discovery`, `k3d-cohort-discovery`). A kind or k3d cluster must be named `cohort-discovery`.

**A port is already in use.** Something else is on 3000, 8100, 5001 or 8180. Stop it, or move the stack with the `CDS_*_PORT` variables in [Getting started](../getting-started.md#host-ports).

## The install fails with a message

The chart checks its values and stops with a message naming the problem. The common ones:

| Message mentions | Fix |
|---|---|
| `the passwordKey of a keycloak.users entry, is not set` | Add that key to `generated/secrets.values.yaml` under `secrets:`. See [Add a user](../customising/identity-and-access.md#add-a-user) |
| `is in group …, which is not in keycloak.groups`, or `has realm role …` | Add the group or role to `keycloak.groups` or `keycloak.roles` |
| `ingress.enabled needs a hostname other than localhost` | Set `web.appUrl`, `api.appUrl` and `keycloak.url` to real hosts, or `*.localhost` names on a laptop |
| `syntheticSize` | Use 100, 1000 or 1001 in `provision.json` |
| `secrets.… is not set` | Pass `-f generated/secrets.values.yaml`, or run `scripts/local-secrets.sh` |

## Pods are stuck

**Waiting in `wait-for-api-init`.** The API, queue and NLP wait until `api-init` has finished. Check its log: `kubectl -n cohort-discovery logs job/cohort-discovery-api-init`. It usually waits on MySQL, which can take a minute the first time.

**`OOMKilled` or pods evicted.** Give your cluster more memory; about 8 GB is needed. The vocabulary import alone can use 4 GB.

**`ImagePullBackOff` with Helm.** The cluster can't see the images you built. Load them in (see [Running with Helm](../running/helm.md#1-build-the-images)), and check the tags match `values.yaml`.

## Signing in

**"Single Sign-On" fails or loops.** The browser and the API must reach Keycloak at the same URL. If you changed ports, use the `CDS_*` variables rather than editing values, so everything moves together. Changes to ports, users or passwords need a [realm re-import](../customising/identity-and-access.md#re-import-the-realm).

**`Token signature mismatch`, or being signed out of another app.** Another copy of the web app on `localhost` is sharing the sign-in cookie. Sign out of both, or use a private window. The stack's cookie is `cds_stack_token` (`web.cookieTokenName`) to avoid this.

**Signed in, but the wrong access.** Access is replaced from Keycloak on every sign-in. Check the user's groups and roles in the Keycloak console, the mappings in `claimsaccesscontrol.php` and that the workgroup exists. See [Identity and access](../customising/identity-and-access.md).

**Sign-in fails on a shared cluster.** Serve it over HTTPS: the web's sign-in cookie is `Secure`, and browsers drop it over plain HTTP anywhere but `localhost`.

## Collections and queries

**A researcher sees no collections.** The collection must be shared with one of their workgroups (`workgroups` in `provision.json`) and active. Check the provision Job's log: `kubectl -n cohort-discovery logs job/cohort-discovery-provision`.

**The provision Job fails with "host … exists but Secret … doesn't".** The API shows a host's credentials only once, and the Secret that held them is gone. Delete the host in the app so the Job can create it again, or restore the Secret.

**Queries never finish.** No BUNNY is answering. Check the BUNNY's logs: `kubectl -n cohort-discovery logs deploy/cohort-discovery-bunny-<collection> --all-containers`. BUNNYs start only after the provision Job has written their host's Secret.

**Counts are 0 or round numbers.** That's on purpose: counts below 10 are hidden and the rest are rounded to the nearest 10. See `synthetic.bunny.*` in [Collections](../customising/collections.md#synthetic-collections).

**The term directory is empty.** Distributions haven't arrived yet. They're collected a minute or so after a collection is created; check the BUNNY's logs and the `scheduler-distributions-collector` resource.

**A concept can't be found.** The minimal vocabulary has only about 3,900 concepts. Import the [full vocabulary](../customising/vocabulary.md).

## Data out of step after a reset

If `generated/secrets.values.yaml` was deleted but the volumes weren't, MySQL, Keycloak and the synthetic Postgres still have the old passwords. Delete the volumes too; see [Stop, restart and reset](../getting-started.md#stop-restart-and-reset).
