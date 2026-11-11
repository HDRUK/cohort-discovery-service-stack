# S3. Stack: OMOP vocabulary

**Repo:** this one · **Depends on:** S1 · **Decisions:** D10

## Goal
The minimal vocabulary is there by default. An optional Job loads a full Athena download, from a host path the deployer supplies, into the MySQL vocabulary DB.

## Context
- The API's importer is `app:import-omop-vocabs {path} --create-schema --bulk --truncate`. It needs MySQL `local_infile=1`.
- It's followed by `concepts:populate-ancestors` and the full-text index migration (`AddFullTextIndexToOmopConcepts`).
- omop-lite can't target MySQL.
- `project-daphne-bunny-config/omop/loader.sh` is a working MySQL loader to compare against.
- Athena files need an account, and some vocabularies (e.g. CPT4) are licensed, so the stack never bundles them.
- Rancher Desktop mounts the macOS home directory into its VM at the same path, so a `hostPath` volume under `/Users/...` reaches the files. Check this, and document the equivalent for kind (`extraMounts`).

## Steps
1. Minimal (default): S1's init Job loads it (later `app:bootstrap` with `BOOTSTRAP_OMOP_MINIMAL=true`, A2).
2. Full: `vocab.athena.hostPath` in values enables a `vocab-import` Job using the API image. It mounts the path read-only at `/vocab` and runs the importer, then the ancestors and index steps. It's re-runnable: `--truncate`.
3. In Tilt it's a manual resource (`auto_init=False`, `TRIGGER_MODE_MANUAL`), with the path read from a Tilt setting, never committed.
4. Restart NLP after an import, because it loads concepts at start.
5. Document the size, the time (measure on a real download) and the recommended Athena vocabulary selection in `getting-started.md`.

## Done when
- After the import, concept search in the web finds concepts that aren't in the minimal set.
- NLP `/health/ready` returns 200.

## Verification
- Row counts per table against the Athena files.
- A concept search through the API.
