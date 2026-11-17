#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secrets_dir="${repo_root}/generated"
secrets_file="${secrets_dir}/secrets.values.yaml"

umask 077
mkdir -p "${secrets_dir}"
work_dir="$(mktemp -d "${secrets_dir}/.work.XXXXXX")"
trap 'rm -rf "${work_dir}"' EXIT

random_hex() {
  openssl rand -hex "$1"
}

random_uuid() {
  random_hex 16 | sed -E 's/^(.{8})(.{4})(.{4})(.{4})(.{12})$/\1-\2-\3-\4-\5/'
}

indent_block() {
  sed 's/^/    /' "$1"
}

write_new_file() {
  openssl genrsa -out "${work_dir}/passport-private.key" 4096 2>/dev/null
  openssl rsa -in "${work_dir}/passport-private.key" -pubout -out "${work_dir}/passport-public.key" 2>/dev/null

  {
    echo "secrets:"
    echo "  appKey: \"base64:$(openssl rand -base64 32)\""
    echo "  mysqlRootPassword: \"$(random_hex 24)\""
    echo "  mysqlPassword: \"$(random_hex 24)\""
    echo "  jwtSecret: \"$(random_hex 32)\""
    echo "  collectionHostsKeySalt1: \"$(random_hex 32)\""
    echo "  collectionHostsKeySalt2: \"$(random_hex 32)\""
    echo "  adminPassword: \"$(random_hex 12)\""
    echo "  schedulerClientId: \"$(random_uuid)\""
    echo "  schedulerClientSecret: \"$(random_hex 32)\""
    echo "  passportPrivateKey: |"
    indent_block "${work_dir}/passport-private.key"
    echo "  passportPublicKey: |"
    indent_block "${work_dir}/passport-public.key"
  } > "${work_dir}/secrets.values.yaml"

  chmod 600 "${work_dir}/secrets.values.yaml"
  mv "${work_dir}/secrets.values.yaml" "${secrets_file}"

  echo "local-secrets: wrote ${secrets_file#"${repo_root}"/} (mode 0600). Values are not printed."
}

has_key() {
  grep -q "^  $1:" "${secrets_file}"
}

add_missing_keys() {
  local key added=()
  cp "${secrets_file}" "${work_dir}/secrets.values.yaml"
  for key in keycloakAdminPassword keycloakClientSecret researcherPassword custodianPassword syntheticDbPassword; do
    if ! has_key "${key}"; then
      echo "  ${key}: \"$(random_hex 24)\"" >> "${work_dir}/secrets.values.yaml"
      added+=("${key}")
    fi
  done
  if [ "${#added[@]}" -eq 0 ]; then
    echo "local-secrets: ${secrets_file#"${repo_root}"/} already has every key, leaving it unchanged."
    return
  fi
  chmod 600 "${work_dir}/secrets.values.yaml"
  mv "${work_dir}/secrets.values.yaml" "${secrets_file}"
  echo "local-secrets: added ${added[*]} to ${secrets_file#"${repo_root}"/}. Values are not printed."
}

if [ ! -f "${secrets_file}" ]; then
  write_new_file
fi
add_missing_keys
