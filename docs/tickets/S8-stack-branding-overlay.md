# S8. Stack: neutral branding and the branding overlay

**Repo:** this one · **Depends on:** D6 · **Decisions:** D3, D6, D7

## Goal
The stack's web image carries its own neutral brand instead of HDR UK's, and a deployer rebrands by editing `config/branding/` and rebuilding. Split out of W3 (its steps 4 and 5), so that it doesn't wait for W3's upstream fixes.

## Steps
1. Add a neutral brand, "Feasibility Tool", to `config/branding/`: `branding.config.ts`, `theme.ts` (which sets `primary` and `secondary`, otherwise `@hdruk/ui`'s HDR UK palette shows through), `assets/logo.svg`, and placeholder legal pages that say they must be replaced.
2. Add `scripts/build-web.sh <image> [docker build options]`. It copies `services/web` to a temporary folder, leaving out `.git`, `node_modules`, `.next` and `.env*`, copies `config/branding/` over `branding/`, and runs the web's own Dockerfile.
3. Tilt builds the web through the script (`custom_build`), rebuilding when `config/branding/` changes.
4. Document it in `docs/getting-started.md`.

## Done when
- The image built by the script shows "Feasibility Tool" and the new colours on `/login` and the legal pages, with no HDR UK text there.
- Tilt resolves the web build to the script.

## Out of scope
The places where the web ignores `branding/` (the copyright text, the favicons, leftover HDR UK strings on signed-in pages) are W3, which is on hold.
