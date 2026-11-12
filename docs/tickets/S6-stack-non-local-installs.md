# S6. Stack: non-local installs

**Repo:** this one · **Depends on:** S1–S5 · **Decisions:** D12, D14

## Goal
The same chart installs somewhere other than a laptop: behind an ingress, with external MySQL, Redis and IdP, and secrets supplied by name.

## Steps
1. Ingress templates for web, API and Keycloak, off by default.
2. Every bundled data store and Keycloak has an `enabled` flag. When it's off, connection settings come from values, and passwords from an existing Secret named in values.
3. `existingSecret` options for everything `scripts/local-secrets.sh` generates.
4. Example values files: `values.evaluation.yaml` (everything bundled, ingress on) and `values.production-like.yaml` (everything external).
5. Resource requests and limits for every workload.

## Done when
`helm install` on a fresh kind cluster with each example values file gives the same result as S1's "done when", with the external services stubbed for the production-like file.

## Verification
- `helm lint` and `helm template | kubeconform` for each values file.
- An install on kind, then the S1 sign-in check.
