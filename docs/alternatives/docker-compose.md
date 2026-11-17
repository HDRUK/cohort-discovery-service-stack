# Running with Docker Compose

This repo runs the Cohort Discovery Service on Kubernetes with Helm and Tilt. If you only want to try the service on one machine and don't have a local cluster, [`AndyRae/cd-build`](https://github.com/AndyRae/cd-build) runs it with `docker compose up` instead. It's a community project, not maintained by HDR UK.

## What it runs

- Web, API and NLP, from images it builds from each service's latest release and publishes to GHCR (amd64 and arm64).
- MySQL and Redis.
- Keycloak with an imported realm, wired as the API's SSO provider. Password sign-in works alongside it.
- A synthetic data node: Postgres loaded by omop-lite's bundled synthetic data, with an availability BUNNY and a distribution BUNNY polling the API.
- A one-shot seed: demo users, a demo collection and its BUNNY credentials (`DevDatabaseSeeder`), and the minimal OMOP vocabulary (`MinimalOmopSeeder`).

## Choosing between them

| | This stack | cd-build |
|---|---|---|
| Needs | A local Kubernetes cluster, Helm, Tilt | Docker with Compose |
| Images | Built from the pinned submodules | Prebuilt from the latest releases |
| Synthetic data | Included, one BUNNY per synthetic collection | Included |
| Keycloak | Included, the only way to sign in | Included, alongside password sign-in |
| Credentials | Generated per install, never committed | Fixed values committed in `example.env` and `docker-compose.yml` |
| Host ports | Web, API and NLP only, configurable ([Host ports](../getting-started.md#host-ports)) | Fixed, and also publishes MySQL on 3306, Redis on 6379 and Postgres on 5432 |
| Beyond a laptop | The same chart, with example values for shared clusters ([Installing beyond a laptop](../installing/beyond-a-laptop.md)) | Local demo only |

Use cd-build for a quick look on one machine. Use this stack to develop against, or as the starting point for a real deployment.

## Before you run it

- **Treat it as a throwaway demo.** Its committed `example.env` includes a Passport signing key, an app key, a JWT secret and key salts, and the Compose file sets fixed database, Keycloak admin and BUNNY passwords. Anyone with the repo can sign tokens for an install that uses them. Don't expose it beyond `localhost`, and don't put real data in it.
- **Port clashes.** It publishes 3000, 8080, 8180, 5001, 3306, 6379 and 5432 on the host. Stop other development containers on those ports first, or edit the `ports:` entries.
- **Shared cookies.** The web app uses the default `token` cookie name, so it shares a sign-in with any other copy of the web app on `localhost`. Sign out of one before using the other, or use a private window.
- **Patched web image.** Its web image changes two upstream files at build time, to work around [cohort-discovery-service-web#245](https://github.com/HDRUK/cohort-discovery-service-web/issues/245) (the sign-in cookie's `Secure` flag) and [#246](https://github.com/HDRUK/cohort-discovery-service-web/issues/246) (Next.js standalone output). Behaviour can differ from the release image until those are fixed upstream.
