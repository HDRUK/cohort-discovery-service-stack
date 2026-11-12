# A4. API: externally managed access

**Repo:** `project-daphne-api` · **Depends on:** D8 · **Decisions:** D4, D8

## Goal
When the IdP is authoritative for workgroups (and roles and custodians), the API refuses changes to them through its own endpoints and tells the web, so the web can show them read-only (W1).

## Context
- The sync policy is `CLAIM_SYNC_{WORKGROUPS,ROLES,CUSTODIANS}` plus `*_AUTHORITATIVE` (`config/claimsaccesscontrol.php`, `app/Services/Claims/`). There's no flag saying "managed externally".
- The web already has a `manage-workgroups-internally` feature flag. It's a Pennant flag in the database that an admin can toggle, and standalone mode overrides it, so it can't be a reliable signal.

## Steps
1. Add `ClaimSyncPolicy::managedExternally(string $kind): bool`, which is true when that kind syncs `always` and is authoritative.
2. Guard the write endpoints with it:
   - creating and updating workgroups;
   - adding and removing workgroup members;
   - changing user roles;
   - creating custodians and changing their membership.

   Each returns 403 with a message the web can show ("Workgroups are managed by your identity provider").
3. Adding and removing **collections** in a workgroup isn't an IdP concern. Decide here whether it stays editable, and record the answer in `01-decisions.md`.
4. Expose the result read-only, either in `GET /api/auth/methods` (public) or in a new authenticated `GET /api/v1/access-policy`, e.g. `{ workgroups: "external", roles: "external", custodians: "internal" }`. Prefer the authenticated route, because unauthenticated callers don't need it.
5. Document it in the docs repo's `access-control-policy.md`.

## Done when
- With authoritative sync, each guarded endpoint returns 403.
- With the default policy, nothing changes.
- The policy endpoint reports the current state.

## Verification
Feature tests per endpoint for both policies, run with `--filter`.
