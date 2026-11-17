# S9. Stack: user docs and a docs site

**Repo:** this one · **Depends on:** S6

## Goal
Someone who has never seen the project can find out what it is, run it, customise it and keep it running, from a short README and a set of user docs published as an MkDocs site. The docs grew one ticket at a time into a 482-line `getting-started.md` that is partly out of date, leaks decision and ticket IDs, and leaves several settings and day-to-day tasks undocumented.

## Steps
1. Rewrite `README.md` as a landing page: what the stack is, a diagram, the status, the prerequisites (the private composer packages up front), the quick start and links into the docs.
2. Split the user docs into sections under `docs/`:
   - `overview.md`: components, how a query flows, start-up order, glossary
   - `getting-started.md` (same path, so existing links still work): local install with Tilt, credentials, a first query, stop and reset
   - `running/helm.md`, `installing/beyond-a-laptop.md`
   - `customising/`: one page per area, with an overview table of what each change needs (web rebuild, restart, Keycloak re-import, Job re-run)
   - `operations/`: troubleshooting and maintenance
   - `reference/`: every chart value, and what the init, provision and vocabulary Jobs do
3. Document what is missing today: the NLP `rules.json` and `mappings.json` formats, the required `provision.json` fields, the undocumented chart values, the synthetic volume in the reset steps.
4. Replace decision and ticket IDs in the user docs with plain sentences and a link to the tracker. The planning docs (`docs/README.md`, `01-decisions.md`, `02-verified-facts.md`, `web-variables.md`, `tickets/`) stay where they are and out of the site.
5. Fix the out-of-date comparison in `docs/alternatives/docker-compose.md`.
6. `NOTES.txt`: show the ingress URLs when the ingress is on, say that sign-in is through single sign-on, and show the admin password only with the bundled Keycloak.
7. Add `mkdocs.yml` (MkDocs Material, HDR UK styling) and `requirements-docs.txt`.

## Done when
- `mkdocs build --strict` passes.
- No decision or ticket IDs in the user pages, other than links to the tracker.
- Every command in the docs matches the Tiltfile, scripts and chart.
- `helm lint` passes, and `NOTES.txt` renders with the ingress on and off.

## Out of scope
- Publishing the site (GitHub Pages needs a workflow; S7 or a follow-up).
- Moving the planning docs.
- Changes to the services.
