# S13. Stack: "Deploy to a cluster" docs by component

**Repo:** this one · **Depends on:** S10

## Goal
Explain each part of a cluster install on its own page, rather than in one walkthrough: how each image is built, how to use your own image and your own configuration, and what to configure for sign-in, the database and the supporting services. Prompted by review of the S10 deploy page.

## Steps
1. A shorter install page: what you deploy, starting point, images, secrets (with which part uses each), install, upgrade, back up, uninstall, known limitations.
2. One page each for the API, the web app and the NLP: what it runs, build the image, use your own image, configure it (values, the env the chart sets, mounted files, `extraEnv`), secrets.
3. Database and vocabulary: the two MySQL databases, bundled or external, what `api-init` creates, the minimal and full vocabulary, importing without `hostPath`, back up.
4. Sign-in: bundled Keycloak, your own OIDC provider, or passwords only, and password sign-in alongside single sign-on.
5. Supporting services: Redis, the queue worker, scheduled jobs, setup Jobs, URLs and ingress, third-party images, resources.
6. Repoint links to moved anchors.

## Done when
- `mkdocs build --strict` passes.
- The pages match the chart: checked by a reviewer against the templates and service source.

## Out of scope
- Chart changes, including the gaps in S11.
