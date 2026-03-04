#!/usr/bin/env bash
set -euo pipefail

bundle="$1"

if [[ ! -s "${bundle}" ]]; then
  echo "Expected bundled output to exist and be non-empty: ${bundle}" >&2
  exit 1
fi
