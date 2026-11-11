# S7. Stack: CI build and deploy

**Repo:** this one · **Depends on:** S1, D14 (deploy also needs S6) · **Decisions:** D2, D5, D6, D14

## Goal
From GitHub Actions, build web, API and NLP images from the pinned submodules, or from any branch you name, with the stack's config and branding. Push them to GHCR and deploy them to the D14 target. This replaces the "deploy any branch to `dev-standalone`" trigger for the open-source flavour.

## Context
- Today `dev_deployment.yaml`'s `workflow_dispatch` in each service repo deploys a branch to `dev-standalone`, through the external `HDRUK/github-actions-templates`.
- This workflow is separate and doesn't change those (D3).

## Steps
1. A `workflow_dispatch` workflow with inputs `web_ref`, `api_ref` and `nlp_ref` (default: the submodule pin) and `deploy` (true/false).
2. Check out each submodule at its ref. Build:
   - web with `scripts/build-web.sh` (branding overlay, D6);
   - api and nlp with their own Dockerfiles.

   Tag each image with the ref's short SHA and push to GHCR as packages scoped to the stack (e.g. `ghcr.io/hdruk/cohort-discovery-stack/web`), separate from the release images.
3. On push to `main`: build the pinned versions and run S1's "done when" as a smoke test in the runner with Compose.
4. When `deploy` is true: `helm upgrade --install` to the D14 target with the built tags. Cluster credentials come from an environment secret, and the environment requires approval.
5. Pin third-party actions to SHAs.

## Done when
- Dispatching with a feature branch of web deploys that branch with the stack's config.
- The Compose smoke test runs on every push to `main`.

## Verification
A dispatch run on a test branch, and the smoke-test job passes.
