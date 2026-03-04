#!/usr/bin/env bash
set -euo pipefail

bundle_file="$1"

[[ -f ${bundle_file} ]]
grep -Eq 'hello-workspace-pkg-a|workspace-pkg-a' "${bundle_file}"
