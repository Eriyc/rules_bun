#!/usr/bin/env bash
set -euo pipefail

bundle="$1"

if [[ ! -f "${bundle}" ]]; then
  echo "Bundle output not found: ${bundle}" >&2
  exit 1
fi

if [[ ! -s "${bundle}" ]]; then
  echo "Bundle output is empty: ${bundle}" >&2
  exit 1
fi
