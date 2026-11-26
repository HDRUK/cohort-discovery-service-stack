# A1. API: an image anyone can build

> **Not needed** (D2, 2026-11-26): the stack doesn't publish images, deployers build the API with a GitHub token, and the API repo's image build is left as it is. The deploy docs warn about the token and local files ending up in the image. For the record, `dev` still declares three `hdruk/*` packages as `vcs` repositories, and all of them are public.

**Repo:** `project-daphne-api` · **Depends on:** D13 · **Decisions:** D2

## Goal
`docker build .` works from a clean public checkout without a GitHub token, and produces an image that is safe to run as a production server.

## Context
Three problems in the current build (`02-verified-facts.md`, API):
- **Private dependencies:** `composer.json` pulls five private `hdruk/*` VCS packages, so the build needs a `github_token` secret.
  - Update 2026-11-13: on `dev` (seen at `b257363`) `composer.json` no longer declares the private VCS packages, but the Dockerfile still reads `/run/secrets/github_token` unconditionally, so the build still fails without the secret. Step 2 is what's left.
- **The token stays in the image:** the Dockerfile writes it to `/tmp/composer/auth.json` and never deletes it, so anyone who can pull an image built with a token can read it. Found in S13 (2026-11-18).
- **No `.dockerignore`:** with `COPY .`, a local build bakes in `.env` and `storage/oauth-*.key`.
- **Dev defaults:** the image sets `REBUILD_DB=1` and uses a dev `php.ini`.

HDR UK's pipeline passes `--secret id=github_token` and has to keep working.

## Steps
1. Make the five packages public on GitHub, or publish them on Packagist. Run H1's scan on each package first. If composer still declares them as `vcs` repositories, it can fetch public ones without a token.
2. Make the `github_token` secret optional in the Dockerfile (`--mount=type=secret,id=github_token,required=false`), so HDR UK's build is unchanged.
3. Delete `/tmp/composer/auth.json` in the same `RUN` step that writes it, or pass the token with `COMPOSER_AUTH` so it is never written.
4. Add a `.dockerignore`: `.env*` except `.env.example`, `storage/*.key`, `vendor`, `node_modules`, `.git`, `tests` output.
5. Change the image defaults to `REBUILD_DB=0` and a production `php.ini`, with the dev ini selected by build arg. Check `dev_deployment.yaml` and the infra `locals.tf` to see whether HDR UK dev relies on `REBUILD_DB=1` being baked in. If it does, set it in that environment's env instead.
6. Add a GHCR publish job, `ghcr.io/hdruk/cohort-discovery-api:<tag>`, on release tags (D2). Leave the existing Artifact Registry pushes alone.

## Done when
- A build from a fresh clone with no secrets succeeds.
- The image contains no `.env` and no key files (`docker run --rm <img> ls storage`).
- HDR UK's dev deploy still works.

## Verification
- `docker build --no-cache .` in a clean clone.
- `docker run --rm <img> sh -c 'ls -a /var/www | grep -c "^.env$"'` prints 0.
- Run the API's filtered tests for anything touched in `start.sh`.
