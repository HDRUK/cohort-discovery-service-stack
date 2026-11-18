# Database and vocabulary

Everything the service keeps is in one MySQL server, in two databases:

| Database | Value | What | Used by |
|---|---|---|---|
| `cohort_discovery` | `mysql.appDatabase` | The app: users, custodians, collections, queries, tasks, results and activity logs | The API, queue worker and `api-init`; the NLP reads its concept list from it: the concepts collections have reported |
| `omop` | `mysql.omopDatabase` | The OMOP vocabulary: the concepts queries are built from | The API; the NLP reads synonyms and ancestors from it |

Every part signs in as `mysql.username` (`cohort_discovery`) with the `mysql-password` secret.

## Bundled or external MySQL

=== "Bundled (the default)"

    `mysql.enabled: true` runs MySQL 8.4 as a StatefulSet with its own volume (`mysql.storageSize`, 10Gi by default; `mysql.storageClassName`). It creates both databases and the user, and starts with `local_infile` on for the vocabulary import. It also needs `mysql-root-password`. Leave `mysql.port` at 3306: the bundled MySQL's Service always listens there.

    It's simple, but it's one pod with one volume that `helm uninstall` deletes. Use it for trials.

=== "External"

    For a real service, use a managed or existing MySQL 8 server:

    ```yaml
    mysql:
      enabled: false
      host: mysql.example.org
      port: 3306
      username: cohort_discovery
    ```

    Before installing:

    - create both databases (`mysql.appDatabase` and `mysql.omopDatabase`);
    - give `mysql.username` all privileges on both;
    - for the full vocabulary import, set `local_infile=1` on the server.

    Put the user's password in `mysql-password`; `mysql-root-password` isn't needed.

## What `api-init` creates

On every install and upgrade, the `api-init` Job migrates both databases (only pending migrations run) and seeds what's missing: roles, workgroups, feature flags, the first admin and the scheduler's account. You never run migrations by hand. Some seeding happens only once: roles only while the `roles` table is empty, and the admin only while there are no users, so changing `bootstrap.adminEmail` or `admin-password` after the first install changes nothing. See [Internals](../reference/internals.md#api-init) for each step.

## The vocabulary

Queries are built from OMOP concepts, so the `omop` database needs a vocabulary in it.

| | What | How |
|---|---|---|
| **Minimal** (the default) | About 3,900 concepts, enough to try the service | `api-init` seeds it when `omop.concept` is empty |
| **Full** | Every concept in the vocabularies you download from [Athena](https://athena.ohdsi.org) | The `vocab-import` Job, or the same command run yourself |

Athena needs an account and some vocabularies are licensed, so the stack never ships vocabulary files. Never commit them or build them into an image.

### Import with the Job

Unzip the Athena download into a folder **on the node the Job will run on**. The chart sets no node selector, so put the folder on every node the Job could land on. Then set:

```yaml
vocab:
  athena:
    hostPath: /srv/athena
```

On the next install or upgrade, the `vocab-import` Job runs after `api-init`, using the API image. It mounts the folder read-only and replaces each table. It does nothing if that vocabulary release is already imported, so later upgrades are quick. Give `helm` a longer `--timeout`, because it waits for the import, and give the bundled MySQL more than 10Gi. The NLP picks up new synonyms and ancestors within five minutes. [Vocabulary](../customising/vocabulary.md) has the folder's contents and how to import again.

### Without `hostPath`

Many managed clusters don't allow `hostPath` volumes. There, run the command the Job runs yourself, from anywhere that has the API image, the Athena files and access to MySQL, with the API's database settings:

```bash
php artisan app:import-omop-vocabs <folder> --create-schema --bulk --truncate --table=<TABLE>
```

Run it once per table, in the order in `charts/cohort-discovery/files/vocab-import/vocab-import.sh`, with `VOCABULARY` last, then run `php artisan concepts:populate-ancestors` as the Job does. Reading from a volume instead of `hostPath` is on the [tracker](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/tickets/S11-stack-cluster-readiness.md).

## Back up

Most of what's worth keeping is in MySQL. With the bundled Keycloak, its volume holds the users and their passwords; the `bunny-<host>` Secrets hold BUNNY credentials the app can't show again. Back those up too. The app database holds personal data (researchers' emails and activity), so store and delete dumps accordingly. The vocabulary can be imported again instead of backed up.

With an external MySQL, use your usual backups. With the bundled one:

```bash
kubectl -n cohort-discovery exec cohort-discovery-mysql-0 -- sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction cohort_discovery' > cohort_discovery.sql
```
