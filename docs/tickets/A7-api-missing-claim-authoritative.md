# A7. API: a missing claim counts as empty under an authoritative sync

**Repo:** `project-daphne-api` · **Depends on:** – · **Decisions:** D4, D20

## Goal
When workgroups, roles or custodians sync `always` and authoritatively, an SSO sign-in whose ID token leaves out the claim removes the user's memberships, as an empty list would. Today a missing claim leaves them unchanged.

## Context
Found during S2, at `v1.17.0`.
- Keycloak leaves out the `groups` claim for a user with no groups instead of sending `[]`. Other IdPs do the same.
- `app/Services/Sso/ClaimMapper.php` treats a missing claim as "the IdP says nothing" and skips the sync, whatever the policy says. Removing a user's last group in the IdP therefore leaves their last workgroup and custodian in place.
- The stack works around this with `keycloak.defaultGroup` (D20), which keeps the claim present for users it defines, but not for a group removed by hand.
- Integrated mode (`app/Services/TokenSync/`) has the same "null means skip" pattern. Check whether it should change too, or stay as it is because the Gateway always sends the claim.

## Steps
1. Add a setting, e.g. `claimsaccesscontrol.sync.missing_claim_is_empty` (`CLAIM_SYNC_MISSING_CLAIM_IS_EMPTY`, default `false`), so existing deployments don't change.
2. When it's on and a subject syncs `always` and authoritatively, `ClaimMapper` treats a missing claim as `[]` for that subject. `ensure_default` still applies afterwards.
3. Log the change through `ActivityLogger` as other claim syncs are.

## Done when
- With the setting off, behaviour is unchanged.
- With it on, signing in with no `groups` claim removes the user's workgroups (except the ensured default) and custodians.
- Non-authoritative or `first_login` syncs are unaffected.

## Verification
Feature tests on the SSO callback for both settings, run with `--filter`.
