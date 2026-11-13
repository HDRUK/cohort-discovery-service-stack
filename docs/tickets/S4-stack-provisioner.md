# S4. Stack: provisioner

**Repo:** this one · **Depends on:** S1, S2 · **Decisions:** D4, D21, D22

## Goal
After the core is up, a provisioning Job creates custodians, collection hosts and collections from `customisations/provision.json` through the API (D21), adds each collection to its workgroups and makes it active, so researchers in those workgroups see it with no admin approval. It stores each host's BUNNY credentials, and its collections' IDs, in a Kubernetes Secret.

## Context
The endpoints are in `02-verified-facts.md` (API):
- `POST /api/v1/collection_hosts` returns `client_id` and `client_secret` **only once**, and they can't be retrieved again.
- `POST /api/v1/custodians/{pid}/collections` with `host_id`. The collection `pid` is `COLLECTION_ID`.
- A researcher sees a collection only when it's `active` **and** in one of their workgroups (`Collection::scopeVisibleToUser`). `draft` → `active` is an allowed transition (`PUT /v1/collections/{id}/transition_to`), and `POST /v1/collections/{id}/workgroup` adds a workgroup.
- Service accounts only reach `/api/v1/services/caller/*`, and password sign-in is off, so the Job signs in through Keycloak as the bootstrap admin (D22). A2 isn't needed: the init Job already seeds the admin.

## Steps
1. `customisations/provision.json`, passed to the chart as `provision.json` by `scripts/customisations-values.sh`: custodians, then hosts per custodian, then collections per host, each with a `description`, the `workgroups` it's shared with and whether it's `synthetic` (S5).
2. `charts/cohort-discovery/files/provision/provision.py`, standard library only, in a pinned `python` image, run as a Helm `post-install`/`post-upgrade` hook Job (after api-init) with a ServiceAccount allowed to get, create and patch Secrets in its namespace. It:
   - signs in as `bootstrap.adminEmail` through Keycloak (D22), reaching the browser URLs inside the cluster by routing their host and port to the Services (`ROUTE_HOSTS`);
   - checks every named workgroup exists before changing anything;
   - finds or creates each custodian, host and collection by name;
   - on creating a host, writes Secret `bunny-<host>` with `TASK_API_BASE_URL`, `TASK_API_USERNAME` and `TASK_API_PASSWORD`, then adds `collection-<collection>` keys holding each collection's `pid`;
   - adds missing workgroups and moves the collection to `active` if it isn't.
3. Idempotency: if a host already exists but its Secret is missing, the credentials are lost. Stop with a clear message ("delete host X or restore its Secret"). Don't recreate silently.
4. Never log credentials.
5. Under Tilt it runs automatically after `api` and `keycloak` are ready, and again whenever `provision.json` changes. It's off when Keycloak is.

## Done when
- A first run creates everything and one Secret per host, and the collections are active and in their workgroups.
- A second run creates nothing and exits 0.
- The researcher, signed in through Keycloak, sees the collections shared with their workgroups.

## Verification
- Run it twice.
- Check the API lists the collections, active, with their workgroups.
- `curl -u` with a generated credential against `/api/v1/task/nextjob/...` returns 204 or 200, not 401.
- Sign in as the researcher in a browser and see the collections (manual).
