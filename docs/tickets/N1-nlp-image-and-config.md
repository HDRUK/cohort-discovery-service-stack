# N1. NLP: document the image's config

**Repo:** `project-daphne-nlp` · **Depends on:** – · **Decisions:** D2

## Goal
A deployer who builds the NLP image knows which env vars and mounts configure it. Nothing is published (D2).

## Context
The NLP service is already runtime-configurable (`02-verified-facts.md`, NLP). It needs both the app DB (`latest_distributions`) and the vocabulary DB. The docs mention `OMOP_VIEW`, which the code doesn't use.

## Steps
1. Check the Dockerfile for a non-root user and a `.dockerignore`, and add them if missing.
2. Fix the docs: remove `OMOP_VIEW`, and document `DB_NAME` (the app DB), `OMOP_DB_NAME`, `RULES_PATH`, `MAPPINGS_PATH` and `/health/ready`.
3. Note in `02-verified-facts.md` that NLP must start after the API has migrated, because it reads an API table.

## Done when
The docs list every env var the code reads.

## Verification
- `grep -rn "os.environ\|getenv" --include=*.py` matches the documented list.
- `pytest`.
