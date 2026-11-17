# S3. Stack: OMOP vocabulary

**Repo:** this one · **Depends on:** S1 · **Decisions:** D10

## Goal
The minimal vocabulary is there by default. An optional Job loads a full Athena download, from a host path the deployer supplies, into the MySQL vocabulary DB that the API and NLP read. The synthetic BUNNYs keep omop-lite's own vocabulary.

## Context
- The API's importer is `app:import-omop-vocabs {path} --create-schema --bulk --truncate [--table=]`. It reads `<TABLE>.csv` files (Athena's tab-separated export) and loads them with `LOAD DATA LOCAL INFILE`. The chart's MySQL already runs with `--local-infile=1`, and the API's `omop` connection sets `PDO::MYSQL_ATTR_LOCAL_INFILE`.
- `concepts:populate-ancestors` only queues `PopulateLocalConceptAncestors`, which links concepts that already have distributions.
- There's no full-text index migration at the pinned API (`b257363`), so there's nothing to run after the import.
- NLP needs no restart: its reload check counts `concept_synonym` and `concept_ancestor` rows, so it reloads within `STORE_REFRESH_TTL` (300 seconds) of an import. Its concept list comes from `latest_distributions`, not the vocabulary.
- omop-lite can't target MySQL.
- Athena files need an account, and some vocabularies (e.g. CPT4) are licensed, so the stack never bundles them.
- Rancher Desktop mounts the macOS home directory into its VM at the same path, so a `hostPath` volume under `/Users/...` reaches the files. kind needs an `extraMounts` entry.

## Steps
1. Minimal (default): S1's init Job loads it when `omop.concept` is empty.
2. Full: `vocab.athena.hostPath` in values renders a `vocab-import` Job, a `post-install`/`post-upgrade` hook after `api-init`, using the API image. It mounts the path read-only at `/vocab`.
3. The Job compares the release in the download's `VOCABULARY.csv` `None` row with the one in the database. If they match, it does nothing. Otherwise it imports each table with `--truncate`, `VOCABULARY` last, so a failed run is retried rather than skipped, then queues `concepts:populate-ancestors`.
4. In Tilt, the path is `customisations/athena/` when it holds `VOCABULARY.csv`. That folder is git-ignored apart from its README, so the files are never committed. With neither, there's no import and the minimal vocabulary stays. The resource runs on `tilt up`; once the release is imported, later runs skip.
5. Document the size, the time (measure on a real download) and the recommended Athena vocabulary selection in `getting-started.md`.

## Done when
- After the import, concept search in the web finds concepts that aren't in the minimal set.
- NLP `/health/ready` returns 200.
- A second run logs "already imported" and changes nothing.

## Verification
- Row counts per table against the Athena files.
- A concept search through the API.
