# N1. NLP: publish the image, document the mounts

**Repo:** `project-daphne-nlp` · **Depends on:** D2 · **Decisions:** D2

## Goal
`ghcr.io/hdruk/cohort-discovery-nlp:<tag>` is public, and a deployer knows which env vars and mounts configure it.

## Context
The NLP service is already runtime-configurable (`02-verified-facts.md`, NLP). It needs both the app DB (`latest_distributions`) and the vocabulary DB. The docs mention `OMOP_VIEW`, which the code doesn't use.

## Steps
1. Add a GHCR publish job on release tags alongside the existing pipeline.
2. Check the Dockerfile for a non-root user and a `.dockerignore`, and add them if missing.
3. Fix the docs: remove `OMOP_VIEW`, and document `DB_NAME` (the app DB), `OMOP_DB_NAME`, `RULES_PATH`, `MAPPINGS_PATH` and `/health/ready`.
4. Note in `02-verified-facts.md` that NLP must start after the API has migrated, because it reads an API table.

## Done when
The image pulls anonymously from GHCR, and the docs list every env var the code reads.

## Verification
- `docker pull` while logged out.
- `grep -rn "os.environ\|getenv" --include=*.py` matches the documented list.
- `pytest`.
