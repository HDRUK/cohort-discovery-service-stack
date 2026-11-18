# The web app

The web app is the Next.js front end (`services/web`, from [`HDRUK/project-daphne-web`](https://github.com/HDRUK/project-daphne-web)). The service docs' [web developer guide](https://hdruk.github.io/cohort-discovery-service-docs/developers/web/) explains the code; this page explains how the stack builds and configures it.

It runs as the `cohort-discovery-web` Deployment on `web.port` (3000). Its server side calls the API; browsers call the API directly too.

## Build the image

Unlike the API and NLP, the web image has settings built in: your branding, and a few build arguments. So build it for your deployment, and rebuild it when either changes.

```bash
REGISTRY=registry.example.org/cohort-discovery
API_URL=https://api.cds.example.org

scripts/build-web.sh $REGISTRY/web:1 \
  --build-arg APPLICATION_MODE=standalone \
  --build-arg API_BASE_URL=$API_URL \
  --build-arg NEXT_PUBLIC_TASK_URL=$API_URL/api/v1 \
  --build-arg NEXT_PUBLIC_USE_EXAMPLE_QUERY=false \
  --build-arg NEXT_PUBLIC_USE_DEBUG_LOGS=false
docker push $REGISTRY/web:1
```

`scripts/build-web.sh <image> [docker build options]` copies `services/web` to a temporary folder, copies `customisations/web/branding/` over its `branding/` folder, and runs the web's own Dockerfile. Any file you leave out of `customisations/web/branding/` falls back to the web's own, which is HDR UK's. To build with HDR UK's branding, run `docker build` on `services/web` directly with the same build arguments. See [Branding](../customising/branding.md) for what the folder holds.

Add `--platform linux/amd64` on an Apple Silicon Mac, as for the other images.

### Build arguments

| Build argument | What |
|---|---|
| `APPLICATION_MODE` | Always `standalone` for this stack |
| `NEXT_PUBLIC_TASK_URL` | Your API's URL plus `/api/v1`. The web shows it to custodians as the URL for their BUNNY, and builds the footer's "API docs" link from it. No request uses it, but a wrong value misleads custodians, so rebuild when the API's URL changes |
| `API_BASE_URL` | Has no effect in the browser: the chart sets it at run time (below) |
| `NEXT_PUBLIC_USE_EXAMPLE_QUERY` | `true` starts the query builder with an example query |
| `NEXT_PUBLIC_USE_DEBUG_LOGS` | `true` turns on the web's debug logging in the browser |

## Use your own image

```yaml
images:
  web: { repository: registry.example.org/cohort-discovery/web, tag: "1" }
```

Any build of the web that runs in standalone mode works, as long as it serves `/favicon.ico`, which the chart's health checks use.

## Configure it

The chart sets these at run time:

| Variable | Set from |
|---|---|
| `PORT` | `web.port` |
| `APPLICATION_MODE` | Always `standalone` |
| `API_BASE_URL` | The API the web's server calls: `api.appUrl` with single sign-on on, otherwise the API's in-cluster Service |
| `COOKIE_TOKEN_NAME` | `web.cookieTokenName` (`cds_stack_token`), the sign-in cookie's name |

| Value | Default | What |
|---|---|---|
| `web.appUrl` | `http://localhost:3000` | The web's URL as the browser sees it. The API sends people back to it after single sign-on |
| `web.cookieTokenName` | `cds_stack_token` | The sign-in cookie's name |
| `web.extraEnv` | `{}` | Any other run-time variable the web reads. Use it only for variables not in the table above, which it would duplicate |
| `web.resources` | | Requests and memory limit |

The web sets its sign-in cookie with `Secure`, so serve it over HTTPS; see [URLs and ingress](services.md#urls-and-ingress). The service docs list the [web's environment variables](https://hdruk.github.io/cohort-discovery-service-docs/developers/web/#environment-variables), and which are fixed at build time.

The web reads no secrets.
