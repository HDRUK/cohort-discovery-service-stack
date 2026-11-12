# S2. Stack: Keycloak

**Repo:** this one · **Depends on:** S1, A3 · **Decisions:** D4, D12

## Goal
A throwaway Keycloak runs in the chart (on by default under Tilt), with a realm imported on start, wired as the API's `default` SSO provider. Signing in through it syncs workgroups and roles from claims.

## Context
`cohort-discovery-service-docs/docs/developers/deploying/examples/keycloak.md` is the specification:
- realm `cohort-discovery-service`;
- groups named after the `workgroup_mappings` values;
- realm roles `GENERAL_ACCESS`, `SYSTEM_ADMIN` and `CUSTODIAN`;
- a confidential client `cohort-discovery-service-api` with PKCE, redirecting to `…/api/auth/sso/default/callback`, with the post-logout redirect set;
- flat `groups` and `roles` mappers on the ID token;
- test users with verified email.

The main pitfall is that the issuer must be the same URL for the browser and the API pod.

## Steps
1. `keycloak.enabled` in the chart: pinned `quay.io/keycloak/keycloak`, `start-dev --import-realm`, a realm JSON from `charts/cohort-discovery/files/keycloak/` via a ConfigMap, and `dev-file` storage on a PVC. No separate database: it's throwaway.
2. Fictional users only, e.g. `admin@example.com` with `SYSTEM_ADMIN` and `researcher@example.com` with `GENERAL_ACCESS`. Their passwords come from `generated/secrets.values.yaml` (S1), never committed.
3. Hostname. Back-channel endpoints and `hostAliases` won't work (see `02-verified-facts.md`, API, SSO): the API rejects discovered endpoints that aren't on the issuer's origin, and PHP's libcurl resolves `localhost` and `*.localhost` itself. Instead, make the browser URL work inside the pods, as `AndyRae/cd-build` does with Compose:
   - Keycloak listens on the same port inside the cluster as its host port-forward (`KC_HTTP_PORT`, `KC_HOSTNAME=http://localhost:<port>`), configurable like the other host ports.
   - The API pod gets a `socat` sidecar listening on `localhost:<keycloak port>` and forwarding to the Keycloak Service. `SSO_DEFAULT_ISSUER` is the browser URL.
   - The web's SSO logout redirects the browser to its run-time `API_BASE_URL`, which S1 sets to the in-cluster Service. Under SSO, the web pod needs `API_BASE_URL=http://localhost:<api port>` and a `socat` sidecar forwarding that port to the API Service. Check where the SSO button's link comes from too: cd-build says the API builds it from the request host.
   - Pin `SSO_DEFAULT_REDIRECT_URI` to match the realm's redirect URI, and shorten `SSO_DISCOVERY_CACHE_TTL_SECONDS` and `SSO_JWKS_CACHE_TTL_SECONDS` (default 3600) so a Keycloak restart with new keys doesn't break sign-in.

   Record what worked in `02-verified-facts.md`.
4. Set `SSO_ENABLED`, `SSO_DEFAULT_*` and `CLAIM_SYNC_*` per D4. Keep `charts/cohort-discovery/files/claims-mapping.json` consistent with the realm's group and role names.

## Done when
- Signing in as the fictional researcher through Keycloak lands in the app with the workgroups from their groups.
- Removing a group in Keycloak and signing in again removes the workgroup.

## Verification
Manual, in the browser. Note it as outstanding if it can't be done.
