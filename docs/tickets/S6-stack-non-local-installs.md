# S6. Stack: non-local installs

**Repo:** this one · **Depends on:** S1–S5 · **Decisions:** D12, D14, D22

## Goal
The same chart installs somewhere other than a laptop: behind an ingress, with external MySQL, Redis and IdP, and secrets supplied by name.

## Context
- The chart assumed `localhost`: Keycloak's URL was fixed to `http://localhost:<port>`, the API and web pods ran socat sidecars so `localhost` reached in-cluster Services, and the provision Job mapped `localhost` URLs to Services (`ROUTE_HOSTS`). MySQL and Redis hosts were the bundled Services, and the Secret was always rendered from values.
- The web's sign-in cookie is `Secure` (web#245), so any host other than `localhost` needs HTTPS.
- The web image carries one API URL for custodians (`NEXT_PUBLIC_TASK_URL`) until W4.

## Steps
1. `keycloak.url` sets the bundled Keycloak's browser URL. The socat sidecars and `ROUTE_HOSTS` apply only to `localhost` URLs. `hostAliases` covers clusters that can't resolve the public hosts.
2. Ingress for web, API and the bundled Keycloak, off by default, with hosts taken from `web.appUrl`, `api.appUrl` and `keycloak.url`.
3. `mysql.enabled` and `redis.enabled`: when off, `host` and `port` come from values, and passwords from the Secret (`mysql-password`, `redis-password` with `redis.auth`).
4. External identity provider: any OIDC issuer through `sso.issuer`, `sso.clientId` and `sso-client-secret`. The provision Job needs Keycloak, bundled or external (D22); with another provider it's turned off.
5. `secrets.existingSecret` names a Secret with the keys listed in `getting-started.md`, and the chart renders none.
6. Every container has requests and a memory limit. No CPU limits.
7. `values.evaluation.yaml` (everything bundled, ingress on) and `values.production-like.yaml` (everything external).
8. A volume shared by the API and queue pods at `storage/app/private`, so Horizon can read the distribution files the API stores. It had been missing since S1, so no distributions were processed. `ReadWriteOnce` by default, `ReadWriteMany` for clusters with more than one node.

## Done when
With each example values file, the stack installs and a user can sign in, with the external services stubbed for the production-like file. With default values, the render is unchanged apart from resources and the shared upload volume.

## Verification
- `helm lint` and `helm template | kubeconform` for each values file.
- An install of each into its own namespace on Rancher Desktop, behind its Traefik ingress, then the sign-in check.
