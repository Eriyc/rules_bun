#!/usr/bin/env bash
set -euo pipefail

workflow_file="$1"

grep -Eq 'bazel test //(tests/)?\.\.\.' "${workflow_file}"
