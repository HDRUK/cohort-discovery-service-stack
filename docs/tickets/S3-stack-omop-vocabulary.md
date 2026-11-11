# S3. Stack: OMOP vocabulary

**Repo:** this one · **Depends on:** S1, D10 · **Decisions:** D10

## Goal
The minimal vocabulary is there by default. `make vocab-import VOCAB_DIR=/path/to/athena` loads a full Athena download into the vocabulary DB.

## Context
- The API's importer is `app:import-omop-vocabs {path} --create-schema --bulk --truncate`. It needs MySQL `local_infile=1`.
- It's followed by `concepts:populate-ancestors` and the full-text index migration (`AddFullTextIndexToOmopConcepts`).
- omop-lite can't target MySQL.
- `project-daphne-bunny-config/omop/loader.sh` is a working MySQL loader to compare against.
- Athena files need an account, and some vocabularies (e.g. CPT4) are licensed, so the stack never bundles them.

## Steps
1. Minimal (default): `app:bootstrap` already loads it when `BOOTSTRAP_OMOP_MINIMAL=true` (A2). Just set the env.
2. Full: add a Compose service `vocab-import` with profile `vocab`, using the API image. It mounts `${VOCAB_DIR}` read-only at `/vocab` and runs the importer, then the ancestors and index steps. It must be re-runnable: `--truncate`.
3. Restart NLP after an import. It loads concepts at start, so it should wait on the job finishing.
4. Document the size and time (measure on a real download) and the Athena vocabulary selection that's recommended, in `getting-started.md`.

## Done when
- After the import, concept search in the web finds concepts that aren't in the minimal set.
- NLP `/health/ready` returns 200.

## Verification
- Row counts per table against the Athena files.
- A concept search through the API.
