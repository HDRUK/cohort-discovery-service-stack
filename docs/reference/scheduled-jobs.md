# Scheduled jobs

Four CronJobs call the API every minute (`POST /api/v1/services/caller/<job>`) as the scheduler's service account, as HDR UK's own deployments do with a cloud scheduler.

| CronJob | What |
|---|---|
| `cohort-discovery-distributions-collector` | Creates distribution tasks for collections whose schedules are due. Running every minute doesn't mean distributions every minute: each collection's schedules decide that. The provision Job gives its collections concept counts weekly and demographics monthly, at 23:59 London time; collections created in the app get the schedules set there |
| `cohort-discovery-task-cleanup-job` | Cleans up old tasks |
| `cohort-discovery-collection-no-activity-monitor` | Suspends active collections whose type A BUNNY hasn't polled for 30 minutes (the API's `COLLECTION_INACTIVITY_MINUTES`), and sends a Slack notification if Slack is set up. See [If a collection is suspended](../deploying/connect-a-collection.md#if-a-collection-is-suspended) |
| `cohort-discovery-collection-task-backlog-monitor` | Suspends collections with too many pending tasks, when its feature flag is on |

| Value | What |
|---|---|
| `scheduler.jobs.<job>` | Each job's cron schedule. Default every minute |
| `scheduler.timeZone` | The time zone the cron schedules above are read in. Default `Etc/UTC`. It doesn't change the distribution schedules' times, which are stored with each collection |
| `scheduler.enabled` | `false` turns all four off |

To run one now:

```bash
kubectl -n cohort-discovery create job --from=cronjob/cohort-discovery-task-cleanup-job task-cleanup-now
kubectl -n cohort-discovery logs job/task-cleanup-now
```
