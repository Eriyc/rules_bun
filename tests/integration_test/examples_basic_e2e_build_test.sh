#!/usr/bin/env bash
set -euo pipefail

build_file="$1"
readme_file="$2"

[[ -f "${build_file}" ]]
[[ -f "${readme_file}" ]]
grep -Eq '^package\(default_visibility = \["//visibility:public"\]\)$' "${build_file}"
