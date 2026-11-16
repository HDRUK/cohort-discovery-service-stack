# A10. API: feature flag defaults from a config file

**Repo:** `project-daphne-api`, then this one · **Depends on:** – · **Decisions:** D3, D9, D21

## Goal
A deployer sets the default state of each feature flag in `customisations/api/features.php`, the same way `workgroups.php` sets the workgroups. Today the defaults are hard-coded in the API, so the stack can't change them without an admin toggling each flag after install.

## Context
Found on 2026-11-16, at `b257363` (`v1.17.0-9`).
- Flags are Laravel Pennant flags in the `features` table. `database/seeders/FeatureSeeder.php` holds them in a private `$features` array of `'name' => bool`.
- The seeder creates only flags that aren't in the table yet, so an admin's later toggle is kept. It purges flags that are no longer listed.
- The stack's init Job runs `FeatureSeeder` on every start (`charts/cohort-discovery/files/api-init/api-init.sh:37`). Deployment steps in the API re-run it when a flag is added.
- The web reads the flags from the API and merges them with its own `DEFAULT_FLAGS` (`useFeatures`, see `02-verified-facts.md`). Standalone mode forces `manage-workgroups-internally` on in the web, whatever the flag says (W1).
- A8 added `config/workgroups.php` read by `WorkgroupSeeder`, and the stack mounts `customisations/api/workgroups.php` over it. This ticket follows the same pattern.

## Steps
1. In the API, move the array into `config/features.php`, returning `'name' => bool`, with today's values. `FeatureSeeder` reads `config('features')`. HDR UK's deployments see no change (D3).
2. Keep the seeder's behaviour: create missing flags with the configured default, leave existing ones alone, purge unlisted ones.
3. In this repo, once the submodule is bumped:
   - add `customisations/api/features.php`, listing every flag with the stack's chosen defaults;
   - add `featuresPhp` to `api_section` in `scripts/customisations-values.sh`;
   - mount it over `config/features.php` in the API, queue and init pods, as `workgroupsPhp` is.
4. Document in `getting-started.md` that the file sets defaults only. Changing a default doesn't change a flag that's already in the database. To apply it, toggle the flag as an admin or reset the database.

## Open
- Should the file only set defaults (as above), or should a flag listed in it be enforced on every init, overriding an admin's toggle? Defaults-only matches the request and today's behaviour. Ask before choosing the other.
- Leaving a flag out of the customisation file purges it. Either the file must list every flag, or the seeder needs to merge the file over the API's own list. Settle this in step 1.

## Done when
- With no customisation file, the API seeds exactly today's flags and values.
- With `customisations/api/features.php`, a fresh stack starts with those defaults, and the web reflects them.
- A second init run changes nothing.

## Verification
Feature tests on `FeatureSeeder`, run with `php artisan test --filter=FeatureSeeder`: config defaults on an empty table, existing flags left alone, unlisted flags purged. Then, in the stack, a fresh `tilt up` with one flag flipped in the customisation file.
