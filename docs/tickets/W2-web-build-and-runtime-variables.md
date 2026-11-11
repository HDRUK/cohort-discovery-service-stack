# W2. Web: build-time vs run-time variables (research)

**Repo:** `project-daphne-web` (read-only) · **Depends on:** – · **Decisions:** D3, informs D6 and D7

## Goal
Decide, variable by variable, whether a generic published web image needs it moved to run time, and what that would cost HDR UK's own stack. The output is a document and a recommendation. **No code changes.**

## Context
- The build args and their readers are listed in `02-verified-facts.md` (web).
- `APPLICATION_MODE` is effectively build-time, because module-level consts are prerendered under `cacheComponents`.
- `NEXT_PUBLIC_*` are inlined into the client bundle.
- HDR UK builds separate integrated and standalone images per environment (`build-args.yaml`, the `INT_*` vars). Production runs on Cloud Run (`cohort-discovery-infrastructure`).
- D3 says change nothing unless it's necessary.

## Questions to answer
1. For each variable: who reads it (server or client), at build or at request, and what breaks in a generic image if it's wrong.
2. Which are actually a problem for a standalone image served at a URL other than localhost?
   - `NEXT_PUBLIC_LOGIN_URL` (login and organisation links) is a likely one.
   - `API_BASE_URL` is server-only and probably fine already.
3. For each problem variable, the cheapest fix:
   - read it on the server and pass it down;
   - replace a placeholder in `.next` when the container starts;
   - or accept a rebuild per deployment.

   Use the Next.js docs in `node_modules/next/dist/docs/` on runtime environment variables.
4. For each fix: what changes in `build-args.yaml`, `dev_deployment.yaml`, `release.yml`, the external `HDRUK/github-actions-templates` and the Terraform `env_vars`.

## Output
- `docs/web-variables.md` in this repo: a table of variable, read where, build/run, problem for a generic image (y/n), proposed fix, and impact on HDR UK.
- A recommendation for D7.
- If a change is needed, a follow-up ticket in the tracker.

## Done when
The table covers every variable in `02-verified-facts.md`, and D7 has a recommendation backed by it.
