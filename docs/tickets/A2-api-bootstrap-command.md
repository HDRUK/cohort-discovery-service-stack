# A2. API: an idempotent first-boot bootstrap

**Repo:** `project-daphne-api` · **Depends on:** A1 · **Decisions:** D4, D15

## Goal
One command, `php artisan app:bootstrap`, takes an empty database to a usable standalone install, and running it again changes nothing. The stack's init container runs it (S1).

## Context
Today a fresh install needs:
- the Passport keys created by hand;
- several named seeders run in order (`cohort-discovery-service-docs/.../running.md`). A bare `db:seed` runs `CustodianSeeder`, which truncates.
- an admin created with `admin-user:import`, which hard-codes the "Health Data Research UK" custodian.

## Steps
1. Add `app:bootstrap`. It does each of the following only if it hasn't been done yet:
   - `migrate --force`, including the `omop` connection's `migrations_omop` when `BOOTSTRAP_OMOP_MINIMAL=true`, followed by `MinimalOmopSeeder` if the concept table is empty.
   - Create the Passport keys if neither `PASSPORT_PRIVATE_KEY` nor the key files exist.
   - Run `WorkgroupSeeder`, `RolesAndPermissionsSeeder`, `StateSeeder`, `FeatureSeeder` and `PersonalAccessClientSeeder`, all guarded with `firstOrCreate`. Not `CustodianSeeder`.
   - Create the initial custodian from `BOOTSTRAP_CUSTODIAN_NAME`, reusing `custodian:create`.
   - Create the initial admin from `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD`, with the `admin` role and `ADMIN` workgroup, linked to the bootstrap custodian. Skip it if the user exists. Never print the password.
   - Create a scheduler service account (D15) only if `BOOTSTRAP_SERVICE_ACCOUNT_FILE` is set, writing its credentials to that file (0600) on first creation.
   - Run `deploy:run`.
2. Change `admin-user:import` to take `--custodian=` instead of the hard-coded name. Default to the old name so HDR UK's behaviour doesn't change.
3. Leave `start.sh` alone. The stack runs bootstrap as a separate init step, so HDR UK's start-up is unchanged.

## Done when
- On an empty MySQL, `app:bootstrap` exits 0 and the admin can log in through `POST /api/auth/login`.
- A second run reports nothing created.
- `admin-user:import` without `--custodian` behaves as before.

## Verification
- Feature tests for the command: empty DB, second run is a no-op, existing admin left alone, no custodian truncation.
- Run them with `php artisan test --filter=Bootstrap`. Don't run the full suite (it times out locally).
