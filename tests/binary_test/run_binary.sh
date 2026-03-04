#!/usr/bin/env bash
set -euo pipefail

binary="$1"
expected="$2"
output="$(${binary})"

if [[ "${output}" != "${expected}" ]]; then
  echo "Unexpected output from ${binary}: ${output}" >&2
  exit 1
fi
