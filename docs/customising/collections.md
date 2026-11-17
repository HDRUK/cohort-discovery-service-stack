# Collections

`customisations/provision.json` lists the custodians, collection hosts and collections the stack creates. The provision Job creates them through the API, shares each collection with its workgroups and makes it active, so researchers in those workgroups can query it straight away. Collections marked `synthetic` also get a BUNNY serving made-up data.

## `provision.json`

```json
{
  "custodians": [
    {
      "name": "Demo Custodian",
      "hosts": [
        {
          "name": "Synthetic Host",
          "collections": [
            {
              "name": "Synthetic Collection A",
              "description": "Synthetic OMOP data for trying the service. It describes no real people.",
              "synthetic": true,
              "syntheticSize": 1000,
              "workgroups": ["UK-RESEARCH", "UK-INDUSTRY"]
            }
          ]
        }
      ]
    }
  ]
}
```

| Field | Required | What |
|---|---|---|
| `custodians[].name` | Yes | The custodian. Users in a Keycloak group with the same name, ignoring case, become its members |
| `custodians[].hosts[].name` | Yes | A collection host: one set of BUNNY credentials |
| `…collections[].name` | Yes | The collection's name |
| `…collections[].description` | Yes, when the collection is created | Shown in the app |
| `…collections[].workgroups` | No | The workgroups that can query it. Each must exist (see [Workgroups](identity-and-access.md#workgroups)), or the run stops before creating anything |
| `…collections[].synthetic` | No | `true` serves the collection from synthetic data. Default `false` |
| `…collections[].syntheticSize` | No | The synthetic bundle: 100, 1000 or 1001 people. Default `synthetic.defaultSize` (100). Any other value fails the install |

Records are matched by name, so the Job can run again without changing anything. It **never deletes or renames** anything, and never takes a workgroup away from a collection: do that in the app. Renaming an entry in the file creates a new record.

## When it runs

- Under Tilt, after the API and Keycloak are up, and again whenever `provision.json` changes.
- With Helm, after every `helm install` and `helm upgrade`.

It signs in as `bootstrap.adminEmail` through the Keycloak login form, so it's off when Keycloak is (`provision.enabled: false`). With an identity provider other than Keycloak, create collections in the app instead.

To see what it did:

```bash
kubectl -n cohort-discovery logs job/cohort-discovery-provision
```

## Host credentials

For each host, the Job writes a Secret `bunny-<host>` (for example `bunny-synthetic-host`) with the BUNNY's `TASK_API_BASE_URL`, `TASK_API_USERNAME` and `TASK_API_PASSWORD`, and a `collection-<collection>` key with each collection's ID. `TASK_API_BASE_URL` is the API's address inside the cluster; a BUNNY outside the cluster needs `api.appUrl` plus `/api/v1` instead, with the same username and password. See [Connect a collection](../deploying/connect-a-collection.md).

The API shows a host's credentials only once, when it creates the host, so **the Secret is the only copy**. If the host exists and its Secret doesn't, the Job stops and asks you to delete the host in the app or restore the Secret.

When the Job creates a host or collection, it restarts that host's BUNNYs so they read the new IDs.

## Distributions

The provision Job gives each collection two distribution schedules, as the API's own seeders do: `GENERIC` (concept counts) weekly and `DEMOGRAPHICS` monthly, at 23:59 London time. The schedule is stored with the collection; the `distributions-collector` scheduled job checks every minute for schedules that are due, and the collection's type B BUNNY does the work. Without them the term directory and the "Last Distribution" columns stay empty. When the Job adds a schedule it also runs it once, so distributions arrive within a minute or so. A schedule you've changed in the app is left alone.

## Synthetic collections

Each collection with `"synthetic": true` gets a Deployment, `cohort-discovery-bunny-<collection>`, serving synthetic OMOP data from omop-lite's bundled datasets. They describe no real people. Collections of the same size return the same counts.

- One Postgres, `cohort-discovery-synthetic-db`, holds a database per synthetic collection. Under Tilt its volume survives `tilt down`.
- On start, the BUNNY's init containers create the collection's database if it's missing and load the synthetic data once. Restarts don't reload it.
- Each Deployment runs two BUNNY containers: `bunny-a` (type A, answers queries) and `bunny-b` (type B, collects distributions), as the service docs' [two-instance pattern](https://hdruk.github.io/cohort-discovery-service-docs/bunny/two-instance-pattern/) describes. They start once the provision Job has written their host's Secret.
- For custom or larger synthetic data, see [somop](https://hdruk.github.io/cohort-discovery-service-docs/developers/somop/) in the service docs.

Settings, under `synthetic` in the values:

| Value | Default | What |
|---|---|---|
| `enabled` | `true` | Turns synthetic BUNNYs off even when `provision.json` marks collections synthetic |
| `defaultSize` | `100` | The bundle for collections without `syntheticSize` |
| `bunny.pollingInterval` | `5` | Seconds between the BUNNYs' polls |
| `bunny.lowNumberSuppressionThreshold` | `10` | Counts below this are reported as 0. See the service docs on [disclosure control](https://hdruk.github.io/cohort-discovery-service-docs/architecture/governance/) |
| `bunny.roundingTarget` | `10` | Counts are rounded to the nearest multiple |

To reload a collection's data, drop its database and restart its BUNNY. The database name is the collection's name in lower case, with underscores for spaces and punctuation:

```bash
kubectl -n cohort-discovery exec cohort-discovery-synthetic-db-0 -- dropdb --username=postgres synthetic_collection_a
kubectl -n cohort-discovery rollout restart deployment/cohort-discovery-bunny-synthetic-collection-a
```
