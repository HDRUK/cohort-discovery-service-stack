# Athena vocabulary

Put an unzipped [Athena](https://athena.ohdsi.org) download here to give the API and NLP the full OMOP vocabulary. With `VOCABULARY.csv` in this folder, `tilt up` imports it. Without it, the stack uses the minimal vocabulary.

Everything here except this README is git-ignored. Athena files need an account, and some vocabularies are licensed, so they must never be committed.

With Helm alone, pass `--set vocab.athena.hostPath=<absolute path>`. See [Full OMOP vocabulary](../../docs/getting-started.md#full-omop-vocabulary).
