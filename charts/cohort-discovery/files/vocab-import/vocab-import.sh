#!/bin/bash
set -euo pipefail

cd /var/www

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"
vocab_dir=/vocab
tables_before_vocabulary=(DOMAIN CONCEPT_CLASS RELATIONSHIP CONCEPT CONCEPT_RELATIONSHIP CONCEPT_SYNONYM CONCEPT_ANCESTOR DRUG_STRENGTH)

if [ ! -f "${vocab_dir}/VOCABULARY.csv" ] || [ ! -f "${vocab_dir}/CONCEPT.csv" ]; then
  echo "vocab-import: ${vocab_dir} has no VOCABULARY.csv or CONCEPT.csv. Point vocab.athena.hostPath at an unzipped Athena download." >&2
  exit 1
fi

release="$(awk -F'\t' '$1 == "None" { print $4 }' "${vocab_dir}/VOCABULARY.csv")"
if [ -z "${release}" ]; then
  echo "vocab-import: VOCABULARY.csv has no 'None' row giving the release version" >&2
  exit 1
fi

imported="$(php "${scripts_dir}/vocabulary-version.php")"
if [ "${imported}" = "${release}" ]; then
  echo "vocab-import: release '${release}' is already imported, nothing to do"
  exit 0
fi

echo "vocab-import: importing release '${release}' (database has '${imported:-none}')"
for table in "${tables_before_vocabulary[@]}" VOCABULARY; do
  php artisan app:import-omop-vocabs "${vocab_dir}" --create-schema --bulk --truncate --table="${table}"
done

php artisan concepts:populate-ancestors

echo "vocab-import: done"
