# S6. Stack: Helm umbrella chart

**Repo:** this one · **Depends on:** S1–S5, D12 · **Decisions:** D12, D14

## Goal
`helm install` gives the same stack as Compose on a Kubernetes cluster, with the same config files supplied through values.

## Context
- The service repos' `chart/` folders contain only `Chart.yaml`, so there is nothing to reuse.
- omop-lite has a published Helm Job chart (`oci://ghcr.io/health-informatics-uon/charts/omop-lite`).
- For Keycloak, the API needs `hostAliases` so the issuer URL resolves inside the pod.

## Steps
1. `charts/cohort-discovery/` contains:
   - Deployments for api, queue, nlp and web;
   - a CronJob scheduler;
   - Jobs as Helm hooks: `api-init` (post-install, post-upgrade), `vocab-import` (optional), `provision`;
   - ConfigMaps from `config/` files, and Secrets referenced by name (never values in `values.yaml`).
2. MySQL, Redis and Keycloak are optional subcharts, or external connection settings. Default to external for production and bundled for evaluation.
3. Synthetic BUNNYs are optional, one Deployment per collection, from a values list.
4. Add Ingress templates for web, API and Keycloak, and one example values file per mode (evaluation, production-like).

## Done when
`helm install` on kind with the evaluation values gives the same result as S1–S5's "done when".

## Verification
- `helm lint`, `helm template | kubeconform`.
- An install on kind, then the S1 sign-in check.
