# S5. Stack: synthetic BUNNYs with somop

**Repo:** this one, and `somop` · **Depends on:** S4 · **Decisions:** D4

## Goal
`make up PROFILE=synthetic` generates synthetic OMOP data per provisioned collection, loads it into Postgres, and runs one BUNNY per collection, so queries in the web return results without any real data.

## Context
- somop is a pip CLI with no Dockerfile. `somop run` writes and runs its own Compose file (`somop/compose.py`) with postgres, omop-lite and `hutch/bunny:edge`.
- That doesn't nest well inside this stack's Compose. Use somop's `generate` (and `load`) steps, and let this stack own the containers.
- Check the BUNNY env names against `somop/compose.py` and the hutch-bunny docs: `TASK_API_BASE_URL`, `TASK_API_USERNAME`, `TASK_API_PASSWORD`, `COLLECTION_ID`, `DATASOURCE_DB_*`, `LOW_NUMBER_SUPPRESSION_THRESHOLD`, `ROUNDING_TARGET`.

## Steps
1. In somop: add a Dockerfile and publish `ghcr.io/hdruk/somop:<tag>` (D2), with no committed secrets (H1). Decide whether somop goes public. If it doesn't, build it from a submodule.
2. Per collection in `provision.json`:
   - a `somop generate` job writing CSVs to a volume;
   - an omop-lite load into a `postgres:16` (one database per collection, in one Postgres);
   - a `hutch/bunny` service pinned to a release, not `:edge`, reading S4's `generated/<host>.env`.
3. Generate the per-collection services. Compose has no loops, so either a script writes `compose/synthetic.generated.yaml` from `provision.json`, or a fixed number of collections is used. Prefer the script.
4. Default BUNNY to the polling interval and obfuscation values in somop's defaults.

## Done when
- A query run from the web completes with results from every synthetic collection.
- `make down` and `make up` doesn't regenerate data unless asked.

## Verification
- An end-to-end query in the browser (manual).
- BUNNY logs show tasks picked up and results posted.
