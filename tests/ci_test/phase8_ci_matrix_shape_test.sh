#!/usr/bin/env bash
set -euo pipefail

workflow_file="$1"

grep -Eq '^name:[[:space:]]+CI$' "${workflow_file}"
grep -Eq 'USE_BAZEL_VERSION:[[:space:]]+9\.0\.0' "${workflow_file}"
grep -Eq 'os:[[:space:]]+ubuntu-latest' "${workflow_file}"
grep -Eq 'phase8_target:[[:space:]]+linux-x64' "${workflow_file}"
grep -Eq 'os:[[:space:]]+macos-14' "${workflow_file}"
grep -Eq 'phase8_target:[[:space:]]+darwin-arm64' "${workflow_file}"
grep -Eq 'os:[[:space:]]+windows-latest' "${workflow_file}"
grep -Eq 'phase8_target:[[:space:]]+windows' "${workflow_file}"
