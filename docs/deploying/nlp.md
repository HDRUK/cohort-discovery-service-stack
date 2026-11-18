# The NLP

The NLP turns a researcher's free-text query into OMOP concepts (`services/nlp`, from [`HDRUK/project-daphne-nlp`](https://github.com/HDRUK/project-daphne-nlp)), matching it against the concepts collections have reported. The service docs' [NLP developer guide](https://hdruk.github.io/cohort-discovery-service-docs/developers/nlp/) explains the code; this page explains how the stack builds and configures it.

It runs as the `cohort-discovery-nlp` Deployment on `nlp.port` (5001). Only the API calls it, inside the cluster, so it has no public URL.

## Build the image

```bash
REGISTRY=registry.example.org/cohort-discovery
docker build -t $REGISTRY/nlp:1 services/nlp
docker push $REGISTRY/nlp:1
```

Add `--platform linux/amd64` on an Apple Silicon Mac. Build from a clean checkout: the NLP has no `.dockerignore` and loads a `.env` file at start-up, so a local `.env` in `services/nlp` would be copied in and used (ticket [N1](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/tickets/N1-nlp-image-and-config.md)). Otherwise the image has no settings built in: its rules come from mounted files, so you rebuild only to change the code.

## Use your own image

```yaml
images:
  nlp: { repository: registry.example.org/cohort-discovery/nlp, tag: "1" }
```

Your image must answer `/health/ready` and `/` on its port, which the chart's health checks use, and read the variables below.

## Configure it

| Variable | Set from |
|---|---|
| `PORT`, `APP_ENV`, `LOG_LEVEL` | `nlp.port`, `nlp.appEnv` (`production`), `nlp.logLevel` (`INFO`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME`, `OMOP_DB_NAME` | `mysql.*`. The NLP reads its concept list from the app database (the concepts collections have reported, in `latest_distributions`), and synonyms and ancestors from the vocabulary database. See [Database and vocabulary](database.md) |
| `RULES_PATH`, `MAPPINGS_PATH` | Set when you supply `rules.json` or `mappings.json`, below |

### Rules and mappings

`customisations/nlp/rules.json` and `mappings.json` replace the NLP's own. `scripts/customisations-values.sh` puts them in `nlp.rulesJson` and `nlp.mappingsJson`, and the chart mounts them in `/config/nlp/`. A change restarts the NLP. See [NLP rules](../customising/nlp.md) for what they hold.

### Anything else: `nlp.extraEnv`

Any other variable the NLP reads goes in `nlp.extraEnv`. Use it only for variables not in the table above, which it would duplicate. The service docs list the [NLP's environment variables](https://hdruk.github.io/cohort-discovery-service-docs/developers/nlp/#environment-variables).

## Secrets it reads

`mysql-password`, only.
