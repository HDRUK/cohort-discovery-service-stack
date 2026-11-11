# A3. API: claims mapping from a mounted file

**Repo:** `project-daphne-api` · **Depends on:** D9 · **Decisions:** D4, D9

## Goal
A deployer can supply the mapping from IdP claim values to local workgroups and roles as a file mounted at run time, without rebuilding the image.

## Context
- `config/claimsaccesscontrol.php` hard-codes `workgroup_mappings` and `role_mappings` (`local => IdP value`). Only the sync policy is set by env.
- `start.sh` runs `config:cache`, so whatever is read must be read while the config loads.
- `AppServiceProvider.php` also passes `workgroup_mappings` to the package's `ClaimMappingService::setMap()`.
- Documentation of the current format is in `cohort-discovery-service-docs/docs/developers/deploying/claim-mapping.md`.

## Steps
1. In `config/claimsaccesscontrol.php`, when `CLAIMS_MAPPING_PATH` is set and readable, decode it as JSON `{ "workgroup_mappings": {...}, "role_mappings": {...} }` and use any key it provides in place of the PHP default. When it isn't set, nothing changes.
2. Fail fast at boot if the path is set but missing or invalid JSON. Silently falling back would grant different access from what the deployer intended.
3. Add an example file `config/claims-mapping.example.json` matching the current defaults, and document it in the docs repo's `claim-mapping.md`.

## Done when
- With the env var unset, behaviour is identical.
- With a mounted file, `config('claimsaccesscontrol.workgroup_mappings')` returns the file's values after `config:cache`.
- An invalid file stops boot with a clear message.

## Verification
- Unit test the config loading: unset, valid, missing file, invalid JSON.
- Run the `ClaimMapper` tests with `--filter=ClaimMapper`.
