# S10. Stack: restructure the user docs after review

**Repo:** this one · **Depends on:** S9

## Goal
The docs site is the one place to read the stack's docs, ordered as a reader needs it (understand, try, customise, deploy, connect collections), with one accurate diagram. It links to the general [service docs](https://hdruk.github.io/cohort-discovery-service-docs/) rather than repeating them. Prompted by a review of the S9 docs from three angles (BUNNY, Next.js, platform engineering) and by the overlap with `cohort-discovery-service-docs`.

## Steps
1. The README leads with the site's URL, and `NOTES.txt` points to the site.
2. Nav order: Overview, Run locally, Customise (opening with a worked example), Deploy to a cluster, Connect a collection, Develop the web app, FAQ, Reference.
3. Merge `running/helm.md` and `installing/beyond-a-laptop.md` into `deploying/index.md`, in deploy order, with a recipe for creating the Secret and a known-limitations list.
4. New pages: `deploying/connect-a-collection.md` (a real custodian's BUNNY type A and type B), `developing/web.md` (the dev loop, build-time vs run-time) and `reference/scheduled-jobs.md`.
5. Turn `operations/` into `faq.md`, and move the docs-site notes to `CONTRIBUTING.md`.
6. One diagram, grouped into browser-facing, service, data and collection host, showing BUNNY type A and type B per collection, in the README and the overview.
7. Fix what the review found wrong:
   - the cluster install command left out the secrets;
   - the CronJob name;
   - suppressed counts are reported as 0;
   - a collection host is one set of credentials;
   - distribution timing;
   - `API_BASE_URL` is set at run time;
   - `organisationName` and `links.organisation` aren't shown in standalone mode.
8. Link to the service docs for BUNNY, identity providers, claim mapping, branding fields, governance and somop.

## Done when
- `mkdocs build --strict` passes, and the links to the service docs resolve.
- `helm template` with the evaluation values and the documented secrets renders.
- The README's and `NOTES.txt`'s links work.

## Out of scope
- The chart gaps the review found (S11).
- Changes to `cohort-discovery-service-docs` (SD1).
