# W1. Web: IdP-managed memberships read-only or warned

**Repo:** `project-daphne-web` · **Depends on:** A4 · **Decisions:** D8

## Goal
When the API reports that an identity provider manages a user's workgroups, the admin screens show their memberships without a way to change them. Where an edit would only partly stick, the screens warn the admin instead. In both cases they say why. The decision is per user, not per deployment: password-only users on the same deployment stay editable.

## Context
- **The contract** is in `project-daphne-api/access-control-editability-fe-notes.md` (A4, DP-1261):
  - `GET /v1/access_policy` gives the deployment answer, provider labels and `restored_on_sync`;
  - `membership_sources` on users from `GET /v1/users` and `/v1/users/{id}` gives the per-user answer.
- **Panels:** `src/app/(protected)/(admin)/admin/(tabs)/components/Workgroups{Left,Middle,Right}Panel.tsx`, using `src/modules/UpdateWorkgroup`.
  - Removal is in the middle panel, through `removeUsersFromWorkgroup`.
  - The add picker is in `UpdateWorkgroup`, through `updateWorkgroupMembers`, which also adds collections.
- **Gating today:** only the remove table is gated, on `manageWorkgroupsInternal` (`src/hooks/useFeatures.ts:45`, forced on in standalone mode). The add picker isn't gated at all.
- **Web repo rules** (its CLAUDE.md):
  - reads go through `src/server/data/`;
  - server data is read from context, not copied into Zustand;
  - copy is in sentence case and says why.

## Steps
1. **Reader.** Add `src/server/data/accessPolicy.ts` (`'use cache: private'`, long `cacheLife`, its own tag). Load it in `AdminSection` with the other admin reads, and expose it through `AdminSectionContext`. Add the `AccessPolicy` and `membership_sources` types.
2. **Helper.** Write a pure editability helper in a sibling `.ts`, with Jest tests. It takes a subject, the policy and an optional user, and returns the user's block when present, otherwise the deployment block, with provider labels.
3. **`authoritative` users:** hide or disable remove in the middle panel, and leave them out of the add picker. Show one explanation: "Workgroups are managed by your identity provider. Changes made there apply the next time a user signs in."
4. **`additive` users, and `first_login` users who haven't synced yet:** keep the controls, with a warning. For entries in `restored_on_sync`, warn that they come back at the next sign-in. Warn, don't disable: a removal still takes effect until then.
5. **Leave alone:** creating, renaming and deleting workgroups, and collection membership.
6. **User view.** `ViewUser` shows "Managed by <provider>" for workgroups, roles and custodians.
7. **Retire the flag.** Delete `manageWorkgroupsInternal`, `FeatureName.ManageWorkgroupsInternally` and its `DEFAULT_FLAGS` entry.
8. **Keep the actions tolerant of a 403 with a message,** so that API enforcement later (D8) isn't a breaking change.

## Done when
- On a deployment where workgroups are `authoritative`: an SSO-linked user shows no add or remove controls and the explanation, and a password-only user is fully editable.
- `additive` mode, pending `first_login` and `restored_on_sync` entries show warnings.
- With no SSO, the screens are unchanged.

## Verification
- Jest tests of the pure helper.
- `npm run lint && npm run test && npm run build`.
- Manual browser check with a mixed deployment (one password user, one SSO user).
