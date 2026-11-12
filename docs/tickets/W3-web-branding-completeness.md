# W3. Web: branding fully overridable from `branding/`

**Repo:** `project-daphne-web`, then this repo · **Depends on:** D6 · **Decisions:** D3, D6, D7

## Goal
Everything that identifies the deployer comes from `branding/`, so replacing that one folder rebrands the app. This repo also ships a neutral default branding set.

## Context
`branding/` already drives the product name, theme, logo and legal pages. The gaps (`02-verified-facts.md`, web):
- `src/utils/getCopyrightText.ts` hard-codes "HDR UK".
- The favicons live in `src/app/`.
- HDR UK and Gateway links are in `src/config/externalLinks.ts`, and Gateway wording in the help `.mdx` files.

No build or run variables change (D3).

## Steps
1. Make `getCopyrightText` use `branding.copyrightHolder`, and add a test.
2. Move the favicon and icon into `branding/assets/` and reference them from `src/app/layout.tsx` metadata. Check the bundled Next.js docs on metadata icons first.
3. List every remaining HDR UK or Gateway string and link. Either move it into `branding.config.ts`, or confirm it only shows in integrated mode.
4. **Moved to S8.** In this repo, add `config/branding/` with a neutral default: plain name, neutral theme, generic logo, placeholder legal pages that say they must be replaced.
5. **Moved to S8.** Add the build script for D6 here: copy `web/` to a temporary context, overlay `config/branding/`, then `docker build`.

## Done when
- Building with the neutral overlay produces no "HDR UK" text in standalone pages. Check with `grep -r "HDR UK" .next/server/app` after the build.
- HDR UK's own build is unchanged.

## Verification
- `npm run lint && npm run test && npm run build` in web.
- Run the overlay build script.
- Manual visual check is still outstanding.
