# Maintaining

## Logs

Under Tilt, every resource's logs are in the Tilt UI (http://localhost:10350). With kubectl:

| Part | Command |
|---|---|
| API | `kubectl -n cohort-discovery logs deploy/cohort-discovery-api -c api` |
| Queue worker | `kubectl -n cohort-discovery logs deploy/cohort-discovery-queue -c horizon` |
| NLP | `kubectl -n cohort-discovery logs deploy/cohort-discovery-nlp -c nlp` |
| Web | `kubectl -n cohort-discovery logs deploy/cohort-discovery-web -c web` |
| Keycloak | `kubectl -n cohort-discovery logs deploy/cohort-discovery-keycloak -c keycloak` |
| A BUNNY | `kubectl -n cohort-discovery logs deploy/cohort-discovery-bunny-<collection> --all-containers` |
| Setup Jobs | `kubectl -n cohort-discovery logs job/cohort-discovery-<api-init, provision or vocab-import>` |

`api.logLevel` and `nlp.logLevel` set how much the API and NLP log.

## Scheduled jobs

Four CronJobs call the API every minute with the scheduler's service account, as HDR UK's own deployments do with a cloud scheduler:

| Job | What |
|---|---|
| `distributions-collector` | Creates distribution tasks for collections whose schedules are due |
| `task-cleanup-job` | Cleans up old tasks |
| `collection-no-activity-monitor` | Suspends active collections with no query activity for 30 minutes (the API's `system.collection_inactivity_minutes`), and sends a Slack notification if Slack is set up |
| `collection-task-backlog-monitor` | Suspends collections with too many pending tasks, when its feature flag is on |

Change their schedules under `scheduler.jobs` and their time zone with `scheduler.timeZone`, or turn them all off with `scheduler.enabled: false`. To run one now:

```bash
kubectl -n cohort-discovery create job --from=cronjob/cohort-discovery-task-cleanup-job task-cleanup-now
kubectl -n cohort-discovery logs job/task-cleanup-now
```

## Upgrading

The services are git submodules pinned to releases, and the chart's image tags match them.

1. Pull this repo, then `git submodule update --init` to move `services/` to the new pins.
2. Under Tilt, `tilt up` rebuilds what changed. With Helm, rebuild the images (see [Running with Helm](../running/helm.md)), run `scripts/customisations-values.sh`, and `helm upgrade`.

The setup Jobs run again on every upgrade and are safe to repeat: `api-init` runs only pending migrations, `provision` only adds what's missing, and `vocab-import` does nothing unless the vocabulary release changed.

When a service's release changes, compare the files in `customisations/api/` and `customisations/nlp/` with the service's own copies at the new release. They replace the service's files, so new settings upstream won't appear until you add them.

## Backups

Everything worth keeping is in MySQL: the app database (`cohort_discovery`) and the vocabulary (`omop`, which you can re-import instead). Keycloak's volume holds its realm, which the stack re-creates from `realm.json` and the values. With the bundled MySQL, for example:

```bash
kubectl -n cohort-discovery exec cohort-discovery-mysql-0 -- sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction cohort_discovery' > cohort_discovery.sql
```

The dump holds personal data (researchers' emails and activity). Store and delete it accordingly; see the [personal data inventory](../data-protection/personal-data-inventory.md).

## Reset and uninstall

Under Tilt, see [Stop, restart and reset](../getting-started.md#stop-restart-and-reset). With Helm, `helm uninstall cohort-discovery -n cohort-discovery` deletes the release, volumes included, but leaves the setup Jobs and the `bunny-<host>` Secrets the provision Job wrote. `kubectl delete namespace cohort-discovery` removes those too.
