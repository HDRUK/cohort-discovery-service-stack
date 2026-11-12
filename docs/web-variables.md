# Web variables: build time or run time (W2)

Which of the web's environment variables a generic published image can change at run time, and what moving any of them would cost HDR UK. Checked on 2026-11-12 against `project-daphne-web` `v1.12.0` (Next.js 16.4, `cacheComponents: true`). Feeds decision [D7](01-decisions.md#d7-what-the-published-web-image-is).

## How Next.js treats a variable here

Three rules decide every row below. Each was checked against the `v1.12.0` image the stack builds (`APPLICATION_MODE=standalone`, `NEXT_PUBLIC_TASK_URL=http://localhost:8100/api/v1`, `NEXT_PUBLIC_LOGIN_URL` unset), run with different values at run time.

1. **A `NEXT_PUBLIC_*` variable that is set at build time is inlined** into the browser chunks and the server chunks alike. After that, changing it at run time does nothing. `http://localhost:8100/api/v1` appears as a literal in four browser chunks and four SSR chunks.
2. **A `NEXT_PUBLIC_*` variable that is unset at build time is not inlined.** The code keeps `process.env.X`, so the server reads the run-time value and the browser reads `undefined`. Setting it only at run time therefore makes the server HTML and the browser disagree. With `NEXT_PUBLIC_LOGIN_URL=https://gateway.example.org` at run time only, the `/login` HTML and the logout redirect use it, but the four browser chunks that read it get `undefined`.
3. **A server-only variable is read whenever its module is evaluated.**
   - On routes rendered per request, that means at run time, including the module-level consts (`const applicationMode = process.env.APPLICATION_MODE`).
   - Five routes are fully static and are served from the build (`x-nextjs-cache: HIT`): `/403`, `/terms-and-conditions`, `/about/privacy-policy`, `/user-not-found` and the not-found page. They keep the values from build time.
   - Every other route (`/`, `/login`, `/dashboard`, `/admin/*`, `/help/*` and the rest) took the run-time value. With the image built as standalone and run with `APPLICATION_MODE=integrated`, `/` and `/dashboard` redirected as integrated and the root layout's `ApplicationModeProvider` carried `"integrated"`, while `/403` still carried `"standalone"`.

The Next.js guide (`node_modules/next/dist/docs/01-app/02-guides/environment-variables.md`, "Runtime Environment Variables") gives the same rules and recommends reading values on the server during dynamic rendering, or serving them to the client yourself.

## Variables

"Generic image" means one image built once with the stack's defaults and run as a standalone service at a URL other than `localhost`.

| Variable | Read where | Build or run | Problem for a generic image | Proposed fix | Impact on HDR UK |
|---|---|---|---|---|---|
| `API_BASE_URL` | Server: `src/lib/apiClient.ts`, `api/download/[pid]/route.ts`, `api/auth/logout/route.ts` | Run (route handlers and server actions) | **No.** Set per install. Under SSO the logout redirect sends the browser to it, so it must work from the browser too (already in [verified facts](02-verified-facts.md)). | None | None |
| `APPLICATION_MODE` | Server: root, `(protected)` layouts, `/`, admin `[tabId]`, `AppShell`, `lib/auth.ts`, logout route. Browser: `Custom403.tsx` | Run on dynamic routes; build on the five static routes; always `undefined` in the browser (`Custom403`) | **No**, while the image is built and run as standalone. A single image for both modes would show the build mode on the static routes, so a mode switch still needs a rebuild. | None. Build with `standalone`. | None |
| `NEXT_PUBLIC_LOGIN_URL` | Browser: `Login.tsx`, `externalLinks.ts` (via `Footer`, `Custom403`, `SupportPopOut`). Server: logout route | Build if set, otherwise server at run time and `undefined` in the browser | **No.** Standalone doesn't use it: sign-in and logout go to `/login`, and organisation links fall back to `branding.links.organisation`. Leave it unset; setting it at run time only would split server and browser. | None. Document "leave unset". | None |
| `NEXT_PUBLIC_TASK_URL` | Browser: `UpdateCollection.tsx` ("Task API_BASE_URL" field), `CollectionsGuidance.tsx`, `Footer.tsx` ("API docs" link) | Build (inlined) | **Yes**, but only cosmetic. Custodians are shown `http://localhost:8100/api/v1` as the URL to give their BUNNY, and the footer's "API docs" link points at localhost. No request uses it. | Rebuild per deployment (D7). Optional: [W4](README.md), a run-time value through `ServerDefaultProvider`. | None for a rebuild. W4 needs no change at first; see [below](#if-w4-is-done) |
| `NEXT_PUBLIC_USE_DEBUG_LOGS` | Browser: `src/utils/deps.ts` | Build | No. A development toggle; `false` suits a published image. | None | None |
| `NEXT_PUBLIC_USE_EXAMPLE_QUERY` | Browser: `queryBuilderStore.ts` | Build | No. A demo toggle; `false` suits a published image. | None | None |
| `NEXT_PUBLIC_SUPPORT_URL` | Browser: `SupportPopOut.tsx` | Not a build arg, so server at run time and `undefined` in the browser | No. `SupportPopOut` only renders in integrated mode. | None | None. It isn't set anywhere. |
| `HIDE_NAV` | Server: `AppShell.tsx`, `(public)/layout.tsx` | Run, except build on the five static routes | No. Unset by default. | None | None. Not set in Terraform. |
| `COOKIE_TOKEN_NAME` | Server: `src/config/internals.ts` | Run | No. The stack already sets it at run time (`web.cookieTokenName`). | None | None |
| `DEFAULT_*` (10) | Server: `ServerDefaultProvider.tsx` | Run, except build on the five static routes | No. All optional tuning. | None | None |
| `CONFIG_SERVICE_DESK_URL`, `CONFIG_SERVICE_DESK_SUPPORT_SUFFIX`, `CONFIG_SERVICE_DESK_REPORT_BUG_SUFFIX`, `CONFIG_SUPPORT_URL` | Server: `ServerDefaultProvider.tsx` | Run, except build on the five static routes | No. Integrated-mode support links. | None | None |
| `NODE_ENV` | Both | Build (the Dockerfile sets `production`) | No | None | None |
| `CYPRESS` | Server: `next.config.ts`, `apiClient.ts` | Build and run | No. End-to-end tests only. | None | None |
| `SESSION_SECRET` | Nothing at `v1.12.0` | – | No | None | None. Terraform sets it, and nothing reads it. |

Branding (`@branding/*`) is also resolved at build time. D6 and W3 cover it.

## What this means for D7

Only `NEXT_PUBLIC_TASK_URL` is wrong in a generic image served away from `localhost`, and it is wrong in text and one link, not in behaviour. Branding already forces a rebuild on anyone who wants their own look (D6). So the generic image stays as D7 proposes, and a deployment at another URL rebuilds it with the stack's build script, passing its own `NEXT_PUBLIC_TASK_URL`. No HDR UK pipeline changes, as D3 asks.

The placeholder approach (bake `__TASK_URL__`, then replace it in `.next` when the container starts) is rejected. It needs a new entrypoint in the web image, which D3 rules out. Turbopack's chunk names are hashed, so it would have to rewrite every chunk. It also changes how HDR UK's image starts.

### If W4 is done

W4 makes the task URL a run-time setting for anyone who wants the published image unchanged at another URL. It's optional and only worth doing if that matters more than it seems to today.

- **Web:** add `taskUrl` to `DefaultConfig`. `ServerDefaultProvider` fills it from a new server-only variable (for example `TASK_URL`), falling back to the build-time `NEXT_PUBLIC_TASK_URL`. The three readers take it from `useDefaults()`. The footer on the five static routes keeps the build value, which is acceptable.
- **`build-args.yaml`, `dev_deployment.yaml`, `release.yml`, `HDRUK/github-actions-templates`:** no change. The fallback keeps today's build arg working. The template passes `docker_build_args` through unchanged.
- **Terraform `env_vars`:** no change needed. To retire the build arg later, add `TASK_URL` to the four web services (dev, dev integrated, preprod, prod), then drop `NEXT_PUBLIC_TASK_URL` from `build-args.yaml` and the five GitHub environments.

## Notes for HDR UK's stack

- **Terraform's `NEXT_PUBLIC_*` env vars do nothing.** Terraform sets `NEXT_PUBLIC_TASK_URL`, `NEXT_PUBLIC_LOGIN_URL`, `NEXT_PUBLIC_USE_EXAMPLE_QUERY` and `NEXT_PUBLIC_USE_DEBUG_LOGS` on the web services. The GitHub environments (`dev`, `dev-standalone`, `dev-integrated`, `preprod`, `prod`) define the same names as build vars, and a value set at build time wins (rule 1). They'd only take effect where the GitHub var is empty, and then only on the server (rule 2). The values of the GitHub vars weren't read.
- **The pipelines decide the mode at build time.** `release.yml` calls `build-args.yaml` with `mode: standalone` for preprod and prod, which only selects the un-prefixed GitHub vars. The image's mode comes from each environment's `APPLICATION_MODE` var. Terraform sets `integrated` for preprod and prod, matching what the build must have used, because the static routes keep the build value.

## Found along the way

- **`Custom403` reads `APPLICATION_MODE` in the browser, where it is `undefined`.** The browser treats every install as integrated, so the "sign in again" target becomes `getOrganisationUrl()` instead of `/login`. The server HTML has `/login` (built as standalone), so the result depends on hydration. Not checked in a browser. Recorded as [W5](README.md).
- **Two corrections to [verified facts](02-verified-facts.md):** `APPLICATION_MODE` isn't build-time across the board (rule 3), and `ADMIN_TABS` in `admin/(tabs)/layout.tsx` doesn't exist at `v1.12.0`; the tabs are built in `admin/[tabId]/page.tsx`.

## How this was checked

- Every `process.env` read in `src/` and `next.config.ts` at `v1.12.0` was listed and each reader opened.
- The image `ghcr.io/hdruk/cohort-discovery-web:v1.12.0` (built by the stack) was run three times: built values; `APPLICATION_MODE=integrated`; and integrated plus `NEXT_PUBLIC_LOGIN_URL`, `NEXT_PUBLIC_TASK_URL` and `NEXT_PUBLIC_SUPPORT_URL` set to `example.org` URLs. Each route in `prerender-manifest.json` was fetched, along with `/api/auth/logout`.
- `.next/static/chunks` and `.next/server` were searched for inlined values and remaining `process.env` references.
- HDR UK's side: `build-args.yaml`, `dev_deployment.yaml`, `release.yml` and `deployment.yaml` in the web repo; `docker-build.yaml` in `HDRUK/github-actions-templates`; the web `env_vars` in `cohort-discovery-infrastructure` (dev, preprod, prod); and the names (not values) of the web repo's GitHub environment variables.
