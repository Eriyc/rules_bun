#!/usr/bin/env bash
set -euo pipefail

build_file="$1"

grep -Eq 'name = "failing_suite"' "${build_file}"
if grep -Eq 'tags = \["manual"\]' "${build_file}"; then
  echo "failing_suite must be automated (not manual-only)" >&2
  exit 1
fi
