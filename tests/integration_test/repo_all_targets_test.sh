#!/usr/bin/env bash
set -euo pipefail

workflow_file="$1"

grep -Eq 'bazel test //tests/\.\.\.' "${workflow_file}" || grep -Eq 'bazel test //\.\.\.' "${workflow_file}"
