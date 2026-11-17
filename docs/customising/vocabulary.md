# Vocabulary

Queries are built from OMOP concepts: conditions, drugs, measurements and so on. Out of the box the API and NLP use a **minimal vocabulary** of about 3,900 concepts, which `api-init` seeds. That's enough to try the service. To search every concept, import a **full vocabulary** downloaded from [Athena](https://athena.ohdsi.org).

The stack never ships vocabulary files: Athena needs an account, and some vocabularies, such as CPT4, are licensed. Never commit them or build them into an image.

## Import the full vocabulary

1. In Athena, choose the vocabularies you need and download the bundle.
2. Unzip it straight into `customisations/athena/`, so that `customisations/athena/VOCABULARY.csv` exists. The folder needs `VOCABULARY.csv` and `CONCEPT.csv`, plus whichever of `DOMAIN`, `CONCEPT_CLASS`, `RELATIONSHIP`, `CONCEPT_RELATIONSHIP`, `CONCEPT_SYNONYM`, `CONCEPT_ANCESTOR` and `DRUG_STRENGTH` you have. Missing tables are skipped. Everything in that folder except its README is git-ignored.
3. Run `tilt up`. With `VOCABULARY.csv` there, Tilt adds a `vocab-import` resource after `api-init` and runs it.

With Helm, pass `--set vocab.athena.hostPath=<absolute path>` and a longer `--timeout`, because `helm` waits for the import. The Job mounts that folder read-only **from the Kubernetes node**, so the path must exist there:

| Cluster | |
|---|---|
| Rancher Desktop, Docker Desktop, OrbStack | Your home folder is mounted into the VM at the same path, so anything under it works |
| kind | Needs an `extraMounts` entry in the cluster config |
| A shared cluster | Put the files on the node, or adapt the Job to read from a volume |

An external MySQL needs `local_infile=1` for the import.

The NLP picks up the new concepts within five minutes, without a restart.

## Re-import

The Job compares the release version in `VOCABULARY.csv` (its `None` row) with the one already imported. If they match, it does nothing, so later upgrades are quick. Otherwise it replaces each table, `VOCABULARY` last, so a run that fails part-way is retried in full next time.

To import the same release again, for example with more vocabularies, delete its version row first:

```bash
kubectl -n cohort-discovery exec cohort-discovery-mysql-0 -- sh -c \
  'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" omop -e "DELETE FROM vocabulary WHERE vocabulary_id = '"'"'None'"'"'"'
```

To go back to the minimal vocabulary, empty `omop.concept` and run `api-init` again (in the Tilt UI, or with `helm upgrade`).
