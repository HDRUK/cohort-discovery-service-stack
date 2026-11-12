# S0. Stack: scaffold

**Repo:** this one · **Depends on:** D5 · **Decisions:** D5, D11, D12

## Goal
The repo layout every later ticket builds on.

## Steps
1. Add submodules under `services/`: `web`, `api` and `nlp`, from `HDRUK/project-daphne-*`, each pinned to its latest release tag. Leave somop out until S5 decides whether it's a submodule or a published image.
2. Layout:
   ```
   services/{web,api,nlp}/       submodules
   charts/cohort-discovery/      the umbrella chart (D12): Chart.yaml, values.yaml, templates/
     files/                      config the chart reads, overridable through values (D17, moved here by S1)
       nlp/{rules,mappings}.json copied from the NLP defaults
       keycloak/                 S2's realm
       synthetic/                S5's somop configs
   config/
     branding/                   W3's neutral default, a web build input
   scripts/                      build-web.sh (W3), helpers
   Tiltfile                      local development (D12)
   ```
   `charts/cohort-discovery/files/claims-mapping.json` (A3, needs D9) and `charts/cohort-discovery/files/provision.json` (S4) are added by those tickets.
3. The Tiltfile only allows local contexts (`allow_k8s_contexts`), so `tilt up` can't touch a shared cluster by accident.
4. Write `docs/getting-started.md`, which later tickets fill in.

## Done when
- `git submodule update --init` checks out all three services at tags.
- `helm lint charts/cohort-discovery` passes.
- The Tiltfile loads without errors.

## Verification
A fresh `git clone --recurse-submodules` works.
