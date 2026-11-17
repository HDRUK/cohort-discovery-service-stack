# S5. Stack: synthetic BUNNYs

**Repo:** this one · **Depends on:** S4, D16 · **Decisions:** D4, D16

## Goal
Every collection marked `"synthetic": true` in `customisations/provision.json` gets a database of synthetic OMOP data and a BUNNY serving it, with no manual steps. Queries in the web return results without any real data.

## Context
- D16: the chart owns every container. somop's own Compose file isn't used, and somop isn't used at all yet, because it has no Dockerfile.
- omop-lite loads its bundled synthetic data when `SYNTHETIC=true`. `SYNTHETIC_NUMBER` picks the bundle: 100, 1000 or 1001. Every collection of the same size returns the same counts.
- omop-lite loads a schema only once. If the schema already has tables it prints "Already Loaded" and exits, so re-running it is safe.
- S4's provisioner writes a `bunny-<host>` Secret with `TASK_API_BASE_URL`, `TASK_API_USERNAME`, `TASK_API_PASSWORD` and one `collection-<collection>` key per collection.

## Steps
1. `synthetic.enabled` (default `true`) adds one `postgres` StatefulSet, `synthetic-db`, with a kept PVC, when at least one collection is synthetic.
2. Per synthetic collection, one Deployment `bunny-<collection>`:
   - an init container creates the collection's database if it's missing;
   - an init container runs omop-lite into schema `omop`, size from `syntheticSize` or `synthetic.defaultSize`;
   - two pinned `hutch/bunny` containers, task types `a` and `b`, with credentials and `COLLECTION_ID` from the host's Secret.
3. The Deployment carries a `cohort-discovery.hdruk.ac.uk/bunny-host` label. When the provisioner creates a host or a collection, it restarts that host's Deployments so they read the new Secret.
4. Tilt groups `synthetic-db` and each `bunny-<collection>` under the `synthetic` label, after `provision`.
5. Polling interval and obfuscation come from `synthetic.bunny` in values.
6. The provisioner gives every collection the `GENERIC` and `DEMOGRAPHICS` distribution schedules that `CollectionSeeder` creates, and runs each one once when it adds it. Without them no type-b task is ever created, and the term directory stays empty.

## Done when
- A query run from the web completes with results from every synthetic collection.
- The term directory shows concepts from each synthetic collection.
- `tilt down` and `tilt up` doesn't reload data.

## Verification
- An end-to-end query in the browser (manual).
- BUNNY logs show tasks picked up and results posted.
- omop-lite logs "Already Loaded" after a pod restart.
