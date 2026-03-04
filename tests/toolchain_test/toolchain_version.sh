#!/usr/bin/env bash
set -euo pipefail

bun_path="$1"
version="$(${bun_path} --version)"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "Unexpected bun version output: ${version}" >&2
  exit 1
fi
