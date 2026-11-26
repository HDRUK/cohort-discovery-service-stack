# A1. API: keep the token and local files out of the image

**Repo:** `project-daphne-api` · **Depends on:** – · **Decisions:** D2 · **PR:** api #378

## Goal
An API image built with a GitHub token doesn't contain the token, a local `.env` or key files, and doesn't wipe its database when run with `APP_ENV=local`. The token stays required, and nothing is published (D2, 2026-11-26).

## Context
Three problems in the current build (`02-verified-facts.md`, API):
- **Private dependencies:** `composer.json` pulls five private `hdruk/*` VCS packages, so the build needs a `github_token` secret.
  - Correction 2026-11-26: `dev` still declares three `hdruk/*` packages as `vcs` repositories in `composer.json`, and all of them are public. The build still reads the `github_token` secret, and D2 keeps it required.
- **The token stays in the image:** the Dockerfile writes it to `/tmp/composer/auth.json` and never deletes it, so anyone who can pull an image built with a token can read it. Found in S13 (2026-11-18).
- **No `.dockerignore`:** with `COPY .`, a local build bakes in `.env` and `storage/oauth-*.key`.
- **Dev defaults:** the image sets `REBUILD_DB=1` and uses a dev `php.ini`.

HDR UK's pipeline passes `--secret id=github_token` and has to keep working.

## Steps
1. Pass the token to composer as `COMPOSER_AUTH` inside the `RUN` step, so it is never written to a layer.
2. Add a `.dockerignore`: `.env*` except `.env.example`, `storage/*.key`, `vendor`, `node_modules`, `.git`, test output.
3. Change the image default to `REBUILD_DB=0`. HDR UK dev, preprod and prod already set `REBUILD_DB=0`.
4. Once merged, update the stack's deploy docs (`docs/deploying/api.md` and the known limitations) to drop the token-in-image and `.env` warnings.

## Done when
- An image built with the token contains no token, `.env` or key files.
- HDR UK's builds, which pass the token, still work.

## Verification
- `docker build --no-cache --secret id=github_token,env=GITHUB_TOKEN .` in a clean clone, and the token not found in `docker history --no-trunc` or the saved image.
- `docker run --rm <img> sh -c 'ls -a /var/www | grep -c "^.env$"'` prints 0.
- Run the API's filtered tests for anything touched in `start.sh`.
