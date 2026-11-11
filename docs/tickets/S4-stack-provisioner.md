# S4. Stack: provisioner

**Repo:** this one · **Depends on:** S1, A2 · **Decisions:** D4

## Goal
After the core is up, a one-off `provision` container creates custodians, collection hosts and collections from `config/provision.json` through the API. It writes each collection's BUNNY settings to a shared volume.

## Context
The endpoints are in `02-verified-facts.md` (API):
- Sign in with `POST /api/auth/login` as the bootstrap admin.
- `POST /api/v1/collection_hosts` returns `client_id` and `client_secret` **only once**, and they can't be retrieved again.
- `POST /api/v1/custodians/{pid}/collections` with `host_id`. The collection `pid` is `COLLECTION_ID`.
- A state transition may be needed for the collection to become active (`PUT /v1/collections/{id}/transition_to`). Check which states BUNNY needs.

## Steps
1. `config/provision.json`: custodians, then hosts per custodian, then collections per host. Each collection names the somop config it uses (S5).
2. A small script (Python or shell + `curl` + `jq`, in an image with no other dependencies) that:
   - signs in;
   - finds or creates each custodian, host and collection by name;
   - on creating a host, writes `generated/<host>.env` with `TASK_API_BASE_URL`, `TASK_API_USERNAME`, `TASK_API_PASSWORD` and `COLLECTION_ID`s (file mode 0600) to a named volume.
3. Idempotency: if a host already exists but its `generated/` file is missing, the credentials are lost. Stop with a clear message ("delete host X or restore its file"). Don't recreate silently.
4. Never log credentials or the admin password.

## Done when
- A first run creates everything and writes one file per host.
- A second run creates nothing and exits 0.

## Verification
- Run it twice.
- Check the API lists the collections.
- `curl -u` with a generated credential against `/api/v1/task/nextjob/...` returns 204 or 200, not 401.
