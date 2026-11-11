# S0. Stack: scaffold

**Repo:** this one · **Depends on:** D5 · **Decisions:** D5, D11

## Goal
The repo layout every later ticket builds on.

## Steps
1. Add submodules under `services/`: `web`, `api` and `nlp`, from `HDRUK/project-daphne-*`, each pinned to its latest release tag. Leave somop out until S5 decides whether it's a submodule or a published image.
2. Layout:
   ```
   services/{web,api,nlp}/     submodules
   config/
     claims-mapping.json       A3's format, matching the Keycloak example's groups and roles
     nlp/{rules,mappings}.json copied from the NLP defaults
     branding/                 W3's neutral default
     provision.json            S4's custodians, hosts and collections
     synthetic/                S5's somop configs
   compose/                    S1+
   charts/                     S6
   scripts/                    build-web.sh (W3), helpers
   .env.example                every variable the stack reads, grouped by service, no real values
   Makefile                    up, down, build, logs, vocab-import, provision
   ```
3. `.env.example` placeholders must be obviously fake (`change-me`, `admin@example.com`), and `make up` should refuse to start while any `change-me` remains.
4. Write `docs/getting-started.md`, which later tickets fill in.

## Done when
`git submodule update --init` checks out all three services at tags, and `make` prints the targets.

## Verification
A fresh `git clone --recurse-submodules` works.
