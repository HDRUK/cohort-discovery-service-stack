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

## Done when
- The scanner is clean on every repo to be published.
- Leaked credentials are rotated.
- A licence is chosen and added.
- The GDPR list has been handed over.

## Verification
Re-run the scanner, and `grep -r "/Users/" --include=*.y*ml` across the repos.
