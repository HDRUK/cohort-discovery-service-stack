# S12. Stack: Tilt settings without exported environment variables

**Repo:** this one · **Depends on:** S1

## Goal
Choosing local host ports, or turning Keycloak off, shouldn't depend on exporting `CDS_*` variables in the shell that runs `tilt up`. Use Tilt's own settings: a git-ignored `tilt_config.json` beside the `Tiltfile`, or flags after `--`, which `tilt args` can change while Tilt runs.

## Steps
1. Define `web-port`, `api-port`, `nlp-port`, `keycloak-port` (strings) and `keycloak` (bool) with `config.define_*` in the `Tiltfile`.
2. Precedence: flag, then `tilt_config.json`, then the existing `CDS_*` variable, then the default. The variables keep working.
3. Fail clearly when a port isn't a number.
4. Git-ignore `tilt_config.json`.
5. Update Run locally (Host ports, Without Keycloak), the FAQ, How to customise and `CLAUDE.md`.

## Done when
- `tilt alpha tiltfile-result` gives the default ports with nothing set, and each setting source wins in the order above.
- `mkdocs build --strict` passes.

## Out of scope
- Ports on a cluster, which come from the chart values.
- `GITHUB_TOKEN`, which is a secret and goes away with A1.
