# Contributing

The plan of work, decisions and ticket tracker are in [`docs/README.md`](docs/README.md). Changes to the web, API or NLP belong in those services' own repos; this repo then moves its submodule pins.

## The docs site

The user docs under `docs/` are published as an MkDocs Material site at https://hdruk.github.io/cohort-discovery-service-stack/, defined by `mkdocs.yml`. To preview it:

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

`.github/workflows/docs.yml` builds it with `mkdocs build --strict` and publishes it to GitHub Pages on every push to `main` that touches `docs/`, `mkdocs.yml` or `requirements-docs.txt`, or when run by hand. The repo's Pages source is set to "GitHub Actions".

- The strict build fails on broken links, broken anchors and pages missing from `nav`, so add every new page to `nav`.
- The planning files (`docs/README.md`, `01-decisions.md`, `02-verified-facts.md`, `web-variables.md`, `tickets/`) are left out of the site with `exclude_docs`. Link to them from user pages by their GitHub URL, except `tickets/`, which is git-ignored and kept locally only.
- Where the general [service docs](https://hdruk.github.io/cohort-discovery-service-docs/) already explain something (BUNNY, identity providers, claim mapping, branding fields), link to them and keep only what's specific to the stack.
