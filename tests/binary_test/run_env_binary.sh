#!/usr/bin/env bash
set -euo pipefail

binary="$1"
output="$(${binary})"

if [[ ${output} != "from-dotenv" ]]; then
  echo "Expected .env value from entry-point directory, got: ${output}" >&2
  exit 1
fi
