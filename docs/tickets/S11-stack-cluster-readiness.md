# S11. Stack: chart gaps for real clusters

**Repo:** this one · **Depends on:** S6

## Goal
Close the gaps that stop the chart serving real users on a shared cluster. Found by the platform-engineering review in S10 and documented there as known limitations.

## Steps
1. **Keycloak runs `start-dev`** (`templates/keycloak.yaml`). Either run it in production mode (`start`, with hostname and proxy settings and a real database), or state in the chart and values that the bundled Keycloak is for trials only, and fail or warn when it's combined with production-like settings.
2. **No `imagePullSecrets`.** Add `imagePullSecrets` to the values and apply them to every pod, Job and CronJob.
3. **The vocabulary import only reads `hostPath`** (`templates/vocab-import.yaml`), which many managed clusters forbid. Accept an existing PVC (or another volume source) holding the Athena files.
4. **`helm uninstall` deletes the data volumes.** Decide whether the MySQL, Keycloak and synthetic PVCs get `helm.sh/resource-policy: keep`, and document the choice.

## Done when
- Each item is fixed or documented as a deliberate choice, and the "Known limitations" table in `docs/deploying/index.md` is updated.
- `helm lint` passes, and a render with `values.production-like.yaml` shows the changes.

## Out of scope
High availability (more than one replica per part).
