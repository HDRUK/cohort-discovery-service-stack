#!/bin/bash
set -euo pipefail

cd /var/www

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"

row_count() {
  local count
  count="$(php "${scripts_dir}/row-count.php" "$1" "$2")"
  if ! [[ "${count}" =~ ^[0-9]+$ ]]; then
    echo "api-init: could not count rows in $1.$2" >&2
    exit 1
  fi
  echo "${count}"
}

seed_when_table_empty() {
  local connection="$1" table="$2" seeder="$3" count
  shift 3
  count="$(row_count "${connection}" "${table}")"
  if [ "${count}" = "0" ]; then
    echo "api-init: ${table} is empty, running ${seeder}"
    php artisan db:seed --class="${seeder}" --force "$@"
  else
    echo "api-init: ${table} already has rows, skipping ${seeder}"
  fi
}

php artisan migrate --force
php artisan migrate --database=omop --path=database/migrations_omop --force
php artisan deploy:run

seed_when_table_empty mysql workgroups WorkgroupSeeder
seed_when_table_empty mysql roles RolesAndPermissionsSeeder
php artisan db:seed --class=StateSeeder --force
php artisan db:seed --class=FeatureSeeder --force
php artisan db:seed --class=PersonalAccessClientSeeder --force

seed_when_table_empty omop concept MinimalOmopSeeder --database=omop

seed_when_table_empty mysql users StandaloneDemoSeeder

php "${scripts_dir}/ensure-scheduler-account.php"

echo "api-init: done"
