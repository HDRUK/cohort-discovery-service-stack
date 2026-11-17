# Develop the web app

The web app's source is `services/web`, a git submodule pinned to a release of [`project-daphne-web`](https://github.com/HDRUK/project-daphne-web). Make changes in that repo and open the PR there; this repo then moves its pin. Don't commit changes inside `services/`.

## Under Tilt: slow but faithful

Tilt watches `services/web` and `customisations/web/branding/`. Every change rebuilds the **production** web image through `scripts/build-web.sh` and restarts the pod. That takes several minutes, and there's no hot reload. It's the right loop for checking branding, or how a change behaves in the real image, but not for day-to-day frontend work.

## Beside the stack: `npm run dev`

For a fast loop, run the web's dev server against the stack's API, Keycloak and data.

!!! note
    These steps haven't yet been checked end to end. If you try them, update this page.

Single sign-on sends the browser back to `web.appUrl`, which under Tilt is `http://localhost:3000`. So the dev server has to take over port 3000 from the stack's web:

1. Start the stack as usual with `tilt up`.
2. Stop the stack's web, which frees port 3000: `tilt disable web`, or click **Disable** on the `web` resource in the Tilt UI.
3. In `services/web` (or your own checkout of the web repo), create `.env.local`:

    ```bash
    APPLICATION_MODE=standalone
    API_BASE_URL=http://localhost:8100
    NEXT_PUBLIC_TASK_URL=http://localhost:8100/api/v1
    COOKIE_TOKEN_NAME=cds_stack_token
    ```

4. Run `npm install && npm run dev`, open http://localhost:3000 and sign in with **Single Sign-On** as one of the [stack's users](../getting-started.md#sign-in).
5. When you've finished, stop the dev server and run `tilt enable web`.

The dev server uses the web repo's own `branding/`, not the stack's. Copy `customisations/web/branding/` over it if you need the stack's look.

## Build time or run time

Some web settings are fixed when the image is built; others are read on every request. The service docs' [web page](https://hdruk.github.io/cohort-discovery-service-docs/developers/web/) has the full list. For this stack:

| Setting | When | Set by |
|---|---|---|
| `branding/` | Build | `customisations/web/branding/`, copied in by `scripts/build-web.sh` |
| `NEXT_PUBLIC_*` (`NEXT_PUBLIC_TASK_URL`, `NEXT_PUBLIC_USE_EXAMPLE_QUERY`, `NEXT_PUBLIC_USE_DEBUG_LOGS`) | Build: inlined into the browser code | Build arguments in the Tiltfile, or yours with `scripts/build-web.sh` |
| `API_BASE_URL` | Run, on the web server only | The chart: `api.appUrl` with sign-in on, otherwise the API's in-cluster address |
| `APPLICATION_MODE` | Run (built as `standalone` too) | The chart: always `standalone` |
| `COOKIE_TOKEN_NAME` | Run | `web.cookieTokenName` |

Changing a build-time setting means a new image. That's why changing `CDS_API_PORT` under Tilt rebuilds the web: the task URL shown to custodians is built in.

## Cookies and ports

Browsers share cookies between ports on the same host. The stack's web names its sign-in cookie `cds_stack_token` (`web.cookieTokenName`) rather than the web's default `token`, so a separate development stack on `localhost` and this stack don't overwrite each other's sign-in. If you see `Token signature mismatch`, two copies of the web app are sharing a cookie name: sign out of both, or use a private window.

To run this stack beside another development stack, move it to other ports; see [Host ports](../getting-started.md#host-ports).

## Rebrand

See [Branding](../customising/branding.md).
