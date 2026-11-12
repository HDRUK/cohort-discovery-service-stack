# S5. Stack: synthetic BUNNYs with somop

**Repo:** this one, and `somop` · **Depends on:** S4, D16 · **Decisions:** D4, D16

## Goal
Once collections are provisioned, BUNNYs are added by hand, one per collection. Each one has synthetic OMOP data in Postgres, so queries in the web return results without any real data.

## Context
- somop is a pip CLI with no Dockerfile. `somop run` writes and runs its own Compose file (`somop/compose.py`) with postgres, omop-lite and `hutch/bunny:edge`. That doesn't fit a cluster, so use somop's `generate` step only and let the chart own the containers (D16).
- omop-lite has a published Helm Job chart (`oci://ghcr.io/health-informatics-uon/charts/omop-lite`).
- Check the BUNNY env names against `somop/compose.py` and the hutch-bunny docs: `TASK_API_BASE_URL`, `TASK_API_USERNAME`, `TASK_API_PASSWORD`, `COLLECTION_ID`, `DATASOURCE_DB_*`, `LOW_NUMBER_SUPPRESSION_THRESHOLD`, `ROUNDING_TARGET`.

## Steps
1. In somop: add a Dockerfile, with no committed secrets (H1). Decide whether somop is published (D2) or built from a submodule.
2. `synthetic.enabled` in the chart adds one `postgres:16` StatefulSet for all synthetic collections, one database each.
3. Per collection, as a manual Tilt resource, plus a script for non-Tilt installs:
   - a `somop generate` Job writing CSVs to a PVC;
   - an omop-lite Job loading them into that collection's database;
   - a `hutch/bunny` Deployment pinned to a release, not `:edge`, with its credentials from S4's `bunny-<host>` Secret.
4. Default BUNNY to the polling interval and obfuscation values in somop's defaults.

## Done when
- A query run from the web completes with results from every synthetic collection that has a BUNNY.
- `tilt down` and `tilt up` doesn't regenerate data unless asked.

## Verification
- An end-to-end query in the browser (manual).
- BUNNY logs show tasks picked up and results posted.
