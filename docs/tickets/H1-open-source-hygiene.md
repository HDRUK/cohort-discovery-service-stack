# H1. Open-source hygiene

**Repo:** all · **Depends on:** – · **Decisions:** D13

## Goal
Nothing private, personal or secret is published when the repos go public. Anything that has leaked is rotated.

## Context
Exploration found:
- BUNNY task API credentials and absolute `/Users/...` paths in `somop/docker-compose.multi.yaml` and `somop/out/*/docker-compose.run.yaml`.
- Default database passwords in `somop/docker/vocab.yaml` and `loadOMOP.ipynb`.
- A personal path mount in `project-daphne-bunny-config/omop/docker-compose.yml`.

Git history keeps a secret even after the file is deleted.

## Steps
1. Run a secret scanner (e.g. `gitleaks detect` over full history) on web, api, nlp, somop, bunny-config and the four `hdruk/*` composer packages. Record what it finds in this ticket by file and kind only. **Never paste a value here.**
2. Rotate every credential found. Collection host credentials can't be regenerated through the API (`02-verified-facts.md`), so recreate the host.
3. Remove the generated `out/` files from somop and add them to `.gitignore`. Replace personal paths with variables.
4. Decide, with whoever owns it, whether any repo's history needs rewriting before it is made public. That is destructive, so ask before doing it.
5. Licence (D13): add `LICENSE` to each repo once agreed.
6. GDPR / data protection: list what the stack stores and logs about people, and flag it for review. Today that includes emails, IdP claims, activity logs, Slack alerts and Keycloak users. This is not legal advice; it goes to the data protection owner.

## Findings (2026-11-12)
`gitleaks` 8.28.0 (container image, `--redact=100`) over the full history of fresh mirror clones, covering every branch and tag. File and kind only.

| Repo | Visibility | Hits | Finding | Verdict |
|---|---|---|---|---|
| API | public | 2 | `README.md`, SSO env example | False positive: placeholders |
| API | public | 1 | `database/seeders/CollectionSeeder.php`, a fixed collection host client ID and secret | Development fixture, run by `DevDatabaseSeeder` and `TestingSeeder`. Public, so treat it as known to anyone. See actions |
| somop | public | 22 | `docker/run-bunny.yaml`, two collection host credential pairs: the `CollectionSeeder` pair and one other | Fixed on branch `feat/H1-remove-committed-credentials`: read from env. The other pair targets a local API (`host.docker.internal:8100`) |
| somop | public | 2 | `configs/multi_example.yaml`, one collection host credential pair, not the seeder's | Fixed on the same branch: placeholders. Targets a local API |
| somop | public | 1 | `configs/CPRD.yaml`, a vocabulary concept name | False positive, recorded in `.gitleaksignore` |
| bunny-config | private | 1 | `relay.compose.yml`, a collection UUID next to `test-client-1`/`test-secret-1` | False positive: an identifier and placeholders |
| web, NLP, stack, the five `hdruk/*` packages | | 0 | | Clean |

Context from exploration that turned out wrong: somop's `out/` and `docker-compose.multi.yaml` were never committed (`out/` is ignored and the multi file is generated, now ignored too). `docker/vocab.yaml` and the notebooks are local, untracked files. bunny-config has never had an `omop/` directory. `loadOMOP.ipynb` isn't in any repo.

Personal paths: no default branch has a `/Users/` path. History has some: NLP briefly committed `node_modules/` (third-party example paths), and web once had a local path in `package.json`, `package-lock.json` and `tsconfig.tsbuildinfo`. At most that exposes a username, so it doesn't justify rewriting history.

Data protection (step 6): see [personal data inventory](../data-protection/personal-data-inventory.md). Its most urgent finding, plaintext passwords in the API's logs, is tracked as A5.

### Actions for owners
- **Deployed databases.** Check dev, preprod and prod for a collection host named `default-seeded-collection-host`, and delete it if present. Its credentials are public. All four environments set `REBUILD_DB=0` today, so the API doesn't seed them on start, but an earlier deploy might have.
- **Local development databases.** Anyone who used the second somop pair or the `multi_example.yaml` pair should delete those collection hosts locally. They're only valid against a local API.
- **History rewrite: not recommended.** Everything found is either a public development fixture or only valid locally, and the repos are already public, so rewriting wouldn't recall anything.
- **Local checkouts.** somop checkouts can hold untracked files with credentials in them: `docker-compose.multi.yaml` is generated with them, and `.env`-style files such as `docker/.env.simple` may have them (not opened). They aren't published, but they're one `git add -A` away. `.env` was already ignored. The somop branch also ignores the multi file and `.env.*` (except `.env.example`).

## Done when
- The scanner is clean on every repo to be published.
- Leaked credentials are rotated.
- A licence is chosen and added.
- The GDPR list has been handed over.

## Verification
Re-run the scanner, and `grep -r "/Users/" --include=*.y*ml` across the repos.
