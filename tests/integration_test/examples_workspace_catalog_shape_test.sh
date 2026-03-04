#!/usr/bin/env bash
set -euo pipefail

root_package_json="$1"
pkg_a_package_json="$2"
pkg_b_package_json="$3"

grep -Eq '"catalog"[[:space:]]*:[[:space:]]*\{' "${root_package_json}"
grep -Eq '"lodash"[[:space:]]*:[[:space:]]*"\^4\.17\.21"' "${root_package_json}"
grep -Eq '"lodash"[[:space:]]*:[[:space:]]*"catalog:"' "${pkg_a_package_json}"
grep -Eq '"lodash"[[:space:]]*:[[:space:]]*"catalog:"' "${pkg_b_package_json}"
