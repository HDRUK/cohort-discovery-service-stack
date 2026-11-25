# A4. API: externally managed access

**Repo:** `project-daphne-api` · **Jira:** DP-1261 · **Depends on:** – · **Decisions:** D4, D8

## Goal
Tell the web which memberships an identity provider manages. This covers workgroups, roles and custodians, both for the deployment as a whole and for each user, so the web can show them read-only or warn before an edit that won't last (W1).

## Context
- **Sync policy.** It is set by `CLAIM_SYNC_{WORKGROUPS,ROLES,CUSTODIANS}` plus `*_AUTHORITATIVE` (`config/claimsaccesscontrol.php`, `app/Services/Claims/ClaimSyncPolicy.php`). Trust and authoritative are global per subject; `claim_mapping` is per SSO provider (`config/sso.php`).
- **Claims only reach a user in two ways:**
  - `ClaimMapper::apply`, on a standalone SSO sign-in at a provider that maps the claim;
  - `DecodeJwt::syncIntegratedOncePerToken`, from the Gateway token in integrated mode.

  Password sign-ins never sync. `first_login` depends on each user's `claims_synced_at`.
- **So one deployment-wide flag is wrong for mixed deployments** (D8):
  - a password-only user is unmanaged;
  - so is a user of a provider that doesn't map that subject.
- **Some entries come back at every sync, whatever the claims say:**
  - the `DEFAULT` workgroup (`ensure_default`);
  - the SDE workgroups in integrated mode (`sde_from_claim`);
  - the `user` role (`RoleSyncFloor`).
- **Only workgroup membership has edit endpoints** (`POST`/`DELETE /v1/users/{id}/workgroup`). Roles and custodians are written only by artisan imports.
- The web's `manage-workgroups-internally` flag is web-only (the API's `FeatureSeeder` doesn't list it), and it can't express a per-user answer. W1 retires it.

## Steps
1. **`GET /api/v1/access_policy`** (admins only, the same `viewAny` user policy as the users index). It returns `operation_mode`, `providers` (slug → label, or `gateway`), and for each subject:
   - `mode`: `internal | first_login | additive | authoritative`
   - `authoritative`
   - `editable`
   - `restored_on_sync`: `{id, name, when: every_sync|sde_approved}`
2. **Per-user `membership_sources`** on `GET /v1/users` and `GET /v1/users/{id}`: `{mode, editable, sources}` for each subject. Resolve it from the user's identities at enabled providers that map the subject (or `gateway`), downgrading `first_login` to `internal` once the user has synced. Make sure the users index has no N+1.
3. **Advisory, not enforced** (D8). The workgroup add and remove endpoints stay at 200. When the target user's workgroups aren't `internal`, also log a `claim_managed_membership_edited` activity entry with the mode, sources, action and `restored_on_sync`.
4. **Collections in a workgroup** stay editable; they aren't an IdP concern. So do creating, renaming and deleting workgroups: claims map onto existing workgroups by name.
5. **Document** it in the API's `docs/ARCHITECTURE/` and in the docs repo's `access-control-policy.md`.

The full contract, the mode rules and the FE guidance are in `project-daphne-api/access-control-editability-fe-notes.md` (DP-1261).

## Done when
- The deployment endpoint reports the configured policy, including `restored_on_sync`.
- A password-only user shows `internal` for every subject on a deployment where SSO users are `authoritative`.
- Editing a managed user's workgroups still succeeds, and writes the warning to the activity log.
- With the default policy and no SSO, nothing changes.

## Verification
Feature tests with `--filter`: regressions and edge cases first (password-only user, a disabled or removed provider, two providers, `first_login` before and after sync, integrated mode, unknown trust, query count on the users index), then the happy path.
