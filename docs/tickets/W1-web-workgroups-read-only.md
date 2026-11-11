# W1. Web: workgroups read-only when managed externally

**Repo:** `project-daphne-web` · **Depends on:** A4 · **Decisions:** D8

## Goal
When the API reports workgroups as managed externally, the admin workgroups screens show workgroups and their members but offer no way to create or change them, and they say why.

## Context
- The panels are `src/app/(protected)/(admin)/admin/(tabs)/components/Workgroups{Left,Middle,Right}Panel.tsx`, using `src/modules/CreateWorkgroup` and `src/modules/UpdateWorkgroup`.
- Only the users table is gated today, on `manageWorkgroupsInternal`.
- `src/hooks/useFeatures.ts:45` forces it on in standalone mode.
- Actions are in `src/actions/workgroup/`.
- Follow the web repo's CLAUDE.md: reads go through `src/server/data/`, server data is read from context and not copied into Zustand, and copy is in sentence case and says why.

## Steps
1. Add a reader for A4's policy endpoint in `src/server/data/` (`'use cache: private'` with a long `stale`, because it only changes on redeploy). Load it with the admin section's other reads and expose it through the admin section's context.
2. Gate the create section (left), the update members panel (right) and member removal (middle) on it. Collection add and remove follow A4's decision.
3. Replace the hidden controls with one short explanation: "Workgroups are managed by your identity provider. Changes made there apply the next time a user signs in."
4. Remove the `isStandalone ||` override in `useFeatures` only if nothing else relies on it. Otherwise leave the feature flag alone and use the new policy as the gate.
5. Keep the actions as they are. The API returns 403 regardless (D8). If a stale page posts anyway, show that message.

## Done when
- With the policy set to external, no create, update or remove controls render, and the explanation shows.
- With it set to internal, the screens are unchanged.

## Verification
- Jest tests of the pure gating logic, pulled into a sibling `.ts`.
- `npm run lint && npm run test && npm run build`.
- Manual browser check is still outstanding: it can't be automated here.
