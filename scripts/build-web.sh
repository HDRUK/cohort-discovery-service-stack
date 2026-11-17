#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: scripts/build-web.sh <image-ref> [docker build options...]" >&2
  exit 64
fi

image_ref="$1"
shift

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
web_dir="${repo_root}/services/web"
branding_dir="${repo_root}/customisations/web/branding"

if [ ! -f "${web_dir}/Dockerfile" ]; then
  echo "build-web: ${web_dir#"${repo_root}"/} is empty. Run: git submodule update --init" >&2
  exit 1
fi

build_context="$(mktemp -d)"
trap 'rm -rf "${build_context}"' EXIT

rsync -a \
  --exclude '.git' \
  --exclude 'node_modules/' \
  --exclude '.next/' \
  --exclude '.env' \
  --exclude '.env.*' \
  "${web_dir}/" "${build_context}/"

rsync -a "${branding_dir}/" "${build_context}/branding/"

docker build -t "${image_ref}" "$@" "${build_context}"
