# Connect a collection

A custodian connects real data by running BUNNY next to it. BUNNY calls out to your stack's API to fetch tasks and post back results; the stack never connects to the custodian's data. This page covers what is specific to this stack. The service docs cover BUNNY itself: [setting it up](https://hdruk.github.io/cohort-discovery-service-docs/bunny/setup/), [its configuration](https://hdruk.github.io/cohort-discovery-service-docs/bunny/configuration/) and [why each collection needs two BUNNYs](https://hdruk.github.io/cohort-discovery-service-docs/bunny/two-instance-pattern/).

## What a collection needs

| Thing | What | Where it comes from |
|---|---|---|
| Custodian | The organisation responsible for the data | `provision.json`, `bootstrap.custodianName`, or the app |
| Collection host | One set of BUNNY credentials (`client_id` and `client_secret`). One host can serve several collections | Created in the app or by the provision Job. **The credentials are shown only once** |
| Collection | The dataset, with an ID, shared with workgroups | Created in the app or by the provision Job |
| BUNNY type A | Answers researchers' queries (`TASK_API_TYPE=a`) | Run by the custodian, one per collection |
| BUNNY type B | Collects distributions: concept counts and demographics (`TASK_API_TYPE=b`) | Run by the custodian, one per collection |

A host with three collections therefore needs six BUNNYs: a type A and a type B for each collection.

## 1. Create the host and collection

=== "In the app"

    Sign in as an admin, or as a custodian user (a member of the custodian; see [Identity and access](../customising/identity-and-access.md)). In the custodian's management area, create a host, then a collection linked to it, as in steps 2 to 6 of the service docs' [BUNNY setup](https://hdruk.github.io/cohort-discovery-service-docs/bunny/setup/). Copy the host's client ID and secret as soon as they appear. Then share the collection with the workgroups that should see it, and make it active.

=== "With provision.json"

    Add the custodian, host and collection to `customisations/provision.json` (see [Collections](../customising/collections.md)), leaving out `"synthetic": true`. The provision Job creates them, shares the collection, makes it active, and writes the host's credentials and the collection's ID to the Secret `bunny-<host>`:

    ```bash
    kubectl -n cohort-discovery get secret bunny-<host> -o jsonpath='{.data.TASK_API_USERNAME}' | base64 -d; echo
    kubectl -n cohort-discovery get secret bunny-<host> -o jsonpath='{.data.TASK_API_PASSWORD}' | base64 -d; echo
    kubectl -n cohort-discovery get secret bunny-<host> -o jsonpath='{.data.collection-<collection>}' | base64 -d; echo
    ```

    The Secret is the only copy of the credentials. Don't delete it.

Send the credentials to the custodian through a channel you'd trust with a password.

## 2. Run BUNNY at the custodian's site

The custodian runs two BUNNYs per collection, with the same settings except `TASK_API_TYPE`:

| Setting | Value |
|---|---|
| `TASK_API_BASE_URL` | Your `api.appUrl` plus `/api/v1`, for example `https://api.cds.example.org/api/v1`. **Not** the `TASK_API_BASE_URL` in the `bunny-<host>` Secret: that's the API's address inside your cluster, for the synthetic BUNNYs |
| `TASK_API_USERNAME`, `TASK_API_PASSWORD` | The host's client ID and secret |
| `COLLECTION_ID` | The collection's ID |
| `TASK_API_TYPE` | `a` for one BUNNY, `b` for the other |
| `TASK_API_ENFORCE_HTTPS` | Keep it `true`, so BUNNY refuses plain HTTP. The synthetic BUNNYs set it to `false` only because they talk to the API inside the cluster |
| `DATASOURCE_*`, obfuscation settings | The custodian's own database and disclosure rules; see the service docs' [configuration reference](https://hdruk.github.io/cohort-discovery-service-docs/bunny/configuration/) |

The custodian's network must allow BUNNY to reach your API over HTTPS. Nothing needs to reach the custodian's network.

## 3. Check it's working

- The BUNNYs' logs show them polling without authentication errors.
- A researcher in one of the collection's workgroups sees the collection and gets counts back.
- Within a minute or so of the first type B poll, distributions arrive and the "Last Distribution" column fills in. Collections created by the provision Job get their distribution schedules and a first run automatically; for collections created in the app, check their schedules in the app.

## If a collection is suspended

Two scheduled jobs can suspend an active collection:

- `collection-no-activity-monitor`, when its **type A** BUNNY has polled before but not in the last 30 minutes (the API's `COLLECTION_INACTIVITY_MINUTES`). Type B polls don't count.
- `collection-task-backlog-monitor`, when too many of its tasks are pending, and only while the API's `collection-task-backlog-limit` feature flag is on.

Either way, it becomes active again by itself the next time its type A BUNNY polls, as long as its task backlog has drained. So if a collection is suspended, check that its type A BUNNY is running and can reach the API.

## Synthetic collections

To try this without real data, the stack runs synthetic collections: each gets a type A and a type B BUNNY inside the cluster, reading made-up OMOP data. See [Collections](../customising/collections.md#synthetic-collections).
