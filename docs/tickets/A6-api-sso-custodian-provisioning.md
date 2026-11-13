# A6. API: create custodians from SSO claims

**Repo:** `project-daphne-api` · **Depends on:** – · **Decisions:** D4

## Goal
When a user signs in through standalone OIDC SSO with a custodian claim that names a custodian the API doesn't have, the API can create that custodian and add the user to it, as integrated mode already does. It is off by default, so existing installs behave as they do now.

## Context
Found during S2, at `v1.17.0` and on `dev` (`b33cc71`).
- **Integrated mode creates custodians.** `app/Services/TokenSync/CustodianSyncerService.php`, called from `DecodeJwt`, upserts `{id, name}` objects from the Gateway JWT by `external_custodian_id`, then syncs membership.
- **Standalone OIDC doesn't.** `app/Services/Sso/ClaimMapper.php::syncCustodians` calls `ClaimResolver::custodianIdsForClaimValues`, which only matches existing `custodians.name` case-insensitively and ignores anything unknown. The docblock there says this is deliberate: "in standalone mode custodians are provisioned by an admin".
- A Keycloak `groups` claim is a flat list of strings, so there is no external ID, only a name.
- The provision settings live under `claimsaccesscontrol.provision` (`CLAIM_PROVISION_DEFAULTS_ON_CREATE`).

## Steps
1. Add `claimsaccesscontrol.provision.create_custodians` (`CLAIM_PROVISION_CUSTODIANS`, default `false`).
2. When it's on, `ClaimMapper::syncCustodians` creates a custodian for each claim value with no match, named after the value, with `external_custodian_id` and `external_custodian_name` set the way `StandaloneDemoSeeder` and `ImportAdminUsers` set them. Then sync membership as now.
3. Decide which claim values count as custodians. With Keycloak, `custodiansClaim` is `groups`, the same claim as workgroups, so every workgroup group would also become a custodian. Options: a separate claim (for example a `custodians` mapper in the realm), a name prefix, or an allow-list. Record the choice in `01-decisions.md`.
4. Log each creation through `ActivityLogger`.

## Done when
- With the setting off, behaviour is unchanged: unknown values are ignored.
- With it on, an SSO sign-in with an unknown custodian value creates the custodian once and adds the user. A second sign-in creates nothing new.
- Workgroup claim values don't become custodians.

## Verification
Feature tests on the SSO callback for both settings, run with `--filter`. Then, in the stack, sign in as a Keycloak user in a custodian group the API doesn't have.
