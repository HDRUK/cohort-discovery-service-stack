# S2. Stack: optional Keycloak

**Repo:** this one · **Depends on:** S1, A3 · **Decisions:** D4

## Goal
`make up PROFILE=keycloak` adds a Keycloak, with a realm imported on start, wired as the API's `default` SSO provider. Signing in through it syncs workgroups and roles from claims.

## Context
`cohort-discovery-service-docs/docs/developers/deploying/examples/keycloak.md` is the specification:
- realm `cohort-discovery-service`;
- groups named after the `workgroup_mappings` values;
- realm roles `GENERAL_ACCESS`, `SYSTEM_ADMIN` and `CUSTODIAN`;
- a confidential client `cohort-discovery-service-api` with PKCE, redirecting to `…/api/auth/sso/default/callback`, with the post-logout redirect set;
- flat `groups` and `roles` mappers on the ID token;
- test users with verified email.

The main pitfall is that `KC_HOSTNAME` must resolve from both the browser and the API container.

## Steps
1. Add a `keycloak` Compose profile: pinned `quay.io/keycloak/keycloak`, `start-dev --import-realm`, and a realm JSON in `config/keycloak/`.
2. Fictional users only, e.g. `admin@example.com` with the `SYSTEM_ADMIN` role and `researcher@example.com` with `GENERAL_ACCESS`. Generate their passwords from `.env`, never commit them, and never use real names.
3. Use one hostname: `KC_HOSTNAME=keycloak.localhost`, plus `extra_hosts` on the API pointing to the host gateway. Document it in `getting-started.md`.
4. Set `SSO_ENABLED`, `SSO_DEFAULT_*` and `CLAIM_SYNC_*` per D4 in the profile's env. Keep `config/claims-mapping.json` consistent with the realm's group and role names.

## Done when
- Signing in as the fictional researcher through Keycloak lands in the app with the workgroups from their groups.
- Removing a group in Keycloak and signing in again removes the workgroup.

## Verification
Manual, in the browser. Note it as outstanding if it can't be done.
