# A8. API: several IdP values can map to one workgroup or role

**Repo:** `project-daphne-api` · **Depends on:** – · **Decisions:** D4, D9

## Goal
A deployer can map several IdP groups to one CDS workgroup (or several IdP roles to one CDS role), e.g. Keycloak groups `ukri`, `breathe` and `ncs` all giving `UK-RESEARCH`. Today each workgroup takes exactly one IdP value.

## Context
Found on 2026-11-13, at `v1.17.0`, while making the stack's claims mapping show IdP names that differ from the CDS ones.
- `config/claimsaccesscontrol.php` maps `'local name' => 'IdP value'`. `app/Services/Claims/ClaimResolver.php` (`localNames`) keeps the entries whose value is in the claim and returns their keys.
- Keys are unique, so a local workgroup or role matches one IdP value. One IdP value can map to several local names (the stack's `gsk` gives `UK-INDUSTRY` and `NON-UK-INDUSTRY`), but not the other way round. A list as the value is cast to the string `"Array"` and matches nothing.
- `AppServiceProvider` passes `workgroup_mappings` to `ClaimMappingService::setMap` as well. Check what that service expects before changing the shape.

## Steps
1. Let each mapping value be a string or a list of strings: `'uk-research' => ['ukri', 'breathe', 'ncs']`. A string keeps working, so existing config files don't change.
2. In `ClaimResolver::localNames`, match a key when any of its values is in the claim, case-insensitively as now.
3. Update `ClaimMappingService` if it reads the map.
4. In this repo, use list values in `customisations/api/claimsaccesscontrol.php` and add the groups to the chart's `keycloak.groups` once the submodule is bumped. **Done 2026-11-13** against `b257363` (DP-1254), together with `customisations/api/workgroups.php` for the branch's new `config/workgroups.php`.

## Done when
- A string value behaves exactly as today.
- With a list, any one of its values in the claim gives that workgroup or role, and an authoritative sync removes it only when none of them is present.

## Verification
Unit tests on `ClaimResolver` for string and list values, and a feature test on the SSO callback, run with `--filter`.
