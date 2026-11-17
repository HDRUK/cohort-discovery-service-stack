# SD1. Service docs: link to the stack, and fix what's out of date

**Repo:** [`cohort-discovery-service-docs`](https://github.com/HDRUK/cohort-discovery-service-docs) · **Depends on:** S10

## Goal
The general service docs know the stack exists and point deployers to it, and their own errors are fixed. Found while mapping their overlap with the stack's docs in S10. Page paths below are under `docs/` in that repo.

## Steps
1. `developers/deploying/running.md`, `developers/deploying/limitations.md` and `developers/deploying/index.md` say there are no published images and no general-purpose Helm chart. Link to the stack as a reference Kubernetes deployment, and to its docs site.
2. `developers/deploying/carrying-changes.md` says no mechanism has been settled. Describe the stack's approach as one answer: mounted config files, plus a build-time branding overlay, with a diff against upstream on upgrade.
3. `developers/deploying/claim-mapping.md` says one IdP value per workgroup ("not the reverse"). The API accepts a list (`ClaimResolver.php` casts each value with `(array)`), and the stack uses lists. Correct it.
4. `architecture/governance.md` says counts of 5 to 10 are rounded to the nearest 10, which contradicts the "below 10 → 0" in `bunny/configuration.md`. Make them agree.
5. `reference/glossary.md` has no entries for collection, collection host (one set of credentials, not a machine), workgroup, distribution, or type A and type B BUNNY. Add them.
6. `developers/deploying/examples/keycloak.md` warns about Keycloak's hostname inside containers. Point to the stack's solution (Keycloak on the same port inside the cluster, with socat sidecars).
7. Optionally, `developers/index.md` (deployment modes) and `developers/somop/index.md` link to the stack as the no-setup way to run the service with synthetic data.

## Done when
The service docs' deploying section links to the stack, and items 3 to 5 are corrected.
