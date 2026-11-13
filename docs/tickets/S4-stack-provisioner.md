# S4. Stack: provisioner

**Repo:** this one · **Depends on:** S1, A2 · **Decisions:** D4

## Goal
After the core is up, a provisioning Job creates custodians, collection hosts and collections from `customisations/provision.json` through the API (D21), using a seeded service account. It stores each host's BUNNY credentials in a Kubernetes Secret.

## Context
The endpoints are in `02-verified-facts.md` (API):
- `POST /api/v1/collection_hosts` returns `client_id` and `client_secret` **only once**, and they can't be retrieved again.
- `POST /api/v1/custodians/{pid}/collections` with `host_id`. The collection `pid` is `COLLECTION_ID`.
- A state transition may be needed for the collection to become active (`PUT /v1/collections/{id}/transition_to`). Check which states BUNNY needs.
- **Check first:** service accounts authenticate with basic auth on `/api/v1/services/caller/*`. Find out whether a service account can call the host and collection endpoints, which sit under `decode.jwt`. If it can't, either sign in as the bootstrap admin or raise an API ticket. Ask before choosing.

## Steps
1. `customisations/provision.json`, passed to the chart by `scripts/customisations-values.sh`: custodians, then hosts per custodian, then collections per host. Each collection names the somop config it uses (S5).
2. A small script (shell with `curl` and `jq`, or Python, in a pinned image with no other dependencies), run as a Job with a ServiceAccount allowed to create Secrets in its namespace. It:
   - authenticates;
   - finds or creates each custodian, host and collection by name;
   - on creating a host, writes Secret `bunny-<host>` with `TASK_API_BASE_URL`, `TASK_API_USERNAME`, `TASK_API_PASSWORD` and the `COLLECTION_ID`s.
3. Idempotency: if a host already exists but its Secret is missing, the credentials are lost. Stop with a clear message ("delete host X or restore its Secret"). Don't recreate silently.
4. Never log credentials.
5. In Tilt it's a manual resource.

## Done when
- A first run creates everything and one Secret per host.
- A second run creates nothing and exits 0.

## Verification
- Run it twice.
- Check the API lists the collections.
- `curl -u` with a generated credential against `/api/v1/task/nextjob/...` returns 204 or 200, not 401.
