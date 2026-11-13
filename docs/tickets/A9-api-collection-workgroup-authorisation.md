# A9. API: authorise adding and removing a collection's workgroups

**Repo:** `project-daphne-api` · **Depends on:** – · **Decisions:** D4

## Goal
Only a user allowed to update a collection can add it to, or remove it from, a workgroup.

## Context
Found during S4, at `b257363`.
- `CollectionController::addToWorkgroup` and `removeFromWorkgroup` (`POST` and `DELETE /api/v1/collections/{id}/workgroup…`) never call `$this->authorize`. Their route group in `routes/api.php` has `cbac:admin` commented out ("permissions to be fixed in DP-354"), so any signed-in user, a researcher included, can share any collection with any workgroup and so make an active collection visible to that workgroup.
- `transitionTo` in the same controller authorises with `update`, and `CollectionPolicy::update` already exists.
- `addToWorkgroup` also writes an `attached` activity entry on every call, even when the link already exists (`firstOrCreate`).
- Check with the team whether DP-354 already covers this before starting.

## Steps
1. Authorise both actions with `CollectionPolicy::update`, returning 403 as `transitionTo` does.
2. Log `attached` only when the link was created.

## Done when
- A researcher gets 403 adding or removing a collection's workgroup; an admin, and a member of the collection's custodian, still can.
- Repeating an add writes no second activity entry.

## Verification
Feature tests for both routes and each role, run with `php artisan test --filter=...`.
