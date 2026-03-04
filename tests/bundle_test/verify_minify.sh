#!/usr/bin/env bash
set -euo pipefail

bundle="$1"
minified="$2"

bundle_size="$(wc -c < "${bundle}")"
minified_size="$(wc -c < "${minified}")"

if (( minified_size >= bundle_size )); then
  echo "Expected minified bundle (${minified_size}) to be smaller than regular bundle (${bundle_size})" >&2
  exit 1
fi
